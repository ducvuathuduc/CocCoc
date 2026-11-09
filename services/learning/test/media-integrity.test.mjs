// Release blocker WS1: the publish gate verifies the media bundles declare (src/content/media.ts)
// before a pointer flips. Covers missing / corrupted / inaccessible media, Storage outage,
// timeout, permission denied, the delete-after-verify race, rollback re-audit, batching and
// concurrency limits, and the Appwrite Storage adapter against a fake SDK.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { loadKit, root } from './helpers/kit.mjs';
import { cloneCourse, declaredAssetIds, faultyStore } from './helpers/media-course.mjs';

const kit = await loadKit('media-integrity');
const local = kit.loadLocalContent(root);
const viEn = local.publications.find((p) => p.courseId === 'vi_en');
const assetIds = await declaredAssetIds(local);
const POLICY = kit.DEFAULT_MEDIA_POLICY;
const FAST = { retryDelayMs: 1 };

const base = () => faultyStore(kit, kit.localMediaStore(root));

async function appWith(store, { texts, media = FAST } = {}) {
  const files = {
    read: async (fileId) => texts?.get(fileId) ?? local.files.read(fileId),
    stat: store.stat,
    readBytes: store.readBytes,
  };
  return kit.createTestApp({ root, seed: false, files, media });
}
const publish = (app, publication, expectedPublishedVersion = null) =>
  app.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: { ...publication, expectedPublishedVersion },
  });
const versionRow = (app, courseId, versionId) =>
  app.persistence.read('l_content_versions', kit.ids.contentVersion(courseId, versionId));
const published = async (app) =>
  (await app.call('GET', '/v1/courses', { user: 'learner' })).body.items.map((c) => [
    c.courseId,
    c.publishedVersion,
  ]);
const problems = (response) =>
  response.body.error.details.problems.map((p) => `${p.where}|${p.problem}`).sort();
async function sampleBundles(count) {
  const manifest = JSON.parse(await local.files.read(viEn.manifestFileId));
  return Promise.all(
    manifest.bundles.slice(0, count).map(async (i) => JSON.parse(await local.files.read(i.fileId))),
  );
}

test('the whole course is verified in batches with bounded concurrency, one download per unique asset', async () => {
  const store = base();
  const app = await appWith(store);
  const response = await publish(app, viEn);
  assert.equal(response.status, 200, JSON.stringify(response.body));
  const batches = Math.ceil(assetIds.length / kit.MEDIA_STAT_BATCH);
  // One metadata pass to verify and one right before the flip; never one call per asset.
  assert.equal(store.counts.stat, batches * 2);
  assert.equal(store.counts.statIds, assetIds.length * 2);
  assert.equal(store.counts.read, assetIds.length);
  assert.ok(store.counts.peakStat <= POLICY.concurrency, `stat peak ${store.counts.peakStat}`);
  assert.ok(store.counts.peakRead <= POLICY.concurrency, `read peak ${store.counts.peakRead}`);
  assert.ok(store.counts.peakRead > 1, 'downloads run in parallel');

  // The same stored objects are not downloaded again: only the cheap metadata pass repeats.
  const again = await kit.verifyVersionMedia(app.deps, 'vi_en', 'v2');
  assert.equal(again.assets, assetIds.length);
  assert.ok(again.references > again.assets, 'declarations are de-duplicated before any I/O');
  assert.equal(again.readCalls, 0);
  assert.equal(again.cacheHits, again.assets);
  assert.equal(store.counts.read, assetIds.length);
});

test('missing media blocks publication, writes nothing and leaves the version id reusable', async () => {
  const store = base();
  const [a, b] = [assetIds[0], assetIds[100]];
  store.faults.missing.add(a).add(b);
  const app = await appWith(store);
  const response = await publish(app, viEn);
  assert.deepEqual([response.status, response.body.error.code], [400, 'VALIDATION_ERROR']);
  assert.deepEqual(problems(response), [`${a}|MEDIA_MISSING`, `${b}|MEDIA_MISSING`].sort());
  assert.equal(store.counts.read, 0, 'no bytes are downloaded once metadata already fails');
  assert.equal(await versionRow(app, 'vi_en', 'v2'), null);
  assert.deepEqual(await published(app), []);

  store.faults.missing.clear();
  assert.equal((await publish(app, viEn)).status, 200, 'the same version publishes once fixed');
  assert.deepEqual(await published(app), [['vi_en', 'v2']]);
});

