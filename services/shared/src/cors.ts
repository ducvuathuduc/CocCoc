// Allow-listed CORS for browser clients. The requesting origin is echoed only on an exact
// allow-list match (never '*', so credentialed calls stay possible); anything else gets no
// allow-origin header and the browser blocks the call. Preflight lives in transport.dispatch.
import { SERVICE_HMAC_HEADERS } from './service-hmac.js';

/** Flutter web dev servers when COC_CORS_ALLOWED_ORIGINS is unset. */
export const DEFAULT_CORS_ORIGINS: readonly string[] = [
  'http://localhost:8087',
  'http://127.0.0.1:8087',
];

export const CORS_ALLOWED_METHODS = 'GET, POST, PATCH, DELETE, OPTIONS';
export const CORS_MAX_AGE_SECONDS = 600;
export const CORS_ALLOWED_HEADERS = [
  'authorization',
  'content-type',
  'idempotency-key',
  'x-appwrite-user-jwt',
  ...SERVICE_HMAC_HEADERS.map((name) => name.toLowerCase()),
].join(', ');

/** COC_CORS_ALLOWED_ORIGINS is a comma-separated allow-list; unset or blank keeps the local default. */
export function corsOriginsFromEnv(raw: string | undefined): readonly string[] {
  const origins = (raw ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
  return origins.length > 0 ? origins : DEFAULT_CORS_ORIGINS;
}

/** CORS response headers for one request; disallowed origins get only Vary so caches stay correct. */
export function corsResponseHeaders(
  origin: string | undefined,
  allowed: readonly string[] = DEFAULT_CORS_ORIGINS,
): Record<string, string> {
  if (!origin || !allowed.includes(origin)) return { Vary: 'Origin' };
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': CORS_ALLOWED_METHODS,
    'Access-Control-Allow-Headers': CORS_ALLOWED_HEADERS,
    'Access-Control-Max-Age': String(CORS_MAX_AGE_SECONDS),
    'Access-Control-Allow-Credentials': 'true',
    Vary: 'Origin',
  };
}
