// `node tools/content/publish-appwrite.mjs [--course vi_en] [--version v2] [--dry-run]`
// Upload-then-flip publish of a committed course version (content/<course>/dist/<version>/) to an
// Appwrite project (P4-LEARN-001, content/README.md "Publishing"):
//   1. upload every file in publish.json to the `learning-assets` bucket (file ID = publish fileId,
//      file-level read(Role.any()); an existing file is re-downloaded and must match its sha256),
//   2. run Learning's real publish use case (POST /v1/admin/content-versions through the Learning
//      router, maintainer) with the durable Appwrite adapter and the Storage file store, so every
//      file is re-read from Storage and verified (sha256 + Ed25519 + answer keys) before the
//      l_courses pointer and the l_content_versions row commit together.
//   0. media first: every bundle asset with a committed file under content/<course>/media/
//      (images/<fileId>.webp, audio/<fileId>.<ext>) is uploaded under its asset fileId with
//      read(Role.any()) after checking its bytes against the manifest sha256 (clients download
//      media by fileId from the public bucket and verify the hash).
// --replace (TEST hot-fix of an already published version id): a remote file whose bytes differ is
// deleted and re-uploaded, and when the course already points at <version> with an older
// manifestSha256, the whole version is first verified exactly like a publish (in-memory Learning,
// Storage files) and then the l_content_versions row takes the new manifestSha256. Hosted Learning
// instances cache a verified manifest per version, so warm instances keep the old one until they
// recycle (redeploy coc-learning to force it).
// Env: APPWRITE_ENDPOINT (default https://sgp.cloud.appwrite.io/v1), APPWRITE_PROJECT_ID,
// APPWRITE_API_KEY (server key; NODE_USE_ENV_PROXY=1 when the key is injected by a proxy),
// COC_DATABASE_ID (default cocenglish). The content keyring is the dev keyring unless
// COC_CONTENT_PUBLIC_KEYS is set (the hosted Learning function must trust the same key).
// Deploy action: run only against a project you are authorized to change.
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { Client, Permission, Role, Storage, TablesDB } from 'node-appwrite';
import { InputFile } from 'node-appwrite/file';
import { loadKit, root } from '../../services/learning/test/helpers/kit.mjs';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : fallback;
};
const courseId = arg('course', 'vi_en');
const versionId = arg('version', 'v2');
const dryRun = process.argv.includes('--dry-run');
const replace = process.argv.includes('--replace');
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '6acc656d0025cc57bd81';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = process.env.COC_DATABASE_ID ?? 'cocenglish';
const bucketId = 'learning-assets';
if (!apiKey) throw new Error('APPWRITE_API_KEY is required');

const dir = path.join(root, 'content', courseId, 'dist', versionId);
const publish = JSON.parse(fs.readFileSync(path.join(dir, 'publish.json'), 'utf8'));
const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
const storage = new Storage(client);
const tables = new TablesDB(client);

// Binary media come back as bytes; JSON files may come back parsed (downloadText re-serializes).
const toBuffer = (data) =>
  data instanceof ArrayBuffer
    ? Buffer.from(data)
    : ArrayBuffer.isView(data)
      ? Buffer.from(data.buffer, data.byteOffset, data.byteLength)
      : Buffer.from(kit.downloadText(data), 'utf8');

async function ensureFile(file) {
  const bytes = fs.readFileSync(file.abs ?? path.join(dir, file.path));
  if (sha256(bytes) !== file.sha256) throw new Error(`${file.path}: local sha256 mismatch`);
  let replaced = false;
  try {
    await storage.getFile({ bucketId, fileId: file.fileId });
    const remote = toBuffer(await storage.getFileDownload({ bucketId, fileId: file.fileId }));
    if (sha256(remote) === file.sha256) return 'present';
    if (!replace) throw new Error(`${file.fileId}: remote bytes differ (use --replace)`);
    if (dryRun) return 'stale';
    await storage.deleteFile({ bucketId, fileId: file.fileId });
    replaced = true;
  } catch (error) {
    if (error?.code !== 404) throw error;
  }
  if (dryRun) return 'missing';
  await storage.createFile({
    bucketId,
    fileId: file.fileId,
    file: InputFile.fromBuffer(bytes, path.basename(file.path)),
    permissions: [Permission.read(Role.any())],
  });
  return replaced ? 'replaced' : 'uploaded';
}

// Media referenced by the bundles that has a committed file (images now; audio when produced).
const mediaRoot = path.join(root, 'content', courseId, 'media');
const mediaFiles = new Map();
for (const f of publish.files) {
  if (!f.path.startsWith('bundles/')) continue;
  for (const asset of JSON.parse(fs.readFileSync(path.join(dir, f.path), 'utf8')).assets ?? []) {
    const ext = { 'image/webp': 'webp', 'image/png': 'png', 'audio/aac': 'aac', 'audio/wav': 'wav' }[
      asset.mime
    ];
    const kind = asset.mime.startsWith('image/') ? 'images' : 'audio';
    const abs = path.join(mediaRoot, kind, `${asset.fileId}.${ext}`);
    if (!mediaFiles.has(asset.fileId) && fs.existsSync(abs)) {
      mediaFiles.set(asset.fileId, {
        fileId: asset.fileId,
        path: path.relative(root, abs),
        abs,
        sha256: asset.sha256,
      });
    }
  }
}

