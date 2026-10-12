// Outbound internal call: signs with the sender's HMAC key (service-hmac.ts) and POSTs JSON.
// Used by event relays (Learning outbox -> Progress inbox) and by `pnpm dev:smoke`.
import { randomUUID } from 'node:crypto';
import { signServiceRequest, type ServiceKey } from './service-hmac.js';

export { signServiceRequest } from './service-hmac.js';

export interface InternalResponse {
  status: number;
  body: unknown;
}

export interface InternalClientOptions {
  key: ServiceKey;
  baseUrl: string;
  fetchImpl?: typeof fetch;
  nowSeconds?: () => number;
}

export function createInternalClient(options: InternalClientOptions) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const nowSeconds = options.nowSeconds ?? (() => Math.floor(Date.now() / 1000));
  const base = options.baseUrl.replace(/\/+$/, '');
  return {
    /** POST a raw JSON body (already serialized) to an internal path. */
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
    /** Signed GET with a query string (e.g. /internal/outbox-watermark?before=...). */
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
    /** Deliver one business event to the receiver's /internal/events. */
    deliverEvent(event: unknown): Promise<InternalResponse> {
      return this.post('/internal/events', JSON.stringify(event));
    },
  };
}