test('corrupted media is refused: wrong bytes, wrong length, wrong stored size', async () => {
  for (const [fault, id, expected] of [
    ['corrupt', assetIds[3], 'MEDIA_HASH_MISMATCH'],
    ['short', assetIds[4], 'MEDIA_SIZE_MISMATCH'],
    ['wrongSize', assetIds[5], 'MEDIA_SIZE_MISMATCH'],
  ]) {
    const store = base();
    store.faults[fault].add(id);
    const app = await appWith(store);
    const response = await publish(app, viEn);
    assert.deepEqual([response.status, response.body.error.code], [400, 'VALIDATION_ERROR'], fault);
    assert.deepEqual(problems(response), [`${id}|${expected}`], fault);
    assert.equal(await versionRow(app, 'vi_en', 'v2'), null, fault);
  }
});

test('media Mobile cannot read is refused: not public, upload unfinished', async () => {
  for (const [fault, expected] of [
    ['notPublic', 'MEDIA_NOT_PUBLIC'],
    ['incomplete', 'MEDIA_INCOMPLETE'],
  ]) {
    const store = base();
    store.faults[fault].add(assetIds[7]);
    const app = await appWith(store);
    const response = await publish(app, viEn);
    assert.equal(response.status, 400, fault);
    assert.deepEqual(problems(response), [`${assetIds[7]}|${expected}`], fault);
    assert.deepEqual(await published(app), [], fault);
  }
});

test('Storage outage, permission denial and timeouts fail closed and never publish', async () => {
  // Outage during the metadata pass: bounded retry, then 503.
  let store = base();
  store.faults.statError = new Error('connect ECONNREFUSED');
  let app = await appWith(store);
  let response = await publish(app, viEn);
  assert.deepEqual([response.status, response.body.error.code], [503, 'STORAGE_UNAVAILABLE']);
  assert.equal(response.body.error.details.reason, kit.MEDIA_REASONS.unavailable);
  assert.equal(response.body.error.retryable, true);
  assert.ok(store.counts.stat <= POLICY.concurrency * (1 + POLICY.retries), 'no retry storm');
  assert.deepEqual(await published(app), []);
  store.faults.statError = null;
  assert.equal((await publish(app, viEn)).status, 200, 'recovers once Storage is back');

  // The key cannot read Storage: a configuration fault, reported as such and never retried.
  store = base();
  store.faults.statError = new kit.ServiceError('STORAGE_UNAVAILABLE', {
    details: { reason: kit.MEDIA_REASONS.permissionDenied },
  });
  app = await appWith(store);
  response = await publish(app, viEn);
  assert.equal(response.status, 503);
  assert.equal(response.body.error.details.reason, kit.MEDIA_REASONS.permissionDenied);
  assert.ok(store.counts.stat <= POLICY.concurrency, 'permission errors are not retried');
  assert.equal(await versionRow(app, 'vi_en', 'v2'), null);

  // A hung metadata call times out instead of blocking the publish.
  store = base();
  store.faults.hangStat = true;
  app = await appWith(store, { media: { callTimeoutMs: 20, retries: 0 } });
  response = await publish(app, viEn);
  assert.equal(response.status, 503);
  assert.equal(response.body.error.details.reason, kit.MEDIA_REASONS.timeout);

  // Outage while downloading bytes.
  store = base();
  store.faults.readError = new Error('socket hang up');
  app = await appWith(store);
  response = await publish(app, viEn);
  assert.equal(response.status, 503);
  assert.equal(response.body.error.details.reason, kit.MEDIA_REASONS.unavailable);
  assert.equal(await versionRow(app, 'vi_en', 'v2'), null);
});

test('an exhausted deadline fails closed and the retry resumes from the verified cache', async () => {
  const bundles = await sampleBundles(20);
  const unique = new Set(bundles.flatMap((b) => b.assets.map((a) => a.fileId))).size;
  assert.ok(unique > 30, 'enough assets to need several attempts');
  const store = base();
  let clock = 0;
  const slow = {
    stat: store.stat,
    readBytes: (id) => {
      clock += 10;
      return store.readBytes(id);
    },
  };
  const verifier = kit.createMediaVerifier(slow, {
    policy: { concurrency: 1, deadlineMs: 100 },
    nowMs: () => clock,
  });
  let attempts = 0;
  let evidence;
  while (!evidence) {
    attempts += 1;
    assert.ok(attempts < 100, 'must converge');
    try {
      evidence = await verifier.verify(bundles);
    } catch (error) {
      assert.deepEqual(
        [error.code, error.details.reason],
        ['STORAGE_UNAVAILABLE', kit.MEDIA_REASONS.deadline],
      );
      assert.ok(error.details.unverified > 0);
    }
  }
  assert.ok(attempts > 1, 'the first attempt ran out of time');
  assert.equal(store.counts.read, unique, 'nothing was downloaded twice across attempts');
});

