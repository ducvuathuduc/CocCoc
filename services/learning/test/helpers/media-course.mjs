// Test-only: media fault injection and a re-signed copy of the committed vi_en course.
//
// cloneCourse() gives a second, independent course that references the SAME committed media files,
// so publish/rollback tests can exercise two versions of a course that really has media (the only
// other fixture course, vi_en_mini, declares none). Bundles are re-signed with the well-known dev
// key (src/testing/dev-content-key.ts); nothing is written to disk.
import assert from 'node:assert/strict';

const tick = () => new Promise((resolve) => setImmediate(resolve));

/** Every unique media fileId the committed vi_en version declares, in first-seen order. */
export async function declaredAssetIds(local) {
  const source = local.publications.find((p) => p.courseId === 'vi_en');
  const manifest = JSON.parse(await local.files.read(source.manifestFileId));
  const ids = new Set();
  for (const index of [...manifest.bundles, manifest.placementBundle]) {
    const bundle = JSON.parse(await local.files.read(index.fileId));
    for (const asset of bundle.assets) ids.add(asset.fileId);
  }
  return [...ids];
}

export async function cloneCourse(kit, local, { courseId, versionId, editBundle }) {
  const source = local.publications.find((p) => p.courseId === 'vi_en');
  const manifest = JSON.parse(await local.files.read(source.manifestFileId));
  manifest.courseId = courseId;
  manifest.courseVersion = versionId;
  manifest.manifestHash = kit.manifestStructureHash(manifest);
  const privateKey = kit.devContentPrivateKey();
  const texts = new Map();
  for (const index of [...manifest.bundles, manifest.placementBundle]) {
    const bundle = JSON.parse(await local.files.read(index.fileId));
    bundle.courseId = courseId;
    bundle.courseVersion = versionId;
    bundle.manifestHash = manifest.manifestHash;
    if (editBundle) editBundle(bundle);
    bundle.signatureKeyId = kit.DEV_CONTENT_KEY_ID;
    bundle.signature = kit.signText(privateKey, kit.bundleSigningInput(bundle));
    const text = kit.canonicalJson(bundle);
    index.fileId = `${courseId}.${versionId}.${index.lessonId}`;
    index.sha256 = kit.sha256(text);
    texts.set(index.fileId, text);
  }
  manifest.signatureKeyId = kit.DEV_CONTENT_KEY_ID;
  manifest.signature = kit.signText(privateKey, kit.manifestSigningInput(manifest));
  const manifestText = kit.canonicalJson(manifest);
  const manifestFileId = `${courseId}.${versionId}.manifest`;
  texts.set(manifestFileId, manifestText);
  return {
    texts,
    publish: { courseId, versionId, manifestFileId, manifestSha256: kit.sha256(manifestText) },
  };
}

/**
 * The builder fills in a placeholder hash and size for every clip or image without a committed file,
 * so a course such as vi_en_mini declares media that was never shipped. Publishing it as-is is
 * exactly what the media gate now refuses. This re-declares each asset with real bytes (the vi_en
 * file when that file id ships there, otherwise deterministic fixture bytes) and re-signs the
 * bundles and manifest, so lifecycle tests can publish the fixture course through the real gate.
 * Returns the built course with updated `manifest`, `files` and `publish`, plus `served`
 * (fileId -> bytes) for the fixture-only files; pair it with layeredMedia().
 */
