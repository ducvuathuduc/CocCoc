import test from 'node:test';
import assert from 'node:assert/strict';
import { loadKit } from '../../services/learning/test/helpers/kit.mjs';
import { generateContentKey } from '../content/generate-content-key.mjs';

const kit = await loadKit('generate-content-key');

test('a generated pair signs with the seed and verifies with the public key the service loads', () => {
  const key = generateContentKey('staging-content-1');
  assert.match(key.seedHex, /^[0-9a-f]{64}$/);
  assert.match(key.publicKeyHex, /^[0-9a-f]{64}$/);

  const privateKey = kit.ed25519FromSeed(Buffer.from(key.seedHex, 'hex'));
  assert.equal(kit.publicKeyHex(privateKey), key.publicKeyHex);
  const ring = kit.parseContentKeyring(
    JSON.stringify([{ keyId: key.keyId, publicKeyHex: key.publicKeyHex }]),
  );
  const signature = kit.signText(privateKey, 'canonical manifest bytes');
  assert.equal(kit.verifyText(ring, key.keyId, 'canonical manifest bytes', signature), true);
  assert.equal(kit.verifyText(ring, key.keyId, 'tampered', signature), false);
});

test('every call makes a new key, and it is never the well-known dev key', () => {
  const a = generateContentKey('staging-content-1');
  const b = generateContentKey('staging-content-1');
  assert.notEqual(a.seedHex, b.seedHex);
  assert.notEqual(a.publicKeyHex, kit.devContentPublicKeyHex());
  assert.throws(() => generateContentKey('dev-content-1'), /DEV_KEY_ID_RESERVED/);
  assert.throws(() => generateContentKey('../x'), /INVALID_KEY_ID/);
  assert.throws(() => generateContentKey(undefined), /INVALID_KEY_ID/);
});
