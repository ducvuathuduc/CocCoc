import { randomUUID } from 'node:crypto';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import type { AddressInfo } from 'node:net';
import type { RawAppwriteContext } from './appwrite-entry.js';
import { corsOriginsFromEnv, corsResponseHeaders } from './cors.js';
import { ServiceError, toErrorResponse } from './errors.js';
import { LARGE_BODY_LIMIT, type FunctionContext, type ServiceName } from './transport.js';

export type HostedHandler = (context: RawAppwriteContext) => Promise<unknown>;

export interface HttpRuntimeOptions {
  service: ServiceName;
  port?: number;
  host?: '127.0.0.1' | '0.0.0.0';
  requestTimeoutMs?: number;
  maxInFlight?: number;
}

export interface HttpRuntime {
  listen(): Promise<AddressInfo>;
  close(): Promise<void>;
}

const APPWRITE_HEADER = /^x-appwrite-/i;
const MIN_TIMEOUT_MS = 1000;
const MAX_TIMEOUT_MS = 30_000;

function boundedInt(raw: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = raw === undefined ? fallback : Number(raw);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) return fallback;
  return parsed;
}

function requestHeaders(request: IncomingMessage): Record<string, string | undefined> {
  const headers: Record<string, string | undefined> = {};
  for (const [name, value] of Object.entries(request.headers)) {
    if (APPWRITE_HEADER.test(name) || value === undefined) continue;
    headers[name.toLowerCase()] = Array.isArray(value) ? value.join(',') : value;
  }
  return headers;
}

function sendJson(
  response: ServerResponse,
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): void {
  if (response.headersSent || response.writableEnded) return;
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...headers,
  });
  response.end(JSON.stringify(body));
}

function sendError(
  response: ServerResponse,
  error: unknown,
  cors: Record<string, string> = {},
): void {
  const requestId = randomUUID();
  const failure = toErrorResponse(error, requestId);
  sendJson(response, failure.body, failure.status, {
    'X-Request-ID': requestId,
    ...cors,
    ...(failure.retryAfterSeconds === undefined
      ? {}
      : { 'Retry-After': String(failure.retryAfterSeconds) }),
  });
}

function requestOrigin(request: IncomingMessage): string | undefined {
  const origin = request.headers.origin;
  return Array.isArray(origin) ? origin[0] : origin;
}

async function readBody(request: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  let bytes = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk as Uint8Array);
    bytes += buffer.length;
    if (bytes > LARGE_BODY_LIMIT) {
      request.resume();
      throw new ServiceError('PAYLOAD_TOO_LARGE');
    }
    chunks.push(buffer);
  }
  return Buffer.concat(chunks).toString('utf8');
}

export function createHttpRuntime(
  handler: HostedHandler,
  options: HttpRuntimeOptions,
): HttpRuntime {
  const timeoutMs = options.requestTimeoutMs ?? 15_000;
  const maxInFlight = boundedInt(String(options.maxInFlight ?? 128), 128, 1, 1024);
  // Runtime-level failures bypass the router, so they carry the same allow-listed CORS headers.
  const corsOrigins = corsOriginsFromEnv(process.env['COC_CORS_ALLOWED_ORIGINS']);
  const errorCors = (request: IncomingMessage) =>
    corsResponseHeaders(requestOrigin(request), corsOrigins);
  let inFlight = 0;
  const server: Server = createServer({ maxHeaderSize: 16_384 }, async (request, response) => {
    if (inFlight >= maxInFlight) {
      request.resume();
      sendError(
        response,
        new ServiceError('RATE_LIMITED', { retryAfterSeconds: 1 }),
        errorCors(request),
      );
      return;
    }
    inFlight++;
    try {
      const bodyText = await readBody(request);
      const url = new URL(request.url ?? '/', 'http://runtime.invalid');
      const req: FunctionContext['req'] = {
        method: request.method ?? 'GET',
        path: url.pathname,
        headers: requestHeaders(request),
        bodyText,
        queryString: url.search.startsWith('?') ? url.search.slice(1) : url.search,
      };
      const execution = Promise.resolve().then(() =>
        handler({
          req,
          res: {
            json: (body, status, headers) => {
              sendJson(response, body, status, headers);
              return body;
            },
          },
        }),
      );
      const timer = setTimeout(() => {
        sendError(response, new ServiceError('DEADLINE_EXCEEDED'), errorCors(request));
      }, timeoutMs);
      timer.unref();
      try {
        await execution;
      } catch (error) {
        sendError(response, error, errorCors(request));
      } finally {
        clearTimeout(timer);
      }
      if (!response.writableEnded) {
        sendError(response, new ServiceError('INTERNAL_ERROR'), errorCors(request));
      }
    } catch (error) {
      sendError(
        response,
        error instanceof ServiceError ? error : new ServiceError('VALIDATION_ERROR'),
        errorCors(request),
      );
    } finally {
      inFlight--;
    }
  });
  server.headersTimeout = Math.min(timeoutMs, 10_000);
  server.requestTimeout = timeoutMs;
  server.keepAliveTimeout = 5000;
  server.maxRequestsPerSocket = 100;

  return {
    listen: () =>
      new Promise<AddressInfo>((resolve, reject) => {
        server.once('error', reject);
        server.listen(options.port ?? 0, options.host ?? '127.0.0.1', () => {
          server.off('error', reject);
          resolve(server.address() as AddressInfo);
        });
      }),
    close: () =>
      new Promise<void>((resolve, reject) => {
        if (!server.listening) return resolve();
        server.close((error) => (error ? reject(error) : resolve()));
        server.closeIdleConnections();
      }),
  };
}

export async function runHttpProcess(
  handler: HostedHandler,
  options: { service: ServiceName },
): Promise<void> {
  const hostValue = process.env['HOST'];
  const host = hostValue === '0.0.0.0' ? '0.0.0.0' : '127.0.0.1';
  const runtime = createHttpRuntime(handler, {
    service: options.service,
    host,
    port: boundedInt(process.env['PORT'], 8080, 1, 65_535),
    requestTimeoutMs: boundedInt(
      process.env['COC_HTTP_REQUEST_TIMEOUT_MS'],
      15_000,
      MIN_TIMEOUT_MS,
      MAX_TIMEOUT_MS,
    ),
    maxInFlight: boundedInt(process.env['COC_HTTP_MAX_IN_FLIGHT'], 128, 1, 1024),
  });
  const address = await runtime.listen();
  process.stdout.write(
    `${JSON.stringify({ service: options.service, runtime: 'http', port: address.port })}\n`,
  );
  let closing = false;
  const close = () => {
    if (closing) return;
    closing = true;
    void runtime.close().then(
      () => process.exit(0),
      () => process.exit(1),
    );
  };
  process.once('SIGTERM', close);
  process.once('SIGINT', close);
}
