// [VI] Phong bì event cho RabbitMQ (bưu điện giữa các service). Event (nội dung nghiệp vụ)
// được bọc trong phong bì CÓ CHỮ KÝ trước khi đưa lên hàng đợi:
//   { v: 1, keyId, sender, bodyHash, signature, event }
//   bodyHash  = hash chuẩn của event           (giống hệt luồng inbox trực tiếp)
//   signature = HMAC-SHA256(secret, "coc-amqp-v1\n" + keyId + "\n" + sender + "\n" + bodyHash)
//
// ★ Khác biệt then chốt so với ký HTTP (service-hmac.ts): KHÔNG có cửa sổ thời gian 300 giây!
// Lý do: event có thể nằm trong hàng đợi HÀNG GIỜ trước khi được giao. Nếu kiểm tra timestamp
// thì event cũ hợp lệ sẽ bị từ chối oan. Thay vào đó, chống trùng bằng inbox bền: eventId + bodyHash
// — event giao 2 lần thì lần 2 nhìn thấy eventId đã có trong inbox → bỏ qua (idempotency).
//
// Xoay key (key rotation): thêm key mới vào MỌI bên nhận trước → rồi mới cho bên gửi dùng key mới
// → hủy key cũ sau window retention. Làm ngược lại = key mới không ai nhận diện được, sập luôn.
import { createHmac, timingSafeEqual } from 'node:crypto';
import { ServiceError } from './errors.js';
import type { BusinessEvent, EventOwner } from './ports.js';
import type { Keyring, ServiceKey } from './service-hmac.js';
import { canonicalBodyHash, validateEventEnvelope } from './transport.js';

export const ENVELOPE_VERSION = 1;
export const MAX_ENVELOPE_BYTES = 64_000; // [VI] phong bì quá 64KB bị chặn ngay — chống bomb
const OWNERS = new Set<string>(['learning', 'progress', 'ai']);
const KEY_ID = /^[A-Za-z0-9._-]{1,64}$/;
const HEX64 = /^[0-9a-f]{64}$/;

export interface SignedEnvelope {
  v: 1;
  keyId: string;
  sender: EventOwner;
  bodyHash: string;
  signature: string;
  event: BusinessEvent;
}

/** [VI] Công thức tính chữ ký: trộn tiêu đề "coc-amqp-v1" + keyId + sender + bodyHash.
 * Tiêu đề riêng (domain separation) để một chữ ký của luồng event KHÔNG THỂ bị đem
 * sang dùng cho luồng HTTP — hai loại chữ ký không lẫn lộn nhau được. */
function mac(key: ServiceKey, sender: string, bodyHash: string): Buffer {
  return createHmac('sha256', key.secret)
    .update(`coc-amqp-v1\n${key.keyId}\n${sender}\n${bodyHash}`, 'utf8')
    .digest();
}

/** [VI] Chọn key để ký: key ĐẦU TIÊN trong chùm có sender trùng owner này. */
export function signingKeyFor(
  keyring: Keyring | undefined,
  owner: EventOwner,
): ServiceKey | undefined {
  return keyring ? [...keyring.values()].find((key) => key.sender === owner) : undefined;
}

/** [VI] Bên GỬI: đóng event vào phong bì có chữ ký, trả về Buffer JSON để đẩy lên broker. */
export function signEnvelope(key: ServiceKey, event: BusinessEvent): Buffer {
  // [VI] Chốt an toàn: key của Learning mà ký event khai producer là "ai" → FORBIDDEN ngay.
  // Chữ ký gắn chặt danh tính; không ai ký hộ ai được.
  if (!OWNERS.has(key.sender) || event.producer !== key.sender) {
    throw new ServiceError('FORBIDDEN', { details: { reason: 'PRODUCER_KEY_MISMATCH' } });
  }
  const bodyHash = canonicalBodyHash(event);
  const envelope: SignedEnvelope = {
    v: ENVELOPE_VERSION,
    keyId: key.keyId,
    sender: key.sender as EventOwner,
    bodyHash,
    signature: mac(key, key.sender, bodyHash).toString('hex'),
    event,
  };
  return Buffer.from(JSON.stringify(envelope), 'utf8');
}

export interface VerifiedEnvelope {
  event: BusinessEvent;
  bodyHash: string;
  sender: EventOwner;
  keyId: string;
}

/**
 * [VI] Bên NHẬN: mở phong bì ra xác thực. Thứ tự:
 *  1. Không có chùm chìa? → AUTH_REQUIRED (fail closed)
 *  2. Quá 64KB?           → PAYLOAD_TOO_LARGE (chặn TRƯỚC khi parse — chống bomb)
 *  3. JSON lỗi / thiếu trường / sai format? → VALIDATION_ERROR
 *  4. keyId lạ?           → AUTH_REQUIRED
 *  5. Chữ ký không khớp?  → AUTH_REQUIRED
 *  6. Người ký ≠ producer khai trong event? → FORBIDDEN (chống mạo danh)
 * Lưu ý cuối: KHÔNG BAO GIỜ tin header của RabbitMQ — chỉ chữ ký HMAC mới đáng tin.
 */
export function verifyEnvelope(keyring: Keyring | undefined, raw: Buffer): VerifiedEnvelope {
  if (!keyring || keyring.size === 0) throw new ServiceError('AUTH_REQUIRED');
  if (raw.length > MAX_ENVELOPE_BYTES) throw new ServiceError('PAYLOAD_TOO_LARGE');
  let parsed: Partial<SignedEnvelope> | null;
  try {
    parsed = JSON.parse(raw.toString('utf8')) as Partial<SignedEnvelope>;
  } catch {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'envelope' } });
  }
  if (
    !parsed ||
    typeof parsed !== 'object' ||
    parsed.v !== ENVELOPE_VERSION ||
    typeof parsed.keyId !== 'string' ||
    !KEY_ID.test(parsed.keyId) ||
    typeof parsed.sender !== 'string' ||
    !OWNERS.has(parsed.sender) ||
    typeof parsed.bodyHash !== 'string' ||
    !HEX64.test(parsed.bodyHash) ||
    typeof parsed.signature !== 'string' ||
    !HEX64.test(parsed.signature)
  ) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'envelope' } });
  }
  const key = keyring.get(parsed.keyId);
  if (!key) throw new ServiceError('AUTH_REQUIRED');
  const event = validateEventEnvelope(parsed.event);
  const bodyHash = canonicalBodyHash(event);
  const expected = mac(key, parsed.sender, bodyHash);
  if (
    bodyHash !== parsed.bodyHash ||
    !timingSafeEqual(expected, Buffer.from(parsed.signature, 'hex'))
  ) {
    throw new ServiceError('AUTH_REQUIRED');
  }
  if (key.sender !== parsed.sender || event.producer !== parsed.sender) {
    throw new ServiceError('FORBIDDEN');
  }
  return { event, bodyHash, sender: parsed.sender as EventOwner, keyId: key.keyId };
}
