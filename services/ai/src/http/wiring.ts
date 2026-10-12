// Ai HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Business routes are added here only when their docs/api/openapi.yaml operation is implemented.
import type { ServiceWiring } from '../../../shared/src/transport.js';
import type { AiPersistence } from '../persistence/port.js';

export function aiWiring(_persistence: AiPersistence): ServiceWiring {
  return { routes: [] };
}
