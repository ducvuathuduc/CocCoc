import test from 'node:test';
import assert from 'node:assert/strict';
import {
  canonicalPath,
  canonicalQuery,
  createKeyring,
  parseKeyring,
  signServiceRequest,
  verifyServiceRequest,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

// Expected signatures computed independently (Python hmac/hashlib/urllib.parse.quote).
const key = {
  keyId: 'learning-progress-1',
  sender: 'learning',
  secret: Buffer.from([...Array(32).keys()]),
};
const keyring = createKeyring([key]);
const NOW = 1760000000;
const WATERMARK_KEYS = ['before', 'z'];

function headersOf(signed) {
  return Object.fromEntries(Object.entries(signed).map(([k, v]) => [k.toLowerCase(), v]));
}
function verify(overrides = {}) {
  return verifyServiceRequest({
    keyring,
    method: 'POST',
    path: '/internal/events',
    query: '',
    allowedQueryKeys: [],
    body: '{"eventId":"x","note":"héllo wörld"}',
    nowSeconds: NOW,
    allowedSenders: ['learning'],
    ...overrides,
    headers: overrides.headers ?? {},
  });
}

test('fixed signing fixtures: Unicode body, reordered/escaped query, Unicode+space path', () => {
  const post = signServiceRequest({
    key,
    method: 'post',
    path: '/internal/events',
    body: '{"eventId":"x","note":"héllo wörld"}',
    nowSeconds: NOW,
  });
  assert.equal(
    post['X-Service-Signature'],
    '298813784f2bf984f962cacc36e14fa9793ac0c49456094b6056bb57ac4fb4de',
  );
  assert.equal(post['X-Service-Timestamp'], '1760000000');
  assert.equal(
    canonicalQuery('z=a%20b%2F%C3%BC&before=2026-10-12T00:00:00Z', WATERMARK_KEYS),
    '?before=2026-10-12T00%3A00%3A00Z&z=a%20b%2F%C3%BC',
  );
  const get = signServiceRequest({
    key,
    method: 'GET',
    path: '/internal/outbox-watermark',
    query: 'z=a%20b%2F%C3%BC&before=2026-10-12T00%3A00%3A00Z',
    allowedQueryKeys: WATERMARK_KEYS,
    body: '',
    nowSeconds: NOW,
  });
  assert.equal(
    get['X-Service-Signature'],
    '920977751c46a27eae28009a41b7c067d4219cfa6ded7c682dcd905c5d903906',
  );
  assert.equal(canonicalPath('/internal/café x'), '/internal/caf%C3%A9%20x');
  assert.equal(canonicalPath('/internal/caf%c3%a9%20x'), '/internal/caf%C3%A9%20x');
  const path = signServiceRequest({
    key,
    method: 'GET',
    path: '/internal/caf%C3%A9%20x',
    body: '',
    nowSeconds: NOW,
  });
  assert.equal(
    path['X-Service-Signature'],
    '301f1b5a3cf90eeabecee2dd8d7df84aa315ea96e46aae09f43a15dc8c1348d3',
  );
});

test('valid signature verifies and returns the key sender', () => {
  const signed = signServiceRequest({
    key,
    method: 'POST',
    path: '/internal/events',
    body: '{"eventId":"x","note":"héllo wörld"}',
    nowSeconds: NOW,
  });
  assert.deepEqual(verify({ headers: headersOf(signed) }), {
    keyId: key.keyId,
    sender: 'learning',
  });
});

test('body tampering, method change, and path change are rejected', () => {
  const signed = headersOf(
    signServiceRequest({
      key,
      method: 'POST',
      path: '/internal/events',
      body: '{"a":1}',
      nowSeconds: NOW,
    }),
  );
  assert.throws(() => verify({ headers: signed, body: '{"a":2}' }), { code: 'AUTH_REQUIRED' });
  assert.throws(() => verify({ headers: signed, body: '{"a":1}', method: 'PUT' }), {
    code: 'AUTH_REQUIRED',
  });
  assert.throws(() => verify({ headers: signed, body: '{"a":1}', path: '/internal/event' }), {
    code: 'AUTH_REQUIRED',
  });
  assert.doesNotThrow(() => verify({ headers: signed, body: '{"a":1}' }));
});

test('replay window: timestamps beyond 300s skew either way are expired', () => {
  const signed = headersOf(
    signServiceRequest({
      key,
      method: 'POST',
      path: '/internal/events',
      body: '{}',
      nowSeconds: NOW,
    }),
  );
  assert.doesNotThrow(() => verify({ headers: signed, body: '{}', nowSeconds: NOW + 300 }));
  assert.doesNotThrow(() => verify({ headers: signed, body: '{}', nowSeconds: NOW - 300 }));
  assert.throws(() => verify({ headers: signed, body: '{}', nowSeconds: NOW + 301 }), {
    code: 'AUTH_EXPIRED',
  });
  assert.throws(() => verify({ headers: signed, body: '{}', nowSeconds: NOW - 301 }), {
    code: 'AUTH_EXPIRED',
  });
});

test('query duplication, unknown keys, dot segments and duplicate slashes are rejected', () => {
  assert.throws(() => canonicalQuery('before=a&before=b', WATERMARK_KEYS), {
    code: 'VALIDATION_ERROR',
  });
  assert.throws(() => canonicalQuery('other=1', WATERMARK_KEYS), { code: 'VALIDATION_ERROR' });
  assert.throws(() => canonicalQuery('before=%zz', WATERMARK_KEYS), { code: 'VALIDATION_ERROR' });
  assert.equal(canonicalQuery('', WATERMARK_KEYS), '');
  for (const bad of [
    '/internal/../ready',
    '/internal/./events',
    '//internal/events',
    '/internal//events',
    '/internal/%2E%2E',
    '/internal/a%2Fb',
    'internal',
  ]) {
    assert.throws(() => canonicalPath(bad), { code: 'VALIDATION_ERROR' }, bad);
  }
});

test('malformed headers, unknown key, wrong sender and missing keyring fail closed', () => {
  const signed = headersOf(
    signServiceRequest({
      key,
      method: 'POST',
      path: '/internal/events',
      body: '{}',
      nowSeconds: NOW,
    }),
  );
  assert.throws(() => verify({ headers: {}, body: '{}' }), { code: 'AUTH_REQUIRED' });
  assert.throws(
    () =>
      verify({
        headers: { ...signed, 'x-service-signature': signed['x-service-signature'].toUpperCase() },
        body: '{}',
      }),
    { code: 'AUTH_REQUIRED' },
  );
  assert.throws(
    () => verify({ headers: { ...signed, 'x-service-timestamp': `0${NOW}` }, body: '{}' }),
    { code: 'AUTH_REQUIRED' },
  );
  assert.throws(
    () => verify({ headers: { ...signed, 'x-service-timestamp': `${NOW}.5` }, body: '{}' }),
    { code: 'AUTH_REQUIRED' },
  );
  assert.throws(
    () => verify({ headers: { ...signed, 'x-service-key-id': 'unknown' }, body: '{}' }),
    { code: 'AUTH_REQUIRED' },
  );
  assert.throws(() => verify({ headers: signed, body: '{}', allowedSenders: ['progress'] }), {
    code: 'FORBIDDEN',
  });
  assert.throws(() => verify({ headers: signed, body: '{}', keyring: undefined }), {
    code: 'AUTH_REQUIRED',
  });
});

test('keyring rejects short secrets, bad senders and duplicate IDs; parses config JSON', () => {
  assert.throws(
    () => createKeyring([{ ...key, secret: Buffer.alloc(31) }]),
    /SERVICE_KEY_TOO_SHORT/,
  );
  assert.throws(() => createKeyring([{ ...key, sender: 'mobile' }]), /INVALID_SERVICE_KEY_SENDER/);
  assert.throws(() => createKeyring([key, key]), /DUPLICATE_SERVICE_KEY_ID/);
  assert.equal(parseKeyring(undefined), undefined);
  const ring = parseKeyring(
    JSON.stringify([{ keyId: 'k1', sender: 'progress', secretHex: 'ab'.repeat(32) }]),
  );
  assert.equal(ring.get('k1').sender, 'progress');
  assert.throws(() => parseKeyring('{"keyId":"k1"}'), /INVALID_SERVICE_KEYRING/);
});
