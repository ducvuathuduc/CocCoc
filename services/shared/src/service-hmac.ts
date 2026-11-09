// [VI] Ký số HMAC cho các request NỘI BỘ giữa các service (Learning ↔ Progress ↔ AI).
// Ý tưởng như "thư có con dấu": người gửi trộn nội dung thư với MẬT KHẨU CHUNG (secret)
// bằng công thức HMAC-SHA256 → ra chữ ký. Người nhận làm lại cùng công thức: khớp = thư thật.
//
// Chuỗi được ký gồm 4 phần (xem signingString() bên dưới):
//   timestamp \n METHOD \n path \n sha256hex(body)
// → Kẻ tấn công sửa bất kỳ phần nào (đổi body, đổi đường dẫn) thì chữ ký lệch ngay.
//
// Chống "replay" (bắt gói tin cũ gửi lại): timestamp lệch quá 300 giây là bị từ chối.
// Với event qua hàng đợi (RabbitMQ) xem event-envelope.ts — event nằm queue lâu nên
// không dùng thời gian, mà dùng eventId + inbox để chống trùng.
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { ServiceError } from './errors.js';

/** [VI] 'scheduler' chỉ được ký các lệnh tick /internal/jobs/* (không route nào khác chấp nhận nó). */
export type ServiceSender = 'learning' | 'progress' | 'ai' | 'maintainer' | 'scheduler';
export interface ServiceKey {
  keyId: string; // [VI] tên chìa khóa, vd "learning-key-1" — gửi kèm để bên nhận biết tra chìa nào
  sender: ServiceSender; // [VI] chìa này thuộc về ai — Learning, Progress, AI...
  secret: Buffer; // [VI] mật khẩu bí mật (≥32 bytes) — chỉ nằm server, tuyệt đối không đưa client
}
export type Keyring = ReadonlyMap<string, ServiceKey>;

export const MAX_SKEW_SECONDS = 300; // [VI] lệch giờ tối đa giữa gửi & nhận: 5 phút
export const MIN_KEY_BYTES = 32; // [VI] chìa bí mật phải dài ≥32 bytes, chống dò mò vét cạn
/** [VI] Tên 3 header đi kèm mọi request nội bộ có chữ ký; cũng được cho phép trong CORS preflight. */
export const SERVICE_HMAC_HEADERS = [
  'X-Service-Key-Id',
  'X-Service-Timestamp',
  'X-Service-Signature',
] as const;
const SENDERS = new Set<ServiceSender>(['learning', 'progress', 'ai', 'maintainer', 'scheduler']);
const KEY_ID = /^[A-Za-z0-9._-]{1,64}$/;
const TIMESTAMP = /^[1-9][0-9]{0,15}$/;
const SIGNATURE = /^[0-9a-f]{64}$/;

export function createKeyring(keys: readonly ServiceKey[]): Keyring {
  const ring = new Map<string, ServiceKey>();
  for (const key of keys) {
    if (!KEY_ID.test(key.keyId)) throw new Error('INVALID_SERVICE_KEY_ID');
    if (!SENDERS.has(key.sender)) throw new Error('INVALID_SERVICE_KEY_SENDER');
    if (key.secret.length < MIN_KEY_BYTES) throw new Error('SERVICE_KEY_TOO_SHORT');
    if (ring.has(key.keyId)) throw new Error('DUPLICATE_SERVICE_KEY_ID');
    ring.set(key.keyId, key);
  }
  return ring;
}

/**
 * [VI] Tạo "chùm chìa" từ cấu hình JSON: [{"keyId","sender","secretHex"}].
 * Trả về undefined khi chưa cấu hình → mọi route nội bộ sẽ fail closed (chặn hết).
 * Đây là chủ ý: KHÔNG cấu hình key thì KHÔNG ai gọi được nhau, an toàn hơn là "tạm cho qua".
 */
