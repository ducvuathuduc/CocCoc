// LOCAL DEV / TEST ONLY. Well-known Ed25519 content-signing key for the committed seed content
// (content/vi_en/dist). A hosted Learning service trusts only COC_CONTENT_PUBLIC_KEYS; this key is
// never a production secret and must not be listed there for a real release.
import { createHash } from 'node:crypto';
import { ed25519FromSeed, publicKeyHex, type ContentKeyring } from '../content/integrity.js';
import { createPublicKey } from 'node:crypto';

export const DEV_CONTENT_KEY_ID = 'dev-content-1';

export function devContentPrivateKey() {
  return ed25519FromSeed(
    createHash('sha256').update('cocenglish-dev-only:content-signing').digest(),
  );
}

export function devContentKeyring(): ContentKeyring {
  const publicKey = createPublicKey(devContentPrivateKey());
  return new Map([[DEV_CONTENT_KEY_ID, { keyId: DEV_CONTENT_KEY_ID, publicKey }]]);
}

export function devContentPublicKeyHex(): string {
  return publicKeyHex(devContentPrivateKey());
}
