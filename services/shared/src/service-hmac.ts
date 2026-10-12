// Internal service request signing per docs/api/EVENTS_ERRORS.md ("HMAC-SHA256 keys ...").
// Signed string: timestamp \n METHOD \n canonicalPathAndQuery \n sha256hex(rawBody).
// Replay protection: timestamp skew <= 300s here; event IDs/inbox give effect-level dedupe.
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { ServiceError } from './errors.js';

/** 'scheduler' signs only the /internal/jobs/* ticks (no event or business route accepts it). */
export type ServiceSender = 'learning' | 'progress' | 'ai' | 'maintainer' | 'scheduler';
export interface ServiceKey {
  keyId: string;
  sender: ServiceSender;
  secret: Buffer;
}
export type Keyring = ReadonlyMap<string, ServiceKey>;

export const MAX_SKEW_SECONDS = 300;
export const MIN_KEY_BYTES = 32;
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
 * Parse a keyring from configuration JSON: [{"keyId","sender","secretHex"}].
 * Returns undefined when unset so readiness/internal routes fail closed.
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

/** RFC3986 percent-encoding: unreserved kept, everything else as UTF-8 %XX uppercase. */
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

/** Decode then re-encode each segment; reject dot segments, empty/duplicate slashes. */
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

/** Sort keys by code unit, reject duplicate/unknown keys; '' when there is no query. */
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

export function sha256Hex(body: string | Uint8Array): string {
  return createHash('sha256').update(body).digest('hex');
}

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

/** Produce the three X-Service-* headers for an outbound internal request. */
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

/** Verify an inbound internal request; returns the authenticated sender. Fails closed. */
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
  if (!timingSafeEqual(expected, Buffer.from(signature, 'hex'))) {
    throw new ServiceError('AUTH_REQUIRED');
  }
  if (!input.allowedSenders.includes(key.sender)) throw new ServiceError('FORBIDDEN');
  return { keyId, sender: key.sender };
}
