// Phase 3 publishing lifecycle: unpublish / retire / rollback state machine for the Learning
// service. Exercises the four admin routes through the real router (in-memory persistence) and
// asserts the derived version-status model, CAS, integrity checks, and that no version row is ever
// deleted. Mirrors multi-course.test.mjs (loadKit + buildCourse + createTestApp + call).
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { loadKit, root } from './helpers/kit.mjs';
import { buildCourse } from '../../../tools/content/build-course.mjs';
import { layeredMedia, withFixtureMedia } from './helpers/media-course.mjs';

const kit = await loadKit('content-lifecycle');
const local = kit.loadLocalContent(root);

const SECOND = 'vi_en_mini';
// vi_en_mini ships no media, so the builder declares placeholder hashes for it; the publish gate
// would refuse those. withFixtureMedia re-declares them with real (fixture) bytes.
const viEnMedia = kit.localMediaStore(root);
const built = new Map();
const fixtureMedia = new Map();
for (const version of ['v1', 'v2']) {
  const b = await withFixtureMedia(
    kit,
    await buildCourse({ courseId: SECOND, version }),
    viEnMedia,
  );
  built.set(version, b);
  for (const [fileId, bytes] of b.served) fixtureMedia.set(fileId, bytes);
}

// All fixture bundle/manifest texts served alongside the shipped vi_en files; nothing on disk.
const fixtureTexts = new Map();
for (const b of built.values())
  for (const file of b.files) fixtureTexts.set(file.fileId, file.text);

function makeFiles(overrides = {}) {
  return {
    async read(fileId) {
      if (fileId in overrides) return overrides[fileId];
      if (fixtureTexts.has(fileId)) return fixtureTexts.get(fileId);
      return local.files.read(fileId);
    },
    // vi_en's committed media plus the fixture course's own files.
    ...layeredMedia(viEnMedia, fixtureMedia),
  };
}

async function publish(app, b, expectedPublishedVersion = null, overrides = {}, key) {
  return app.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    body: {
      courseId: b.publish.courseId,
      versionId: b.publish.versionId,
      manifestFileId: b.publish.manifestFileId,
      manifestSha256: b.publish.manifestSha256,
      expectedPublishedVersion,
      ...overrides,
    },
    key: key ?? randomUUID(),
  });
}

function listVersions(app, courseId, user = 'maintainer-1') {
  return app.call('GET', `/v1/admin/courses/${courseId}/content-versions`, { user });
}

const statusMap = (body) => new Map(body.items.map((i) => [i.versionId, i.status]));

test('version history is maintainer-only: a learner is refused', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await listVersions(app, SECOND, 'learner')).status, 403);
  assert.equal((await listVersions(app, SECOND, 'learner')).body.error.code, 'MAINTAINER_REQUIRED');
  // A maintainer can read it.
  assert.equal((await listVersions(app, SECOND)).status, 200);
});

test('version history: publishing v2 demotes v1 to SUPERSEDED, v2 is LIVE', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const list = await listVersions(app, SECOND);
  assert.equal(list.status, 200);
  const statuses = statusMap(list.body);
  assert.deepEqual([statuses.get('v2'), statuses.get('v1')], ['LIVE', 'SUPERSEDED']);
  assert.equal(list.body.items.length, 2, 'no version is ever deleted');
});

test('republishing an already-published version is refused (VERSION_EXISTS)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);
  // v1 already exists as a version row; even with a stale expected pointer this is VERSION_EXISTS.
  const dup = await publish(app, built.get('v1'), 'v2');
  assert.equal(dup.status, 409);
  assert.equal(dup.body.error.code, 'REVISION_CONFLICT');
  assert.equal(dup.body.error.details.reason, 'VERSION_EXISTS');
});