test('media deleted or replaced between verification and the flip is caught by the recheck', async () => {
  const victim = assetIds[10];

  // Deleted while the last bytes were being verified.
  let store = base();
  store.faults.afterRead = (ordinal) => {
    if (ordinal === assetIds.length) store.faults.missing.add(victim);
  };
  let app = await appWith(store);
  let response = await publish(app, viEn);
  assert.deepEqual([response.status, response.body.error.code], [400, 'VALIDATION_ERROR']);
  assert.deepEqual(problems(response), [`${victim}|MEDIA_MISSING`]);
  assert.equal(await versionRow(app, 'vi_en', 'v2'), null);
  assert.deepEqual(await published(app), []);

  // Replaced by a different object in the same window: the verified bytes are no longer the stored ones.
  store = base();
  store.faults.afterRead = (ordinal) => {
    if (ordinal === assetIds.length) store.faults.replace.set(victim, new Uint8Array([1, 2, 3]));
  };
  app = await appWith(store);
  response = await publish(app, viEn);
  assert.deepEqual([response.status, response.body.error.code], [409, 'REVISION_CONFLICT']);
  assert.equal(response.body.error.details.reason, kit.MEDIA_REASONS.changed);
  assert.deepEqual(await published(app), []);
  store.faults.afterRead = null;
  store.faults.replace.clear();
  assert.equal((await publish(app, viEn)).status, 200);
});

// Two versions of a course that really has media: copies of vi_en re-signed under another id.
const v1 = await cloneCourse(kit, local, { courseId: 'media_check', versionId: 'v1' });
const victim = assetIds[0];
const originalBytes = await kit.localMediaStore(root).readBytes(victim);
const replacement = Uint8Array.from(originalBytes);
replacement[replacement.length - 1] ^= 0x55;
const v2 = await cloneCourse(kit, local, {
  courseId: 'media_check',
  versionId: 'v2',
  editBundle: (bundle) => {
    for (const asset of bundle.assets)
      if (asset.fileId === victim)
        asset.sha256 = createHash('sha256').update(replacement).digest('hex');
  },
});
const texts = new Map([...v1.texts, ...v2.texts]);
const rollback = (app, target, expected) =>
  app.call('POST', '/v1/admin/courses/media_check/rollback', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: { targetVersionId: target, expectedPublishedVersion: expected },
  });

test('rollback re-audits its target: media replaced since the version was published refuses it', async () => {
  const store = base();
  const app = await appWith(store, { texts });
  assert.equal((await publish(app, v1.publish)).status, 200);
  // v2 re-records one clip under the same file id: Storage now holds the new bytes.
  store.faults.replace.set(victim, replacement);
  assert.equal((await publish(app, v2.publish, 'v1')).status, 200);
  const rowBefore = await versionRow(app, 'media_check', 'v1');

  const refused = await rollback(app, 'v1', 'v2');
  assert.deepEqual([refused.status, refused.body.error.code], [400, 'VALIDATION_ERROR']);
  assert.deepEqual(problems(refused), [`${victim}|MEDIA_HASH_MISMATCH`]);
  assert.deepEqual(await published(app), [['media_check', 'v2']], 'the pointer did not move');
  assert.deepEqual(await versionRow(app, 'media_check', 'v1'), rowBefore, 'v1 row is untouched');

  // Restoring the original object makes v1 sound again, and the rollback goes through.
  store.faults.replace.clear();
  assert.equal((await rollback(app, 'v1', 'v2')).status, 200);
  assert.deepEqual(await published(app), [['media_check', 'v1']]);
  assert.ok(await versionRow(app, 'media_check', 'v2'), 'v2 is history, never deleted');
});

test('rollback is refused when its target lost media, and a Storage outage cannot block a takedown', async () => {
  const store = base();
  const app = await appWith(store, { texts });
  assert.equal((await publish(app, v1.publish)).status, 200);
  store.faults.replace.set(victim, replacement);
  assert.equal((await publish(app, v2.publish, 'v1')).status, 200);

  store.faults.replace.clear();
  store.faults.missing.add(assetIds[20]);
  const refused = await rollback(app, 'v1', 'v2');
  assert.deepEqual(problems(refused), [`${assetIds[20]}|MEDIA_MISSING`]);

  // Unpublishing needs no Storage at all, so an outage never keeps bad content online.
  store.faults.statError = new Error('connect ETIMEDOUT');
  store.faults.readError = new Error('connect ETIMEDOUT');
  const unpublished = await app.call('POST', '/v1/admin/courses/media_check/unpublish', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: { expectedPublishedVersion: 'v2' },
  });
  assert.equal(unpublished.status, 200);
  assert.deepEqual(await published(app), []);
});

