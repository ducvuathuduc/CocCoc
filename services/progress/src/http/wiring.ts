// Progress HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Business routes are added here only when their docs/api/openapi.yaml operation is implemented.
import type { ServiceWiring } from '../../../shared/src/transport.js';
import { createProgressEventConsumer } from '../application/consume-events.js';
import type { ProgressPersistence } from '../persistence/port.js';

export function progressWiring(persistence: ProgressPersistence): ServiceWiring {
  return { routes: [], eventConsumer: createProgressEventConsumer(persistence) };
}
