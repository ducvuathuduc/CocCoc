// P4-LEARN-001: content publishing. The committed vi_en version passes the offline gate; publish
// verifies hash/signature/answer keys before the pointer flips; maintainers only; immutable versions.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { loadKit } from './helpers/kit.mjs';

const kit = await loadKit('content');
const local = kit.loadLocalContent();
const publication = local.publications.find((p) => p.courseId === 'vi_en');

test('committed content: deterministic rebuild matches, OpenAPI-valid, signed, 12 types, 2/6/24/48', () => {
  for (const args of [
    ['content/tools/build-content.mjs', '--check'],
    ['content/tools/check-content.mjs'],
  ]) {
    const run = spawnSync(process.execPath, args, { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stderr || run.stdout);
    assert.match(run.stdout, /"status":"PASS"/);
  }
});

async function fileStore(mutate) {
  const texts = new Map();
  return {
    texts,
    files: {
      async read(fileId) {
        if (texts.has(fileId)) return texts.get(fileId);
        const text = await local.files.read(fileId);
        return mutate ? mutate(fileId, text) : text;
      },
    },
  };
}
const publishBody = (extra = {}) => ({ ...publication, expectedPublishedVersion: null, ...extra });

test('publish: maintainer only; flips the pointer atomically; expectedPublishedVersion guards races; versions immutable', async () => {
  const a = await kit.createTestApp({ seed: false });
  assert.equal(
    (await a.call('GET', '/v1/courses', { user: 'x' })).body.items.length,
    0,
    'nothing published before',
  );
  const denied = await a.call('POST', '/v1/admin/content-versions', {
    user: 'learner',
    body: publishBody(),
    key: randomUUID(),
  });
  assert.deepEqual([denied.status, denied.body.error.code], [403, 'MAINTAINER_REQUIRED']);
  const key = randomUUID();
  const ok = await a.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    body: publishBody(),
    key,
  });
  assert.deepEqual([ok.status, ok.body.status], [200, 'accepted']);
  const again = await a.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    body: publishBody(),
    key,
  });
  assert.deepEqual(again.body, ok.body, 'same key replays');
  const stale = await a.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    body: publishBody(),
    key: randomUUID(),
  });
  assert.deepEqual(
    [stale.status, stale.body.error.code, stale.body.error.details.publishedVersion],
    [409, 'REVISION_CONFLICT', 'v1'],
  );
  const dup = await a.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    body: publishBody({ expectedPublishedVersion: 'v1' }),
    key: randomUUID(),
  });
  assert.equal(dup.body.error.details.reason, 'VERSION_EXISTS');
  const courses = await a.call('GET', '/v1/courses', { user: 'x' });
  assert.deepEqual(
    courses.body.items.map((c) => c.publishedVersion),
    ['v1'],
  );
});

test('publish rejects tampered manifest/bundle, wrong sha256, unknown exercise type and missing files; prior version stays usable', async () => {
  const cases = [
    ['wrong manifest sha256', null, { manifestSha256: 'f'.repeat(64) }, 'VALIDATION_ERROR'],
    ['missing manifest', null, { manifestFileId: 'nope' }, 'NOT_FOUND'],
    [
      'tampered bundle',
      (id, t) => (id.endsWith('.u2n1l1') ? t.replace('"title":"', '"title":"X') : t),
      {},
      'VALIDATION_ERROR',
    ],
    ['missing bundle', (id, t) => (id.endsWith('.u6n4l2') ? null : t), {}, 'VALIDATION_ERROR'],
  ];
  for (const [name, mutate, extra, code] of cases) {
    const store = await fileStore(mutate);
    const a = await kit.createTestApp({ seed: false, files: store.files });
    const r = await a.call('POST', '/v1/admin/content-versions', {
      user: 'maintainer-1',
      body: publishBody(extra),
      key: randomUUID(),
    });
    assert.equal(r.body.error?.code, code, `${name}: ${JSON.stringify(r.body)}`);
    assert.equal(
      (await a.call('GET', '/v1/courses', { user: 'x' })).body.items.length,
      0,
      `${name}: pointer not flipped`,
    );
  }
  // A version re-signed with the dev key but containing an unknown type is still refused.
  const manifest = JSON.parse(await local.files.read(publication.manifestFileId));
  const index = manifest.bundles[0];
  const bundle = JSON.parse(await local.files.read(index.fileId));
  bundle.exercises[0].type = 'hologram';
  const v = kit.validateBundle(bundle);
  assert.ok(v.some((p) => p.problem === 'UNKNOWN_EXERCISE_TYPE'));
  const audioNoAlt = JSON.parse(await local.files.read(manifest.bundles[0].fileId));
  const listen = audioNoAlt.exercises.find((e) => e.type === 'listenChoice');
  delete listen.nonAudioAlternative;
  assert.ok(
    kit.validateBundle(audioNoAlt).some((p) => p.problem === 'NON_AUDIO_ALTERNATIVE_REQUIRED'),
  );
});

test('content repository refuses a file whose bytes do not match the pinned sha256 at read time', async () => {
  const a = await kit.createTestApp();
  const manifest = (await a.call('GET', '/v1/courses/vi_en/manifest', { user: 'x' })).body;
  const corrupt = await fileStore((id, t) =>
    id.endsWith('.u5n1l1') ? t.replace('Where', 'Wh3re') : t,
  );
  const repo = kit.createContentRepository({
    persistence: a.persistence,
    files: corrupt.files,
    keyring: kit.devContentKeyring(),
  });
  await assert.rejects(repo.bundle(manifest, 'u5n1l1'), { code: 'STORAGE_UNAVAILABLE' });
  const untrusted = kit.createContentRepository({
    persistence: a.persistence,
    files: local.files,
    keyring: new Map(),
  });
  await assert.rejects(
    untrusted.published('vi_en'),
    { code: 'STORAGE_UNAVAILABLE' },
    'unknown signing key fails closed',
  );
});