test('unpublish takes the course offline: Mobile listCourses drops it, manifest read fails', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const unpub = await app.call('POST', `/v1/admin/courses/${SECOND}/unpublish`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(unpub.status, 200);

  const statuses = statusMap((await listVersions(app, SECOND)).body);
  assert.equal(statuses.get('v2'), 'SUPERSEDED', 'no LIVE version after unpublish');

  const courses = (await app.call('GET', '/v1/courses', { user: 'learner' })).body;
  assert.ok(!courses.items.some((c) => c.courseId === SECOND), 'Mobile no longer lists it');
  const manifest = await app.call('GET', `/v1/courses/${SECOND}/manifest`, { user: 'learner' });
  assert.equal(manifest.status, 404, 'Mobile cannot read an unpublished course');

  // Idempotent: unpublishing again with the now-null pointer is a no-op success.
  const again = await app.call('POST', `/v1/admin/courses/${SECOND}/unpublish`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: null },
    key: randomUUID(),
  });
  assert.equal(again.status, 200);
});

test('unpublish is CAS-guarded: a stale expectedPublishedVersion is rejected', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);
  const stale = await app.call('POST', `/v1/admin/courses/${SECOND}/unpublish`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v1' },
    key: randomUUID(),
  });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.error.code, 'REVISION_CONFLICT');
  // Course is still published and Mobile still sees it.
  const courses = (await app.call('GET', '/v1/courses', { user: 'learner' })).body;
  assert.ok(courses.items.some((c) => c.courseId === SECOND && c.publishedVersion === 'v2'));
});

test('retire the live version auto-unpublishes the course; history is preserved', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const retire = await app.call('POST', `/v1/admin/courses/${SECOND}/content-versions/v2/retire`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(retire.status, 200);
  assert.equal(retire.body.status, 'retired');
  assert.equal(retire.body.unpublishedCourse, true);

  const statuses = statusMap((await listVersions(app, SECOND)).body);
  assert.deepEqual([statuses.get('v2'), statuses.get('v1')], ['RETIRED', 'SUPERSEDED']);
  const courses = (await app.call('GET', '/v1/courses', { user: 'learner' })).body;
  assert.ok(!courses.items.some((c) => c.courseId === SECOND));
});

test('retire a non-live version keeps the course published with the live version intact', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const retire = await app.call('POST', `/v1/admin/courses/${SECOND}/content-versions/v1/retire`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(retire.status, 200);
  assert.equal(retire.body.unpublishedCourse, false);

  const statuses = statusMap((await listVersions(app, SECOND)).body);
  assert.deepEqual([statuses.get('v2'), statuses.get('v1')], ['LIVE', 'RETIRED']);
  const courses = (await app.call('GET', '/v1/courses', { user: 'learner' })).body;
  assert.ok(courses.items.some((c) => c.courseId === SECOND && c.publishedVersion === 'v2'));
});

test('retire is idempotent and refuses a missing version', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const first = await app.call('POST', `/v1/admin/courses/${SECOND}/content-versions/v1/retire`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  const second = await app.call('POST', `/v1/admin/courses/${SECOND}/content-versions/v1/retire`, {
    user: 'maintainer-1',
    body: { expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(second.status, 200);
  assert.equal(second.body.alreadyRetired, true);

  const missing = await app.call(
    'POST',
    `/v1/admin/courses/${SECOND}/content-versions/nope/retire`,
    { user: 'maintainer-1', body: { expectedPublishedVersion: 'v2' }, key: randomUUID() },
  );
  assert.equal(missing.status, 404);
});

test('rollback v2 -> v1 keeps v2 as SUPERSEDED history (never deleted) and re-lives v1', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  const rb = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v1', expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(rb.status, 200);
  assert.equal(rb.body.publishedVersion, 'v1');

  const statuses = statusMap((await listVersions(app, SECOND)).body);
  assert.deepEqual([statuses.get('v2'), statuses.get('v1')], ['SUPERSEDED', 'LIVE']);
  assert.equal((await listVersions(app, SECOND)).body.items.length, 2, 'v2 is not deleted');
  const manifest = (await app.call('GET', `/v1/courses/${SECOND}/manifest`, { user: 'learner' }))
    .body;
  assert.equal(manifest.courseVersion, 'v1');
});

test('rollback is CAS-guarded: a stale expectedPublishedVersion is rejected', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);
  const stale = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v1', expectedPublishedVersion: 'v1' },
    key: randomUUID(),
  });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.error.code, 'REVISION_CONFLICT');
});