test('declarations are checked offline before any Storage call', async () => {
  const asset = (fileId, extra = {}) => ({
    fileId,
    sha256: 'a'.repeat(64),
    bytes: 10,
    mime: 'audio/aac',
    altText: 'x',
    ...extra,
  });
  const untouched = {
    stat: async () => assert.fail('stat must not run'),
    readBytes: async () => assert.fail('readBytes must not run'),
  };
  const verifier = kit.createMediaVerifier(untouched);
  const first = (promise) =>
    promise.then(
      () => assert.fail('expected a rejection'),
      (error) => [error.code, error.details.problems?.[0]?.problem ?? error.details.reason],
    );
  assert.deepEqual(
    await first(
      verifier.verify([
        { assets: [asset('a.one')] },
        { assets: [asset('a.one', { sha256: 'b'.repeat(64) })] },
      ]),
    ),
    ['VALIDATION_ERROR', 'MEDIA_METADATA_CONFLICT'],
  );
  assert.deepEqual(
    await first(verifier.verify([{ assets: [asset('a.big', { bytes: 2 * 1024 * 1024 + 1 })] }])),
    ['VALIDATION_ERROR', 'MEDIA_SIZE_OUT_OF_POLICY'],
    'Mobile refuses audio over 2 MiB',
  );
  assert.deepEqual(
    await first(
      kit
        .createMediaVerifier(untouched, { policy: { maxAssets: 1 } })
        .verify([{ assets: [asset('a.1'), asset('a.2')] }]),
    ),
    ['VALIDATION_ERROR', 'MEDIA_BUDGET_EXCEEDED'],
  );
  const empty = await verifier.verify([{ assets: [] }, { assets: [] }]);
  assert.deepEqual([empty.assets, empty.statCalls, empty.readCalls], [0, 0, 0]);

  // A store that cannot check media is never treated as "nothing to check".
  for (const store of [undefined, { read: async () => null }]) {
    assert.deepEqual(
      await first(kit.createMediaVerifier(store).verify([{ assets: [asset('a.one')] }])),
      ['STORAGE_UNAVAILABLE', kit.MEDIA_REASONS.notConfigured],
    );
  }
});

test('hosted tuning knobs accept only sane values', () => {
  assert.deepEqual(
    kit.mediaPolicyFromEnv({
      COC_MEDIA_VERIFY_CONCURRENCY: '4',
      COC_MEDIA_VERIFY_DEADLINE_MS: '20000',
    }),
    { concurrency: 4, deadlineMs: 20000 },
  );
  for (const bad of ['0', '17', 'abc', '', '-1', '1e3'])
    assert.deepEqual(kit.mediaPolicyFromEnv({ COC_MEDIA_VERIFY_CONCURRENCY: bad }), {}, bad);
  for (const bad of ['999', '55001', 'x'])
    assert.deepEqual(kit.mediaPolicyFromEnv({ COC_MEDIA_VERIFY_DEADLINE_MS: bad }), {}, bad);
  assert.deepEqual(kit.mediaPolicyFromEnv({}), {});
});

// --- Appwrite Storage adapter against a fake SDK -----------------------------------------------

function fakeStorage({ files = [], listError, getFileError, downloadError, download } = {}) {
  const calls = { listFiles: [], getFile: [], getFileDownload: [] };
  const byId = new Map(files.map((f) => [f.$id, f]));
  return {
    calls,
    async listFiles(params) {
      calls.listFiles.push(params);
      if (listError) throw listError;
      const wanted = JSON.parse(
        params.queries.find((q) => JSON.parse(q).method === 'equal'),
      ).values;
      return { total: 0, files: wanted.flatMap((id) => (byId.has(id) ? [byId.get(id)] : [])) };
    },
    async getFile(params) {
      calls.getFile.push(params);
      if (getFileError) throw getFileError;
      if (!byId.has(params.fileId)) throw Object.assign(new Error('not found'), { code: 404 });
      return byId.get(params.fileId);
    },
    async getFileDownload(params) {
      calls.getFileDownload.push(params);
      if (downloadError) throw downloadError;
      return download ?? new Uint8Array([1, 2, 3]).buffer;
    },
  };
}
const file = (id, extra = {}) => ({
  $id: id,
  sizeOriginal: 10,
  signature: 'md5-of-bytes',
  $updatedAt: '2026-11-09T00:00:00.000+00:00',
  chunksTotal: 1,
  chunksUploaded: 1,
  $permissions: ['read("any")'],
  ...extra,
});
const adapter = (storage) =>
  kit.createStorageContentFiles({ endpoint: 'https://x', projectId: 'p', apiKey: 'k' }, storage);

