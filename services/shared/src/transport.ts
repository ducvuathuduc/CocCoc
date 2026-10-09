import { randomUUID } from 'node:crypto';
export type ServiceName = 'learning' | 'progress' | 'ai';
export interface FunctionContext {
  req: {
    method: string;
    path: string;
    headers: Record<string, string | undefined>;
    bodyText?: string;
  };
  res: { json: (body: unknown, status?: number, headers?: Record<string, string>) => unknown };
}
export function createFunctionHandler(service: ServiceName) {
  return async (context: FunctionContext): Promise<unknown> => {
    const candidate = context.req.headers['x-request-id'];
    const requestId =
      candidate && /^[A-Za-z0-9-]{1,64}$/.test(candidate) ? candidate : randomUUID();
    const headers = { 'X-Request-ID': requestId, 'Cache-Control': 'no-store' };
    if (context.req.method === 'GET' && context.req.path === '/health') {
      return context.res.json(
        { service, buildId: process.env.BUILD_ID ?? 'local-scaffold', status: 'degraded' },
        200,
        headers,
      );
    }
    const ready = context.req.path === '/ready';
    return context.res.json(
      {
        error: {
          code: ready ? 'AUTH_REQUIRED' : 'SERVICE_NOT_CONFIGURED',
          message: ready
            ? 'Internal authentication required.'
            : 'This scaffold has no enabled business adapter.',
          requestId,
          details: {},
          retryable: false,
        },
      },
      ready ? 401 : 503,
      headers,
    );
  };
}