async function uploadAll(files, step) {
  const counts = { present: 0, uploaded: 0, replaced: 0, stale: 0, missing: 0 };
  const queue = [...files];
  await Promise.all(
    Array.from({ length: 8 }, async () => {
      for (let file = queue.shift(); file; file = queue.shift()) {
        for (let attempt = 1; ; attempt++) {
          try {
            counts[await ensureFile(file)]++;
            break;
          } catch (error) {
            if (attempt >= 3 || /differ|mismatch/.test(String(error?.message))) throw error;
            await new Promise((r) => setTimeout(r, 500 * attempt));
          }
        }
      }
    }),
  );
  console.error(JSON.stringify({ step, bucketId, files: files.length, ...counts }));
  return counts;
}

const kit = await loadKit('publish-appwrite');
const { downloadText } = kit;
const mediaCounts = await uploadAll([...mediaFiles.values()], 'media');
const counts = await uploadAll(publish.files, 'upload');
if (dryRun) process.exit(0);

const durable = kit.createAppwriteLearningPersistence(
  { endpoint, projectId, apiKey, databaseId, admittedForHosting: false },
  tables,
);
// Surface the underlying cause of a failed persistence call (the router maps it to a bare 500).
const persistence = new Proxy(durable, {
  get(target, prop) {
    const value = Reflect.get(target, prop, target);
    if (typeof value !== 'function') return value;
    return async (...args) => {
      try {
        return await value.apply(target, args);
      } catch (error) {
        console.error(
          `persistence.${String(prop)} failed:`,
          error?.code ?? '',
          error?.message,
          JSON.stringify(error?.details ?? {}),
          error?.cause?.message ?? '',
        );
        throw error;
      }
    };
  },
});
const files = {
  async read(fileId) {
    try {
      return downloadText(await storage.getFileDownload({ bucketId, fileId }));
    } catch (error) {
      if (error?.code === 404) return null;
      throw error;
    }
  },
};
const app = await kit.createTestApp({ persistence, files, seed: false });
const course = await persistence.read('l_courses', kit.ids.course(courseId));
const current = course ? String(course.publishedVersion) : null;
let result = { status: 'already-published' };
const existing = await persistence.read(
  'l_content_versions',
  kit.ids.contentVersion(courseId, versionId),
);
if (current === versionId && existing && existing.manifestSha256 !== publish.manifestSha256) {
  if (!replace) {
    throw new Error(
      `${courseId} ${versionId} is published with manifest ${existing.manifestSha256}; ` +
        'committed content differs (re-run with --replace for a TEST hot-fix)',
    );
  }
  // Verify the replaced version exactly like a publish, against Storage, in memory.
  const check = await kit.createTestApp({ files, seed: false });
  const r = await check.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: {
      courseId,
      versionId,
      manifestFileId: publish.manifestFileId,
      manifestSha256: publish.manifestSha256,
      expectedPublishedVersion: null,
    },
  });
  if (r.status !== 200) throw new Error(`verify failed: ${r.status} ${JSON.stringify(r.body)}`);
  await tables.updateRow({
    databaseId,
    tableId: 'l_content_versions',
    rowId: kit.ids.contentVersion(courseId, versionId),
    data: {
      manifestSha256: publish.manifestSha256,
      publishedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      revision: Number(existing.revision ?? 0) + 1,
    },
  });
  result = { status: 'replaced', previousManifestSha256: existing.manifestSha256 };
} else if (current !== versionId) {
  const r = await app.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: randomUUID(),
    body: {
      courseId,
      versionId,
      manifestFileId: publish.manifestFileId,
      manifestSha256: publish.manifestSha256,
      expectedPublishedVersion: current,
    },
  });
  if (r.status !== 200) throw new Error(`publish failed: ${r.status} ${JSON.stringify(r.body)}`);
  result = r.body;
}
const after = await persistence.read('l_courses', kit.ids.course(courseId));
const version = await persistence.read(
  'l_content_versions',
  kit.ids.contentVersion(courseId, versionId),
);
console.log(
  JSON.stringify({
    status: 'PASS',
    courseId,
    versionId,
    previousVersion: current,
    publish: result.status,
    l_courses: { publishedVersion: after?.publishedVersion, manifestFileId: after?.manifestFileId },
    l_content_versions: {
      manifestSha256: version?.manifestSha256,
      publishedAt: version?.publishedAt,
    },
    upload: counts,
    media: mediaCounts,
  }),
);
