#!/usr/bin/env node
// Validates the generated Postman assets:
//   1. every JSON file parses;
//   2. the collection covers exactly the current OpenAPI operations;
//   3. both environments keep every secret value empty;
//   4. regeneration is byte-identical to the committed artifacts;
//   5. the embedded HMAC signer matches vectors produced by the real
//      services/shared/src/service-hmac.ts signer for raw bodies, canonical
//      path/query handling, timestamps and the dev keyring derivation.
import assert from 'node:assert/strict';
import { createHash, createHmac } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import {
  COLLECTION_PATH,
  LOCAL_ENV_PATH,
  PRE_REQUEST_SCRIPT,
  TEST_ENV_PATH,
  buildArtifacts,
  loadSpec,
  operations,
  ownerFolder,
} from './generate.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REQUIRED_ENVIRONMENT_KEYS = [
  'learning_base_url',
  'progress_base_url',
  'ai_base_url',
  'token_a',
  'token_b',
  'service_signing_mode',
  'service_key_id_learning',
  'service_secret_hex_learning',
  'courseId',
  'sessionId',
  'completionId',
  'expectedRevision',
  'questId',
  'leagueWeekId',
  'purchaseId',
  'groupId',
  'giftId',
  'conversationId',
  'voiceSessionId',
  'assessmentJobId',
];

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`${path.relative(process.cwd(), file)} is not valid JSON: ${error.message}`);
  }
}

function sha256Hex(value) {
  return createHash('sha256').update(value).digest('hex');
}

function nodeCrypto() {
  return {
    sha256Hex(value) {
      return sha256Hex(value);
    },
    hmacSha256Hex(value, secretHex) {
      return createHmac('sha256', Buffer.from(secretHex, 'hex')).update(value).digest('hex');
    },
  };
}

function walkItems(items, callback, trail = []) {
  for (const item of items) {
    if (item.request) {
      callback(item, trail);
    } else if (Array.isArray(item.item)) {
      walkItems(item.item, callback, [...trail, item.name]);
    }
  }
}

function parseBaselineMarker(description) {
  const match = /^OpenAPI operation: `([A-Z]+) ([^`]+)` \(`([^`]+)`\)/.exec(description ?? '');
  if (!match) return null;
  return { method: match[1], apiPath: match[2], operationId: match[3] };
}

function checkCollection(collection, spec, specOperations) {
  assert.equal(
    collection.info?.schema,
    'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  );
  const folderNames = collection.item.map((folder) => folder.name);
  assert.deepEqual(folderNames, ['Learning', 'Progress', 'AI', 'Internal']);

  const expectedByKey = new Map(specOperations.map((op) => [`${op.method} ${op.path}`, op]));
  const seen = new Map();
  const counts = { Learning: 0, Progress: 0, AI: 0, Internal: 0 };
  let scenarioRequests = 0;
  let totalRequests = 0;

  walkItems(collection.item, (item, trail) => {
    totalRequests += 1;
    if (!item.request.description?.startsWith('OpenAPI operation:')) {
      scenarioRequests += 1;
      return;
    }
    const marker = parseBaselineMarker(item.request.description);
    if (!marker) fail(`Baseline request "${item.name}" has a malformed OpenAPI marker`);
    const key = `${marker.method} ${marker.apiPath}`;
    const expected = expectedByKey.get(key);
    if (!expected) fail(`Collection contains an operation not present in OpenAPI: ${key}`);
    if (expected.operationId !== marker.operationId) {
      fail(`Operation id mismatch for ${key}: ${marker.operationId} != ${expected.operationId}`);
    }
    if (seen.has(key)) fail(`Duplicate baseline request for ${key}`);
    if (item.request.method !== marker.method) fail(`HTTP method mismatch for ${key}`);
    seen.set(key, item);

    const topFolder = trail[0];
    const expectedFolder = ownerFolder(expected);
    if (topFolder !== expectedFolder) {
      fail(`${key} is in folder ${topFolder}, expected ${expectedFolder}`);
    }
    counts[topFolder] += 1;

    const headers = item.request.header ?? [];
    const authorization = headers.find((header) => header.key.toLowerCase() === 'authorization');
    if (expectedFolder === 'Internal') {
      if (authorization) fail(`${key} must not send a user Authorization header`);
    } else if (!authorization || !/^Bearer \{\{token_(a|b)\}\}$/.test(authorization.value)) {
      fail(`${key} must send Authorization: Bearer {{token_a}} or {{token_b}}`);
    }

    if (item.request.body?.raw) {
      const template = item.request.body.raw
        .replace(/"\{\{[^}]+\}\}"/g, '"sample"')
        .replace(/\{\{[^}]+\}\}/g, '0');
      try {
        JSON.parse(template);
      } catch (error) {
        fail(`${key} body is not JSON after variable substitution: ${error.message}`);
      }
    }
    const expectsBody = Boolean(expected.op.requestBody);
    const hasBody = Boolean(item.request.body?.raw);
    if (expectsBody !== hasBody) {
      fail(`${key} body presence mismatch: OpenAPI requestBody=${expectsBody}, request=${hasBody}`);
    }
  });

  for (const op of specOperations) {
    const key = `${op.method} ${op.path}`;
    if (!seen.has(key)) fail(`Missing OpenAPI operation in collection: ${key} (${op.operationId})`);
  }
  if (seen.size !== specOperations.length) {
    fail(
      `Coverage mismatch: ${seen.size} baseline requests for ${specOperations.length} operations`,
    );
  }
  if (totalRequests !== seen.size + scenarioRequests) fail('Request count accounting mismatch');

  return { counts, scenarioRequests, totalRequests, baseline: seen.size };
}

