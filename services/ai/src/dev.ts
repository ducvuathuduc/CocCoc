// LOCAL DEV composition root for `pnpm dev:services`. Same wiring as the hosted entrypoint,
// but with the explicit in-memory adapter and mode 'local-dev'. Never imported by src/index.ts.
// Optional, local only:
//   COC_DEV_AUTH=1        accept `Authorization: Bearer dev-<userId>` (never in hosted code)
import { randomUUID } from 'node:crypto';
import { ServiceError } from '../../shared/src/errors.js';
import type { AuthPort } from '../../shared/src/auth.js';
import { createRouter } from '../../shared/src/transport.js';
import type { Keyring } from '../../shared/src/service-hmac.js';
import { SCRIPTED_PROVIDER, type AiDeps } from './application/deps.js';
import { DEFAULT_GATES } from './domain/plans.js';
import { aiHandler, aiWiring } from './http/wiring.js';
import { createMemoryAiPersistence } from './persistence/memory.js';

const DEV_TOKEN = /^dev-([A-Za-z0-9][A-Za-z0-9_.-]{0,35})$/;
export const devAuth: AuthPort = {
  async verify(jwt) {
    const match = DEV_TOKEN.exec(jwt);
    if (!match?.[1]) throw new ServiceError('AUTH_REQUIRED');
    return { userId: match[1] };
  },
};

export function createDevHandler(
  keyring: Keyring,
  env: Record<string, string | undefined> = process.env,
) {
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
      ...(env['COC_DEV_AUTH'] === '1' ? { auth: devAuth } : {}),
      ...(wiring.routes ? { routes: wiring.routes } : {}),
      eventConsumer: wiring.eventConsumer,
    }),
  );
  return { handler, persistence };
}
