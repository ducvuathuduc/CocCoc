// Progress HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Business routes are the docs/api/openapi.yaml operations tagged progress (./routes.ts);
// withRequestScope (./scope.ts) supplies path parameters and the Idempotency-Key.
import type { FunctionContext, ServiceWiring } from '../../../shared/src/transport.js';
import { createProgressEventConsumer } from '../application/consume-events.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { extendedRoutes } from './routes-extended.js';
import { PROGRESS_ROUTE_TEMPLATES, progressRoutes } from './routes.js';
import { withRequestScope } from './scope.js';

export function progressWiring(persistence: ProgressPersistence): ServiceWiring {
  return {
    routes: [...progressRoutes(persistence), ...extendedRoutes(persistence)],
    eventConsumer: createProgressEventConsumer(persistence),
  };
}

/** Wrap the shared router so templated paths and idempotency keys reach the handlers. */
export function scopeProgressHandler(router: (context: FunctionContext) => Promise<unknown>) {
  return withRequestScope(router, PROGRESS_ROUTE_TEMPLATES);
}