function findItem(items, name) {
  for (const item of items) {
    if (item.name === name) return item;
    if (Array.isArray(item.item)) {
      const found = findItem(item.item, name);
      if (found) return found;
    }
  }
  return undefined;
}

function headerValue(item, key) {
  return (item.request.header ?? []).find(
    (header) => header.key.toLowerCase() === key.toLowerCase(),
  )?.value;
}

function checkIdempotencyScenarios(collection) {
  const triples = [
    [
      'Enroll (first write)',
      'Enroll replay (same key + same body)',
      'Enroll changed body (same key) -> 409',
    ],
    [
      'Start session (first write)',
      'Start session replay (same key + same body)',
      'Start session changed body (same key) -> 409',
    ],
    [
      'Abandon session (first write)',
      'Abandon replay (same key + same body)',
      'Abandon changed body (same key) -> 409',
    ],
    [
      'Purchase (first write)',
      'Purchase replay (same key + same body)',
      'Purchase changed body (same key) -> 409',
    ],
    [
      'Create TURN voice session (first write)',
      'Create voice session replay (same key + same body)',
      'Create voice session changed body (same key) -> 409',
    ],
  ];
  for (const [first, replay, changed] of triples) {
    const a = findItem(collection.item, first);
    const b = findItem(collection.item, replay);
    const c = findItem(collection.item, changed);
    if (!a || !b || !c) fail(`Idempotency scenario is incomplete: ${first}`);
    const key = headerValue(a, 'Idempotency-Key');
    if (!key || headerValue(b, 'Idempotency-Key') !== key) {
      fail(`Replay does not reuse the idempotency key: ${first}`);
    }
    if (headerValue(c, 'Idempotency-Key') !== key) {
      fail(`Changed-body request does not reuse the idempotency key: ${first}`);
    }
    if (!a.request.body?.raw || a.request.body.raw !== b.request.body?.raw) {
      fail(`Replay does not reuse the exact body: ${first}`);
    }
    if (a.request.body.raw === c.request.body?.raw) {
      fail(`Changed-body request has an identical body: ${first}`);
    }
  }
  const eventFirst = findItem(collection.item, 'Deliver lesson.completed.v1 (Learning key)');
  const eventReplay = findItem(collection.item, 'Replay same event (same eventId + same body)');
  const eventChanged = findItem(collection.item, 'Changed payload with same eventId -> 409');
  if (!eventFirst || !eventReplay || !eventChanged)
    fail('Internal event replay scenario is incomplete');
  if (eventFirst.request.body.raw !== eventReplay.request.body.raw) {
    fail('Event replay does not reuse the exact body');
  }
  if (eventFirst.request.body.raw === eventChanged.request.body.raw) {
    fail('Changed event payload has an identical body');
  }
}

