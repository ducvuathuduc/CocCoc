// `node tools/content/generate-content-key.mjs --key-id staging-content-1`
// Makes a fresh Ed25519 content signing key for a project that must not trust the well-known dev
// key (staging, production). Prints one JSON line:
//   publicKeyHex   goes into COC_CONTENT_PUBLIC_KEYS on the Learning function (public).
//   seedHex        is the signing secret for COC_CONTENT_SIGNING_SEED_HEX at build time. It is
//                  shown once and never written to disk: pipe it straight into the vault.
// Nothing is created in any cloud project. The pair is compatible with integrity.ts
// (ed25519FromSeed / publicKeyFromHex); tools/tests/generate-content-key.test.mjs proves it.
import { generateKeyPairSync } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KEY_ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

export function generateContentKey(keyId) {
  if (!KEY_ID.test(keyId ?? '')) throw new Error('INVALID_KEY_ID');
  if (keyId === 'dev-content-1') throw new Error('DEV_KEY_ID_RESERVED');
  const { privateKey, publicKey } = generateKeyPairSync('ed25519');
  // PKCS#8 and SPKI wrap the raw 32 bytes; the raw bytes are the last 32 of each DER.
  const seed = privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(-32);
  const pub = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
  return { keyId, publicKeyHex: pub.toString('hex'), seedHex: seed.toString('hex') };
}

const invoked = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  const index = process.argv.indexOf('--key-id');
  const keyId = index === -1 ? undefined : process.argv[index + 1];
  try {
    const key = generateContentKey(keyId);
    process.stderr.write(
      'seedHex is the signing secret: store it in the vault now; it is not saved anywhere.\n',
    );
    console.log(JSON.stringify(key));
  } catch (error) {
    process.stderr.write(`${error.message}\nUsage: --key-id <id> (not dev-content-1)\n`);
    process.exit(2);
  }
}