test('rollback refuses a retired target (CONTENT_VERSION_RETIRED) but can re-live a non-retired one', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  // Retire the live v2 -> auto-unpublish (course DRAFT, pointer cleared).
  assert.equal(
    (
      await app.call('POST', `/v1/admin/courses/${SECOND}/content-versions/v2/retire`, {
        user: 'maintainer-1',
        body: { expectedPublishedVersion: 'v2' },
        key: randomUUID(),
      })
    ).status,
    200,
  );

  // Rolling back to the retired v2 is refused.
  const toRetired = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v2', expectedPublishedVersion: null },
    key: randomUUID(),
  });
  assert.equal(toRetired.status, 409);
  assert.equal(toRetired.body.error.code, 'CONTENT_VERSION_RETIRED');

  // Rolling back to the non-retired v1 re-lives it and re-publishes the course.
  const toV1 = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v1', expectedPublishedVersion: null },
    key: randomUUID(),
  });
  assert.equal(toV1.status, 200);
  const manifest = (await app.call('GET', `/v1/courses/${SECOND}/manifest`, { user: 'learner' }))
    .body;
  assert.equal(manifest.courseVersion, 'v1');
});

test('rollback refuses an unverifiable target (manifest file missing -> STORAGE_UNAVAILABLE)', async () => {
  // Publish with real files, then make the target manifest missing only at rollback time.
  const overrides = {};
  const app = await kit.createTestApp({ root, files: makeFiles(overrides) });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);
  overrides[built.get('v2').publish.manifestFileId] = null; // manifest gone after publish

  const rb = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v2', expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  assert.equal(rb.status, 503);
  assert.equal(rb.body.error.code, 'STORAGE_UNAVAILABLE');
});

test('multi-course isolation: rolling back one course never touches another', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  // The shipped vi_en course is auto-seeded (published at its own version) by createTestApp.
  const viEn = local.publications.find((p) => p.courseId === 'vi_en');
  assert.ok(viEn, 'shipped vi_en publication is seeded');
  const shippedManifestBefore = (
    await app.call('GET', '/v1/courses/vi_en/manifest', {
      user: 'learner',
    })
  ).body;
  assert.equal(shippedManifestBefore.courseVersion, viEn.versionId);

  // Publish the second course with two versions, then roll it back to v1.
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200);

  assert.equal(
    (
      await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
        user: 'maintainer-1',
        body: { targetVersionId: 'v1', expectedPublishedVersion: 'v2' },
        key: randomUUID(),
      })
    ).status,
    200,
  );

  const secondManifest = (
    await app.call('GET', `/v1/courses/${SECOND}/manifest`, {
      user: 'learner',
    })
  ).body;
  assert.equal(secondManifest.courseVersion, 'v1');
  const shippedManifest = (
    await app.call('GET', '/v1/courses/vi_en/manifest', {
      user: 'learner',
    })
  ).body;
  assert.equal(shippedManifest.courseVersion, viEn.versionId, 'shipped course untouched');
});

function sha256Of(text) {
  return createHash('sha256').update(text).digest('hex');
}

// --- Section 5: concurrency, idempotency and content-integrity regression coverage ---

test('idempotent publish: the same idempotency key replays the receipt without re-writing the version row', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  const key = randomUUID();
  const first = await publish(app, built.get('v1'), null, {}, key);
  assert.equal(first.status, 200);
  assert.equal(first.body.operationId, key);
  // A retried / duplicated publish with the identical key must not write a second version.
  const second = await publish(app, built.get('v1'), null, {}, key);
  assert.equal(second.status, 200);
  assert.equal(second.body.operationId, key, 'same receipt returned on replay');
  const list = await listVersions(app, SECOND);
  assert.equal(list.body.items.length, 1, 'no duplicate version row on idempotent replay');
  assert.equal(list.body.items[0].versionId, 'v1');
});

test('idempotency conflict: the same key with a different body is refused (IDEMPOTENCY_CONFLICT)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  const key = randomUUID();
  assert.equal((await publish(app, built.get('v1'), null, {}, key)).status, 200);
  // A different body under the same key must not be silently applied.
  const conflict = await publish(app, built.get('v2'), 'v1', {}, key);
  assert.equal(conflict.status, 409);
  assert.equal(conflict.body.error.code, 'IDEMPOTENCY_CONFLICT');
  const list = await listVersions(app, SECOND);
  assert.equal(list.body.items.length, 1, 'the conflicting body was never applied');
  assert.equal(list.body.items[0].versionId, 'v1');
});

