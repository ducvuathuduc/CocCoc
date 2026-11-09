// [VI] "Khách hàng nội bộ" — service nào muốn GỌI service khác đều dùng file này.
// Mọi request đều được tự động ký HMAC (qua signServiceRequest) rồi mới gửi —
// người gọi không cần biết chi tiết ký thế nào, không thể quên ký, không thể ký sai.
// Ví dụ: relay đẩy event từ outbox của Learning → inbox của Progress (/internal/events),
// hoặc lệnh `pnpm dev:smoke` kiểm tra liên thông giữa 2 service.
import { randomUUID } from 'node:crypto';
import { signServiceRequest, type ServiceKey } from './service-hmac.js';

export { signServiceRequest } from './service-hmac.js';

export interface InternalResponse {
  status: number; // [VI] mã HTTP trả về (200, 4xx, 5xx...)
  body: unknown; // [VI] nội dung JSON đã parse
}

export interface InternalClientOptions {
  key: ServiceKey; // [VI] chìa của BÊN GỬI — chữ ký mang danh tính mình, không phải bên nhận
  baseUrl: string; // [VI] địa chỉ service đích, vd http://127.0.0.1:4102
  fetchImpl?: typeof fetch; // [VI] cho test chèn fetch giả (không cần mạng thật)
  nowSeconds?: () => number; // [VI] cho test "đóng băng" thời gian
}

/** [VI] Tạo client: post() / get() / deliverEvent(). Ví dụ:
 *   const client = createInternalClient({ key, baseUrl: 'http://127.0.0.1:4102' });
 *   await client.deliverEvent(event);  // tự ký + POST tới /internal/events */
export function createInternalClient(options: InternalClientOptions) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const nowSeconds = options.nowSeconds ?? (() => Math.floor(Date.now() / 1000));
  const base = options.baseUrl.replace(/\/+$/, '');
  return {
    /** [VI] POST một body JSON (đã serialize sẵn) tới path nội bộ — tự ký HMAC trước khi gửi. */
    async post(path: string, body: string, requestId = randomUUID()): Promise<InternalResponse> {
      const headers = signServiceRequest({
        key: options.key,
        method: 'POST',
        path,
        body,
        nowSeconds: nowSeconds(),
      });
      const response = await fetchImpl(`${base}${path}`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json', 'X-Request-ID': requestId },
        body,
      });
      const text = await response.text();
      return { status: response.status, body: text ? (JSON.parse(text) as unknown) : null };
    },
    /** [VI] GET có query string (vd /internal/outbox-watermark?before=...) — query được sắp
     * xếp chuẩn để chữ ký bên gửi & bên nhận khớp nhau. */
    async get(
      path: string,
      query: Record<string, string>,
      requestId = randomUUID(),
    ): Promise<InternalResponse> {
      const raw = new URLSearchParams(query).toString().replace(/\+/g, '%20');
      const headers = signServiceRequest({
        key: options.key,
        method: 'GET',
        path,
        query: raw,
        allowedQueryKeys: Object.keys(query),
        body: '',
        nowSeconds: nowSeconds(),
      });
      const response = await fetchImpl(`${base}${path}${raw ? `?${raw}` : ''}`, {
        method: 'GET',
        headers: { ...headers, 'X-Request-ID': requestId },
      });
      const text = await response.text();
      return { status: response.status, body: text ? (JSON.parse(text) as unknown) : null };
    },
    /** [VI] Giao 1 business event tới /internal/events của service đích — luồng chính
     * outbox → inbox giữa các service. */
    deliverEvent(event: unknown): Promise<InternalResponse> {
      return this.post('/internal/events', JSON.stringify(event));
    },
  };
}