test('Storage adapter: one listFiles call per batch maps size, completeness and public read', async () => {
  const storage = fakeStorage({
    files: [
      file('a.1'),
      file('a.2', { $permissions: ['read("users")'] }),
      file('a.3', { chunksUploaded: 0, chunksTotal: 2 }),
    ],
  });
  const stats = await adapter(storage).stat(['a.1', 'a.2', 'a.3', 'a.gone']);
  assert.equal(storage.calls.listFiles.length, 1);
  assert.equal(storage.calls.getFile.length, 0);
  const [call] = storage.calls.listFiles;
  assert.equal(call.bucketId, 'learning-assets');
  assert.equal(call.total, false);
  const queries = call.queries.map((q) => JSON.parse(q));
  assert.deepEqual(queries[0].values, ['a.1', 'a.2', 'a.3', 'a.gone']);
  assert.equal(queries[0].attribute, '$id');
  assert.equal(queries[1].method, 'limit');
  assert.deepEqual([...stats.keys()], ['a.1', 'a.2', 'a.3'], 'absent ids are omitted');
  assert.equal(stats.get('a.1').publicRead, true);
  assert.equal(stats.get('a.2').publicRead, false);
  assert.equal(stats.get('a.3').complete, false);
  assert.equal(stats.get('a.1').bytes, 10);
  const replaced = await adapter(
    fakeStorage({ files: [file('a.1', { signature: 'md5-of-other-bytes' })] }),
  ).stat(['a.1']);
  assert.notEqual(
    stats.get('a.1').version,
    replaced.get('a.1').version,
    'replacing the stored object changes its version',
  );
});

test('Storage adapter: a rejected batch query falls back to bounded per-file metadata calls', async () => {
  const storage = fakeStorage({
    files: [file('a.1'), file('a.2')],
    listError: Object.assign(new Error('Invalid query'), { code: 400 }),
  });
  const stats = await adapter(storage).stat(['a.1', 'a.missing', 'a.2']);
  assert.deepEqual([...stats.keys()], ['a.1', 'a.2']);
  assert.equal(storage.calls.getFile.length, 3);
});

test('Storage adapter: failures carry a reason the publish gate acts on', async () => {
  const reasonOf = async (work) => {
    try {
      await work();
    } catch (error) {
      return [error.code, error.details.reason];
    }
    return assert.fail('expected a failure');
  };
  const denied = Object.assign(new Error('forbidden'), { code: 403 });
  const unauthorized = Object.assign(new Error('unauthorized'), { code: 401 });
  const server = Object.assign(new Error('boom'), { code: 503 });
  assert.deepEqual(await reasonOf(() => adapter(fakeStorage({ listError: denied })).stat(['a'])), [
    'STORAGE_UNAVAILABLE',
    kit.MEDIA_REASONS.permissionDenied,
  ]);
  assert.deepEqual(
    await reasonOf(() => adapter(fakeStorage({ downloadError: unauthorized })).readBytes('a')),
    ['STORAGE_UNAVAILABLE', kit.MEDIA_REASONS.permissionDenied],
  );
  assert.deepEqual(await reasonOf(() => adapter(fakeStorage({ listError: server })).stat(['a'])), [
    'STORAGE_UNAVAILABLE',
    kit.MEDIA_REASONS.unavailable,
  ]);
  assert.deepEqual(
    await reasonOf(() =>
      adapter(fakeStorage({ downloadError: new Error('fetch failed') })).readBytes('a'),
    ),
    ['STORAGE_UNAVAILABLE', kit.MEDIA_REASONS.unavailable],
  );
});

test('Storage adapter: bytes come back untouched and a missing file is null', async () => {
  const storage = fakeStorage({ download: Uint8Array.from([0xff, 0xf1, 0x00]).buffer });
  assert.deepEqual([...(await adapter(storage).readBytes('a.1'))], [0xff, 0xf1, 0x00]);
  const missing = fakeStorage({ downloadError: Object.assign(new Error('nf'), { code: 404 }) });
  assert.equal(await adapter(missing).readBytes('a.1'), null);
  assert.equal((await adapter(storage).stat([])).size, 0);
  assert.equal(storage.calls.listFiles.length, 0, 'an empty batch makes no call');
});