test('two admins cannot both roll back from the same observed snapshot (CAS race)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200);
  assert.equal((await publish(app, built.get('v2'), 'v1')).status, 200); // live = v2
  // Both admins observed v2 as live and both issue a rollback to v1.
  const a = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v1', expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  const b = await app.call('POST', `/v1/admin/courses/${SECOND}/rollback`, {
    user: 'maintainer-1',
    body: { targetVersionId: 'v1', expectedPublishedVersion: 'v2' },
    key: randomUUID(),
  });
  const statuses = [a.status, b.status];
  assert.ok(statuses.includes(200), 'exactly one rollback applies');
  assert.ok(statuses.includes(409), 'the other is rejected by CAS');
  const rejected = a.status === 409 ? a : b;
  assert.equal(rejected.body.error.code, 'REVISION_CONFLICT');
  // Final state is deterministic: v1 is live and v2 history is preserved (never deleted).
  const manifest = (await app.call('GET', `/v1/courses/${SECOND}/manifest`, { user: 'learner' }))
    .body;
  assert.equal(manifest.courseVersion, 'v1');
  assert.equal((await listVersions(app, SECOND)).body.items.length, 2);
});

test('two admins cannot both publish the next version from the same observed snapshot (CAS race)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  assert.equal((await publish(app, built.get('v1'))).status, 200); // live = v1
  // Both admins observed v1 and both attempt to publish v2 as the next version.
  const a = await publish(app, built.get('v2'), 'v1');
  const b = await publish(app, built.get('v2'), 'v1');
  const statuses = [a.status, b.status];
  assert.ok(statuses.includes(200), 'exactly one publish of v2 succeeds');
  assert.ok(statuses.includes(409), 'the other is rejected by CAS');
  const rejected = a.status === 409 ? a : b;
  assert.equal(rejected.body.error.code, 'REVISION_CONFLICT');
  const list = await listVersions(app, SECOND);
  assert.equal(list.body.items.length, 2, 'v2 published exactly once, v1 kept as history');
});

test('publish refuses a manifest whose SHA-256 does not match the declared hash (tamper resistance)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  const b = built.get('v1');
  const realSha = b.publish.manifestSha256;
  const wrongSha = realSha.replace(/.$/, (c) => (c === 'f' ? '0' : 'f')); // 64-hex, not the real hash
  const r = await app.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: {
      courseId: b.publish.courseId,
      versionId: b.publish.versionId,
      manifestFileId: b.publish.manifestFileId,
      manifestSha256: wrongSha,
      expectedPublishedVersion: null,
    },
  });
  assert.equal(r.status, 400);
  assert.equal(r.body.error.code, 'VALIDATION_ERROR');
  assert.equal(r.body.error.details.reason, 'HASH_OR_SIGNATURE');
  // Nothing was published.
  assert.equal((await listVersions(app, SECOND)).status, 200);
  assert.equal((await listVersions(app, SECOND)).body.items.length, 0);
});

test('publish refuses a manifest with an invalid Ed25519 signature (tamper resistance)', async () => {
  const app = await kit.createTestApp({ root, files: makeFiles() });
  const b = built.get('v1');
  const manifestText = fixtureTexts.get(b.publish.manifestFileId);
  const manifest = JSON.parse(manifestText);
  // Replace the signature with garbage (structure hash is unchanged, so this fails the signature check).
  manifest.signature = createHash('sha256')
    .update('not-the-signing-key')
    .digest('base64url')
    .slice(0, 86);
  const tampered = JSON.stringify(manifest);
  const sha = sha256Of(tampered);
  const files = makeFiles({ [b.publish.manifestFileId]: tampered });
  const tamperedApp = await kit.createTestApp({ root, files });
  const r = await tamperedApp.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: {
      courseId: b.publish.courseId,
      versionId: b.publish.versionId,
      manifestFileId: b.publish.manifestFileId,
      manifestSha256: sha,
      expectedPublishedVersion: null,
    },
  });
  assert.equal(r.status, 400);
  assert.equal(r.body.error.code, 'VALIDATION_ERROR');
  assert.equal(r.body.error.details.reason, 'HASH_OR_SIGNATURE');
});