export async function withFixtureMedia(kit, built, base) {
  const privateKey = kit.devContentPrivateKey();
  const served = new Map();
  const declared = new Map();
  const redeclare = async (asset) => {
    if (!declared.has(asset.fileId)) {
      const real = await base.readBytes(asset.fileId);
      const bytes = real ?? new TextEncoder().encode(`fixture-media:${asset.fileId}`);
      if (!real) served.set(asset.fileId, bytes);
      declared.set(asset.fileId, { sha256: kit.sha256(bytes), bytes: bytes.length });
    }
    return { ...asset, ...declared.get(asset.fileId) };
  };
  const manifest = structuredClone(built.manifest);
  const texts = new Map();
  const entries = [...built.finished, built.placement];
  const indexes = [...manifest.bundles, manifest.placementBundle];
  for (const [position, entry] of entries.entries()) {
    const bundle = structuredClone(entry.bundle);
    bundle.assets = await Promise.all(bundle.assets.map(redeclare));
    bundle.signature = kit.signText(privateKey, kit.bundleSigningInput(bundle));
    const text = kit.canonicalJson(bundle);
    indexes[position].sha256 = kit.sha256(text);
    texts.set(indexes[position].fileId, text);
  }
  manifest.signature = kit.signText(privateKey, kit.manifestSigningInput(manifest));
  const manifestText = kit.canonicalJson(manifest);
  texts.set(built.publish.manifestFileId, manifestText);
  const files = built.files.map((f) => ({ ...f, text: texts.get(f.fileId) ?? f.text }));
  return {
    ...built,
    manifest,
    files,
    served,
    publish: {
      ...built.publish,
      manifestSha256: kit.sha256(manifestText),
      files: built.publish.files.map((f) => {
        const text = texts.get(f.fileId);
        return text === undefined
          ? f
          : { ...f, sha256: kit.sha256(text), bytes: Buffer.byteLength(text) };
      }),
    },
  };
}

/** `base` plus fixture-only files (fileId -> bytes) that are complete and public. */
export function layeredMedia(base, served) {
  return {
    async stat(ids) {
      const found = await base.stat(ids.filter((id) => !served.has(id)));
      for (const id of ids) {
        if (!served.has(id)) continue;
        found.set(id, {
          bytes: served.get(id).length,
          version: `fixture:${id}`,
          complete: true,
          publicRead: true,
        });
      }
      return found;
    },
    readBytes: async (id) => (served.has(id) ? served.get(id) : base.readBytes(id)),
  };
}

/**
 * A MediaStore over `base` that records call counts and peak concurrency and injects faults.
 * Mutate `faults` between calls to change behaviour mid-test.
 */
export function faultyStore(kit, base) {
  const counts = { stat: 0, statIds: 0, read: 0, inflight: 0, peak: 0, peakStat: 0, peakRead: 0 };
  const kinds = { stat: 0, read: 0 };
  const faults = {
    missing: new Set(),
    notPublic: new Set(),
    incomplete: new Set(),
    wrongSize: new Set(),
    corrupt: new Set(),
    short: new Set(),
    replace: new Map(),
    statError: null,
    readError: null,
    hangStat: false,
    afterRead: null,
  };
  async function within(kind, work) {
    counts.inflight += 1;
    kinds[kind] += 1;
    counts.peak = Math.max(counts.peak, counts.inflight);
    const key = kind === 'stat' ? 'peakStat' : 'peakRead';
    counts[key] = Math.max(counts[key], kinds[kind]);
    try {
      await tick();
      return await work();
    } finally {
      counts.inflight -= 1;
      kinds[kind] -= 1;
    }
  }
  return {
    counts,
    faults,
    async stat(ids) {
      counts.stat += 1;
      counts.statIds += ids.length;
      assert.ok(ids.length <= kit.MEDIA_STAT_BATCH, `batch of ${ids.length} exceeds the limit`);
      return within('stat', async () => {
        if (faults.hangStat) return new Promise(() => {});
        if (faults.statError) throw faults.statError;
        const found = await base.stat(ids);
        for (const id of ids) {
          if (faults.missing.has(id)) found.delete(id);
          const stat = found.get(id);
          if (!stat) continue;
          if (faults.notPublic.has(id)) stat.publicRead = false;
          if (faults.incomplete.has(id)) stat.complete = false;
          if (faults.wrongSize.has(id)) stat.bytes += 1;
          if (faults.replace.has(id)) {
            stat.bytes = faults.replace.get(id).length;
            stat.version = `replaced:${id}`;
          }
        }
        return found;
      });
    },
    async readBytes(id) {
      counts.read += 1;
      const ordinal = counts.read;
      return within('read', async () => {
        if (faults.readError) throw faults.readError;
        let bytes = faults.replace.has(id) ? faults.replace.get(id) : await base.readBytes(id);
        if (bytes && faults.corrupt.has(id)) {
          bytes = Uint8Array.from(bytes);
          bytes[0] ^= 0xff;
        }
        if (bytes && faults.short.has(id)) bytes = bytes.subarray(0, bytes.length - 1);
        if (faults.afterRead) faults.afterRead(ordinal, id);
        return bytes;
      });
    },
  };
}
