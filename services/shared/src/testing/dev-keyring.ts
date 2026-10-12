// LOCAL DEV ONLY. Well-known keys for `pnpm dev:services` / `pnpm dev:smoke`; never a hosted
// secret (hosted Functions read COC_SERVICE_KEYS). Override locally with COC_SERVICE_KEYS.
import { createHash } from 'node:crypto';
import { createKeyring, parseKeyring, type Keyring, type ServiceKey } from '../service-hmac.js';

const SENDERS = ['learning', 'progress', 'ai', 'maintainer', 'scheduler'] as const;
export type DevSender = (typeof SENDERS)[number];

export function devKey(sender: DevSender): ServiceKey {
  return {
    keyId: `dev-${sender}`,
    sender,
    secret: createHash('sha256').update(`cocenglish-dev-only:${sender}`).digest(),
  };
}

export function createDevKeyring(env: Record<string, string | undefined> = process.env): Keyring {
  return parseKeyring(env['COC_SERVICE_KEYS']) ?? createKeyring(SENDERS.map(devKey));
}