function checkEnvironment(file, kind) {
  const environment = readJson(file);
  assert.equal(environment._postman_variable_scope, 'environment');
  assert.ok(Array.isArray(environment.values), `${file} has no values array`);
  const byKey = new Map();
  for (const entry of environment.values) {
    if (byKey.has(entry.key)) fail(`${file} has duplicate variable ${entry.key}`);
    byKey.set(entry.key, entry);
  }
  for (const key of REQUIRED_ENVIRONMENT_KEYS) {
    if (!byKey.has(key)) fail(`${path.basename(file)} is missing required variable ${key}`);
  }
  for (const entry of environment.values) {
    if (entry.type === 'secret' && entry.value !== '') {
      fail(`${path.basename(file)} secret ${entry.key} must be empty`);
    }
    if (/(token|secret|password|jwt|api[_-]?key)/i.test(entry.key) && entry.value !== '') {
      fail(`${path.basename(file)} credential-like variable ${entry.key} must be empty`);
    }
  }
  const seenKeys = new Set();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  for (const entry of environment.values.filter((value) => value.key.startsWith('idem_'))) {
    if (!uuidPattern.test(entry.value)) {
      fail(`${path.basename(file)} idempotency variable ${entry.key} is not a UUIDv4`);
    }
    if (seenKeys.has(entry.value)) {
      fail(`${path.basename(file)} reuses idempotency key ${entry.value}`);
    }
    seenKeys.add(entry.value);
  }
  const learning = byKey.get('learning_base_url').value;
  const progress = byKey.get('progress_base_url').value;
  const ai = byKey.get('ai_base_url').value;
  if (kind === 'local') {
    assert.equal(learning, 'http://127.0.0.1:4101');
    assert.equal(progress, 'http://127.0.0.1:4102');
    assert.equal(ai, 'http://127.0.0.1:4103');
    assert.equal(byKey.get('service_signing_mode').value, 'dev-keyring');
  } else {
    if (/127\.0\.0\.1|localhost/.test(`${learning}${progress}${ai}`)) {
      fail('TEST template must not point at loopback URLs');
    }
    assert.equal(byKey.get('service_signing_mode').value, 'keyring');
  }
  return environment.values.length;
}

function checkRegeneration() {
  const artifacts = buildArtifacts();
  const comparisons = [
    [COLLECTION_PATH, artifacts.collectionText],
    [LOCAL_ENV_PATH, artifacts.localEnvironmentText],
    [TEST_ENV_PATH, artifacts.testEnvironmentText],
  ];
  for (const [file, expected] of comparisons) {
    const actual = fs.readFileSync(file, 'utf8');
    if (actual !== expected) {
      fail(`${path.relative(process.cwd(), file)} is stale. Run: node tools/postman/generate.mjs`);
    }
  }
}