export function parseKeyring(raw: string | undefined): Keyring | undefined {
  if (!raw) return undefined;
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error('INVALID_SERVICE_KEYRING');
  return createKeyring(
    parsed.map((entry: unknown) => {
      const value = entry as { keyId?: unknown; sender?: unknown; secretHex?: unknown };
      if (
        typeof value.keyId !== 'string' ||
        typeof value.sender !== 'string' ||
        typeof value.secretHex !== 'string' ||
        !/^(?:[0-9a-f]{2})+$/i.test(value.secretHex)
      ) {
        throw new Error('INVALID_SERVICE_KEYRING');
      }
      return {
        keyId: value.keyId,
        sender: value.sender as ServiceSender,
        secret: Buffer.from(value.secretHex, 'hex'),
      };
    }),
  );
}

/** [VI] Mã hóa chuẩn RFC3986: giữ nguyên ký tự an toàn, còn lại thành %XX viết hoa. */
export function rfc3986Encode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function strictDecode(value: string): string {
  if (/%(?![0-9A-Fa-f]{2})/.test(value)) throw new ServiceError('VALIDATION_ERROR');
  try {
    return decodeURIComponent(value);
  } catch {
    throw new ServiceError('VALIDATION_ERROR');
  }
}

/** [VI] Chuẩn hóa đường dẫn URL: giải mã rồi mã hóa lại từng đoạn; từ chối ".", "..", "//".
 * Quan trọng vì bên gửi và bên nhận phải tính ra CHÍNH XÁC cùng một chuỗi mới so chữ ký được.
 * Nếu không, "/a/b" và "//a//b" (vẫn trỏ tới chỗ nhau) sẽ cho 2 chữ ký khác nhau → false mismatch. */
export function canonicalPath(rawPath: string): string {
  if (!rawPath.startsWith('/')) throw new ServiceError('VALIDATION_ERROR');
  if (rawPath === '/') return '/';
  const segments = rawPath.slice(1).split('/');
  return (
    '/' +
    segments
      .map((segment) => {
        const decoded = strictDecode(segment);
        if (!decoded || decoded === '.' || decoded === '..' || decoded.includes('/')) {
          throw new ServiceError('VALIDATION_ERROR');
        }
        return rfc3986Encode(decoded);
      })
      .join('/')
  );
}

/** [VI] Chuẩn hóa query: sắp xếp key theo alphabet, từ chối key trùng/key lạ.
 * Cùng lý do canonicalPath: "?b=2&a=1" và "?a=1&b=2" phải ra cùng chuỗi để ký khớp nhau. */
export function canonicalQuery(rawQuery: string, allowedKeys: readonly string[]): string {
  const query = rawQuery.startsWith('?') ? rawQuery.slice(1) : rawQuery;
  if (!query) return '';
  const seen = new Map<string, string>();
  for (const part of query.split('&')) {
    if (!part) throw new ServiceError('VALIDATION_ERROR');
    const index = part.indexOf('=');
    const key = strictDecode(index < 0 ? part : part.slice(0, index));
    const value = index < 0 ? '' : strictDecode(part.slice(index + 1));
    if (!allowedKeys.includes(key) || seen.has(key)) throw new ServiceError('VALIDATION_ERROR');
    seen.set(key, value);
  }
  const keys = [...seen.keys()].sort();
  return (
    '?' + keys.map((key) => `${rfc3986Encode(key)}=${rfc3986Encode(seen.get(key) ?? '')}`).join('&')
  );
}

/** [VI] Tính SHA-256 của body → hex. Dùng hash thay vì body thô để chuỗi ký có độ dài cố định. */
export function sha256Hex(body: string | Uint8Array): string {
  return createHash('sha256').update(body).digest('hex');
}

/** [VI] Ghép 4 phần thành "bản gốc" cần ký. Mỗi phần ngăn bằng xuống dòng \n. */
export function signingString(
  timestamp: string,
  method: string,
  pathAndQuery: string,
  rawBody: string,
): string {
  return `${timestamp}\n${method.toUpperCase()}\n${pathAndQuery}\n${sha256Hex(rawBody)}`;
}

export interface SignInput {
  key: ServiceKey;
  method: string;
  path: string;
  query?: string;
  allowedQueryKeys?: readonly string[];
  body: string;
  nowSeconds: number;
}

