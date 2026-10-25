// LOCAL DEV composition root for `pnpm dev:services`. Same wiring as the hosted entrypoint,
// but with the explicit in-memory adapter and mode 'local-dev'. Never imported by src/index.ts.
import { createRouter } from '../../shared/src/transport.js';
import type { Keyring } from '../../shared/src/service-hmac.js';
import { httpRelayDeliver, httpWatermark } from './application/relay-http.js';
import { progressWiring, scopeProgressHandler, type ProgressJobPorts } from './http/wiring.js';
import { createMemoryProgressPersistence } from './persistence/memory.js';

export function createDevHandler(
  keyring: Keyring,
  env: Record<string, string | undefined> = process.env,
) {
  const persistence = createMemoryProgressPersistence(Date.now, { strictSchema: true });
  // Job ports point at the sibling dev services; nothing runs on a timer here (the scheduler
  // ticks are signed POSTs, e.g. from `pnpm dev:smoke` or a maintainer key).
  const ownKey = [...keyring.values()].find((k) => k.sender === 'progress');
  const base = Number(env['COC_DEV_PORT_BASE'] ?? 4101);
  const ports: ProgressJobPorts = ownKey
    ? {
        deliver: httpRelayDeliver({
          key: ownKey,
          targets: { learning: `http://127.0.0.1:${base}`, ai: `http://127.0.0.1:${base + 2}` },
        }),
        watermark: httpWatermark({ key: ownKey, learningBaseUrl: `http://127.0.0.1:${base}` }),
      }
    : {};
  const wiring = progressWiring(persistence, ports, { allowSimulatedCommerce: true });
  const handler = createRouter({
    service: 'progress',
    persistence,
    mode: 'local-dev',
    keyring,
    buildId: 'local-dev',
    ...(wiring.routes ? { routes: wiring.routes } : {}),
    eventConsumer: wiring.eventConsumer,
  });
  return { handler: scopeProgressHandler(handler), persistence };
}