function checkSigner() {
  const sandbox = { URL, console };
  vm.createContext(sandbox);
  vm.runInContext(
    `${PRE_REQUEST_SCRIPT}\nthis.__cocSignRequest = cocSignRequest;\nthis.__cocCanonicalQuery = cocCanonicalQuery;\nthis.__cocCanonicalPath = cocCanonicalPath;`,
    sandbox,
    { filename: 'CocEnglish-postman-prerequest.js' },
  );
  const sign = sandbox.__cocSignRequest;
  const canonicalQuery = sandbox.__cocCanonicalQuery;
  const canonicalPath = sandbox.__cocCanonicalPath;
  assert.equal(typeof sign, 'function', 'pre-request signer is not exposed');

  assert.equal(canonicalQuery('b=1&a=hello world', ['a', 'b']), '?a=hello%20world&b=1');
  assert.equal(
    canonicalQuery('before=2026-10-28T00%3A00%3A00Z', ['before']),
    '?before=2026-10-28T00%3A00%3A00Z',
  );
  assert.throws(() => canonicalQuery('a=1&a=2', ['a']));
  assert.throws(() => canonicalQuery('unknown=1', ['a']));
  assert.equal(canonicalPath('/internal/outbox-watermark'), '/internal/outbox-watermark');
  assert.equal(canonicalPath('/a%20b/c'), '/a%20b/c');
  assert.throws(() => canonicalPath('/a/../b'));
  assert.throws(() => canonicalPath('/a//b'));

  // Expected values were produced by services/shared/src/service-hmac.ts with the
  // built-in dev keyring at nowSeconds=1780000000. Keeping them literal proves the
  // collection script and the real signer agree on bytes, not just on shape.
  const vectors = [
    {
      sender: 'maintainer',
      method: 'GET',
      path: '/ready',
      query: '',
      body: '',
      signature: '86170660fbde4a34d4e1c97f62fe44ea7d931d0ea3830344433fc514847d7a8b',
    },
    {
      sender: 'progress',
      method: 'GET',
      path: '/internal/outbox-watermark',
      query: 'before=2026-10-28T00%3A00%3A00Z',
      allowedQueryKeys: ['before'],
      body: '',
      signature: '895e9887caacf363e51cb8499590361bcbeb8f89105dcef1563a099ab708dfe4',
    },
    {
      sender: 'learning',
      method: 'POST',
      path: '/internal/events',
      query: '',
      body: '{"eventId":"3f0c2b1e-4a5d-4c8e-9f10-123456789abc","type":"lesson.completed.v1","text":"xin chào"}',
      signature: 'd5dc92ff341faad0faa03a17e57a8ef610c21a3d3f92016f078e1f14b4849c9c',
    },
  ];
  for (const vector of vectors) {
    const keyId = `dev-${vector.sender}`;
    const secretHex = sha256Hex(`cocenglish-dev-only:${vector.sender}`);
    const headers = sign({
      method: vector.method,
      path: vector.path,
      query: vector.query,
      allowedQueryKeys: vector.allowedQueryKeys ?? [],
      body: vector.body,
      keyId,
      secretHex,
      nowSeconds: 1780000000,
      crypto: nodeCrypto(),
    });
    assert.equal(headers['X-Service-Key-Id'], keyId, `key id mismatch for ${vector.path}`);
    assert.equal(headers['X-Service-Timestamp'], '1780000000');
    assert.equal(
      headers['X-Service-Signature'],
      vector.signature,
      `signature mismatch for ${vector.path}`,
    );
  }
  // Body tampering must change the signature.
  const base = {
    method: 'POST',
    path: '/internal/events',
    query: '',
    body: '{"originalCorrect":13}',
    keyId: 'dev-learning',
    secretHex: sha256Hex('cocenglish-dev-only:learning'),
    nowSeconds: 1780000000,
    crypto: nodeCrypto(),
  };
  const tampered = sign({ ...base, body: '{"originalCorrect":12}' });
  assert.notEqual(tampered['X-Service-Signature'], sign(base)['X-Service-Signature']);
}

function main() {
  const spec = loadSpec();
  const specOperations = operations(spec);
  const collection = readJson(COLLECTION_PATH);
  const coverage = checkCollection(collection, spec, specOperations);
  checkIdempotencyScenarios(collection);
  const localValueCount = checkEnvironment(LOCAL_ENV_PATH, 'local');
  const testValueCount = checkEnvironment(TEST_ENV_PATH, 'test');
  checkRegeneration();
  checkSigner();

  console.log('PASS: Postman assets are valid');
  console.log(
    `  OpenAPI operations: ${specOperations.length} (Learning ${coverage.counts.Learning}, Progress ${coverage.counts.Progress}, AI ${coverage.counts.AI}, Internal ${coverage.counts.Internal})`,
  );
  console.log(`  Baseline requests: ${coverage.baseline}`);
  console.log(`  Scenario/chain requests: ${coverage.scenarioRequests}`);
  console.log(`  Total requests: ${coverage.totalRequests}`);
  console.log(
    `  Environment values: local ${localValueCount}, TEST template ${testValueCount}; all secrets empty`,
  );
  console.log('  Regeneration: byte-identical');
  console.log('  HMAC signer: 3 service-hmac.ts vectors + canonical path/query negatives');
}

main();
