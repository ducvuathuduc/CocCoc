// LOCAL DEV composition root for `pnpm dev:services`. Same wiring as the hosted entrypoint,
// but with the explicit in-memory adapter and mode 'local-dev'. Never imported by src/index.ts.
import { randomUUID } from 'node:crypto';
import { createRouter } from '../../shared/src/transport.js';
import type { Keyring } from '../../shared/src/service-hmac.js';
import { SCRIPTED_PROVIDER, type AiDeps } from './application/deps.js';
import { DEFAULT_GATES } from './domain/plans.js';
import { aiHandler, aiWiring } from './http/wiring.js';
import { createMemoryAiPersistence } from './persistence/memory.js';

export function createDevHandler(keyring: Keyring) {
  const persistence = createMemoryAiPersistence();
  const deps: AiDeps = {
    persistence,
    nowMs: Date.now,
    newId: randomUUID,
    gates: DEFAULT_GATES,
    provider: SCRIPTED_PROVIDER,
  };
  const wiring = aiWiring(deps);
  const handler = aiHandler(
    createRouter({
      service: 'ai',
      persistence,
      mode: 'local-dev',
      keyring,
      buildId: 'local-dev',
      ...(wiring.routes ? { routes: wiring.routes } : {}),
      eventConsumer: wiring.eventConsumer,
    }),
  );
  return { handler, persistence };
}