/** [VI] Bên GỬI gọi hàm này: tạo 3 header X-Service-* đính kèm request.
 * Giống gửi thư kèm: CMND (keyId) + ngày ký (timestamp) + con dấu (signature). */
export function signServiceRequest(input: SignInput): Record<string, string> {
  const timestamp = String(Math.floor(input.nowSeconds));
  const pathAndQuery =
    canonicalPath(input.path) + canonicalQuery(input.query ?? '', input.allowedQueryKeys ?? []);
  const signature = createHmac('sha256', input.key.secret)
    .update(signingString(timestamp, input.method, pathAndQuery, input.body), 'utf8')
    .digest('hex');
  return {
    'X-Service-Key-Id': input.key.keyId,
    'X-Service-Timestamp': timestamp,
    'X-Service-Signature': signature,
  };
}

export interface VerifyInput {
  keyring: Keyring | undefined;
  headers: Record<string, string | undefined>;
  method: string;
  path: string;
  query: string;
  allowedQueryKeys: readonly string[];
  body: string;
  nowSeconds: number;
  allowedSenders: readonly ServiceSender[];
}

/**
 * [VI] Bên NHẬN gọi hàm này để xác thực request nội bộ. Trả về danh tính người gửi thật.
 * Nguyên tắc "fail closed": mặc định là CHẶN, chỉ khi mọi lớp kiểm tra đều pass mới cho qua.
 *
 * Thứ tự kiểm tra (từ rẻ đến đắt) — mỗi lớp fail là trả lỗi ngay, không cố "fix hộ":
 *  1. Không có chìa nào cấu hình?        → AUTH_REQUIRED (chặn hết)
 *  2. Thiếu 1 trong 3 header?            → AUTH_REQUIRED
 *  3. Định dạng header sai (regex)?      → AUTH_REQUIRED (kiểm tra format TRƯỚC khi dùng)
 *  4. keyId không có trong chùm chìa?    → AUTH_REQUIRED
 *  5. Timestamp lệch quá 300s?           → AUTH_EXPIRED (chống replay gói tin cũ)
 *  6. Tự tính lại chữ ký mà không khớp?  → AUTH_REQUIRED
 *  7. Chìa hợp lệ nhưng không được phép gọi route này? → FORBIDDEN
 */
export function verifyServiceRequest(input: VerifyInput): { keyId: string; sender: ServiceSender } {
  if (!input.keyring || input.keyring.size === 0) throw new ServiceError('AUTH_REQUIRED');
  const keyId = input.headers['x-service-key-id'];
  const timestamp = input.headers['x-service-timestamp'];
  const signature = input.headers['x-service-signature'];
  if (!keyId || !timestamp || !signature) throw new ServiceError('AUTH_REQUIRED');
  if (!KEY_ID.test(keyId) || !TIMESTAMP.test(timestamp) || !SIGNATURE.test(signature)) {
    throw new ServiceError('AUTH_REQUIRED');
  }
  const key = input.keyring.get(keyId);
  if (!key) throw new ServiceError('AUTH_REQUIRED');
  if (Math.abs(input.nowSeconds - Number(timestamp)) > MAX_SKEW_SECONDS) {
    throw new ServiceError('AUTH_EXPIRED');
  }
  const pathAndQuery =
    canonicalPath(input.path) + canonicalQuery(input.query, input.allowedQueryKeys);
  const expected = createHmac('sha256', key.secret)
    .update(signingString(timestamp, input.method, pathAndQuery, input.body), 'utf8')
    .digest();
  // [VI] timingSafeEqual: hàm so sánh mất CÙNG thời gian dù đúng hay sai. Nếu dùng ===
  // thường, hacker đo thời gian trả lời để dò từng ký tự của chữ ký (timing attack).
  if (!timingSafeEqual(expected, Buffer.from(signature, 'hex'))) {
    throw new ServiceError('AUTH_REQUIRED');
  }
  if (!input.allowedSenders.includes(key.sender)) throw new ServiceError('FORBIDDEN');
  return { keyId, sender: key.sender };
}
