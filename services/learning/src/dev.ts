// LOCAL DEV composition root for `pnpm dev:services`. Same wiring as the hosted entrypoint,
// but with the explicit in-memory adapter and mode 'local-dev'. Never imported by src/index.ts.
import { createRouter } from '../../shared/src/transport.js';
import type { Keyring } from '../../shared/src/service-hmac.js';
import { learningWiring } from './http/wiring.js';
import { createMemoryLearningPersistence } from './persistence/memory.js';

export function createDevHandler(keyring: Keyring) {
  const persistence = createMemoryLearningPersistence();
  const wiring = learningWiring(persistence);
  const handler = createRouter({
    service: 'learning',
    persistence,
    mode: 'local-dev',
    keyring,
    buildId: 'local-dev',
    ...(wiring.routes ? { routes: wiring.routes } : {}),
    eventConsumer: wiring.eventConsumer,
  });
  return { handler, persistence };
}
