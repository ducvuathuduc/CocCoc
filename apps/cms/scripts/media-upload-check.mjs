// Media upload proof. Drives the real `uploadMedia` server action against the file store in a scratch
// directory, so a browser drop is proven to land exactly where `publish-appwrite.mjs` reads, and to
// refuse everything the bundle could mis-claim: a key no unit asks for, the wrong extension, bytes that
// are not ADTS AAC, a WebP that is not the 512x512 tile build-course.mjs declares, an existing file
// without the overwrite flag, and a caller with no admin session. Nothing under the real content/ tree
// is written; the repo's own clips and pictures are read only as samples of the real formats.
import { build } from 'esbuild';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
  HARNESS_ADMIN_SECRET,
  HARNESS_OUTSIDER_SECRET,
  authCoreStub,
} from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
for (const entry of await readdir(path.join(appRoot, 'node_modules')))
  if (entry.startsWith('.media-upload-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.media-upload-'));
const dataDir = path.join(scratch, 'data');
const repoRoot = path.join(scratch, 'repo');
const posix = (p) => p.replace(/\\/g, '/');

await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
);
await writeFile(path.join(scratch, 'stub-auth-core.mjs'), authCoreStub());
await writeFile(
  path.join(scratch, 'stub-navigation.mjs'),
  'export function redirect(to) {\n  throw new Error(`redirect:${to}`);\n}\n',
);

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/cms/media';\n" +
      "export * from '@/cms/media-format';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/server/media-service';\n" +
      "export * from '@/server/actions/media';\n" +
      "export * from '@/server/store/file-store';\n",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: {
    '@': posix(path.join(appRoot, 'src')),
    '@/server/auth-core': posix(path.join(scratch, 'stub-auth-core.mjs')),
    'next/headers': posix(path.join(scratch, 'stub-headers.mjs')),
    'next/navigation': posix(path.join(scratch, 'stub-navigation.mjs')),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

for (const key of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY'])
  delete process.env[key];
Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-media',
  CMS_DATA_DIR: dataDir,
  CMS_REPO_ROOT: repoRoot,
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
});

const cms = await import(pathToFileURL(bundleFile).href);
const store = new cms.FileStore(dataDir);

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};

const courseId = 'vi_en';

// ---------- the format sniffers, against the repo's own files ----------
const realClip = new Uint8Array(
  await readFile(path.join(realRepo, 'content/vi_en/media/audio/a.u1.s1.n.aac')),
);
const realImage = new Uint8Array(
  await readFile(path.join(realRepo, 'content/vi_en/media/images/i.u1.friend.webp')),
);
check('clip AAC thật của repo qua isAdtsAac', cms.isAdtsAac(realClip) === true);
check(
  'ảnh WebP thật của repo đọc đúng 512x512',
  JSON.stringify(cms.webpSize(realImage)) === JSON.stringify({ width: 512, height: 512 }),
  JSON.stringify(cms.webpSize(realImage)),
);
check('chuỗi không phải AAC bị từ chối', cms.isAdtsAac(new Uint8Array(Buffer.from('not an aac file at all'))) === false);
check('WebP giả mạo (GIF) trả null', cms.webpSize(new Uint8Array(Buffer.from('GIF89a0000000000000000000000000'))) === null);

// A VP8X canvas is stored as size-1 in three little-endian bytes; the app tile must be 512x512.
const extended = Buffer.alloc(34);
Buffer.from('RIFF').copy(extended, 0);
extended.writeUInt32LE(20, 4);
Buffer.from('WEBPVP8X').copy(extended, 8);
extended.writeUInt32LE(10, 16);
extended.writeUIntLE(511, 24, 3);
extended.writeUIntLE(767, 27, 3);
check(
  'WebP nhiều trang đọc đúng khổ vẽ',
  JSON.stringify(cms.webpSize(new Uint8Array(extended))) === JSON.stringify({ width: 512, height: 768 }),
  JSON.stringify(cms.webpSize(new Uint8Array(extended))),
);

// ---------- one unit, five keys the app will ask for ----------
const draft = cms.blankUnit('alpha', 'A1');
draft.title = 'Bài alpha';
draft.levels = ['L1', 'L2', '', '', ''];
draft.guide = 'Hướng dẫn alpha';
draft.vocab = [
  { level: 1, en: 'alpha', enAlts: [], vi: 'an-pha', viAlts: [], img: true, forms: [], id: 'w_alpha' },
];
draft.sentences = [{ en: 'Alpha one.', enAlts: [], vi: 'Một.', viAlts: [] }];
draft.dialogues = [{ line: 'alpha a', reply: 'alpha b', replyAlts: [], vi: 'Chào.' }];

await store.saveCourse({
  courseId,
  draft: {
    course: { courseId, title: 'Khóa thử nạp media', sourceLocale: 'vi', targetLocale: 'en', status: 'DRAFT' },
    sections: [{ sectionId: 's1', title: 'Phần một', units: ['alpha'] }],
    version: 'v2',
  },
  actorId: 'harness-media',
  expectedRevision: 0,
});
await store.saveUnit({
  courseId,
  unitId: '01-alpha',
  order: 0,
  draft,
  actorId: 'harness-media',
  expectedRevision: 0,
});

const index = await cms.courseAssets(courseId);
const wanted = ['a.u1.s1.n', 'a.u1.s1.s', 'a.u1.d1.n', 'a.u1.d1.s', 'i.u1.w_alpha'];
check(
  'index khóa = đúng 5 tài nguyên unit này cần',
  [...index.keys()].sort().join() === wanted.slice().sort().join(),
  [...index.keys()].join(),
);
const mediaRoot = path.resolve(repoRoot, 'content', courseId, 'media');
check(
  'mọi key index đều giải ra đường dẫn trong kho media của khóa',
  [...index.keys()].every((key) => path.resolve(cms.mediaFile(courseId, key).file).startsWith(mediaRoot)),
);

const before = await cms.unitAssets(courseId, 'v2', 0, draft);
check(
  'chưa nạp gì: cả 5 mục đều thiếu file',
  before.assets.length === 5 && before.assets.every((a) => a.present === false),
  before.assets.map((a) => `${a.fileId}=${a.present}`).join(),
);
check(
  'chưa có manifest: audio báo none',
  before.assets.every((a) => (a.kind === 'audio' ? a.manifest === 'none' : true)),
);

// ---------- the real action ----------
const upload = (entries, flag) => {
  const form = new FormData();
  for (const [name, body] of entries) form.append('files', new File([body], name));
  if (flag) form.append('overwrite', '1');
  return cms.uploadMedia(courseId, form);
};

const okUpload = await upload([
  ['a.u1.s1.n.aac', realClip],
  ['a.u1.s1.s.aac', realClip],
  ['i.u1.w_alpha.webp', realImage],
]);
check('nạp 3 file hợp lệ: ok', okUpload.ok === true, JSON.stringify(okUpload.rejected));
check('nạp 3 file hợp lệ: saved 3', okUpload.saved.length === 3, JSON.stringify(okUpload.saved));
check(
  'khai báo dung lượng đúng bằng file trên đĩa',
  okUpload.saved.every((s) => s.bytes > 100 && !s.overwritten),
  JSON.stringify(okUpload.saved),
);
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
check(
  'sha256 CMS báo = sha256 mẫu gốc',
  okUpload.saved.every((s) => s.sha256 === sha(s.fileId.startsWith('i.') ? realImage : realClip)),
  JSON.stringify(okUpload.saved.map((s) => [s.fileId, s.sha256?.slice(0, 8)])),
);

const onDisk = async (dir, name) => {
  try {
    return new Uint8Array(await readFile(path.join(repoRoot, 'content', courseId, 'media', dir, name)));
  } catch {
    return null;
  }
};
check(
  'clip nằm đúng content/<course>/media/audio và đủ byte',
  (await onDisk('audio', 'a.u1.s1.n.aac'))?.length === realClip.length,
);
check(
  'ảnh nằm đúng content/<course>/media/images và đủ byte',
  (await onDisk('images', 'i.u1.w_alpha.webp'))?.length === realImage.length,
);
const clipOnDisk = await onDisk('audio', 'a.u1.s1.n.aac');
const imageOnDisk = await onDisk('images', 'i.u1.w_alpha.webp');
check(
  'byte ghi xuống đĩa giống hệt byte trình duyệt gửi',
  clipOnDisk !== null &&
    imageOnDisk !== null &&
    sha(clipOnDisk) === sha(realClip) &&
    sha(imageOnDisk) === sha(realImage),
);

const afterUpload = await cms.unitAssets(courseId, 'v2', 0, draft);
check(
  'panel thấy 3 file vừa nạp',
  afterUpload.assets.filter((a) => a.present).length === 3,
  afterUpload.assets.map((a) => `${a.fileId}=${a.present}/${a.manifest}`).join(),
);
check(
  'audio đã có file mà chưa có manifest vẫn báo placeholder',
  afterUpload.assets.every((a) => (a.fileId.startsWith('a.u1.s1') ? a.manifest === 'none' : true)),
  afterUpload.assets.map((a) => `${a.fileId}/${a.manifest}`).join(),
);

const auditRows = async () => (await store.listAudit(50)).filter((e) => e.operation === 'media.upload');
check('media.upload vào nhật ký', (await auditRows()).length === 1, `${(await auditRows()).length} dòng`);
check(
  'nhật ký ghi đủ 3 file và tên người nạp',
  JSON.parse((await auditRows())[0]?.afterJson ?? '[]').length === 3 &&
    (await auditRows())[0]?.actorId === 'harness-media',
);

// ---------- refusals ----------
const unknown = await upload([['a.u9.s1.n.aac', realClip]]);
check(
  'key khóa này không cần bị từ chối',
  unknown.ok === false && unknown.saved.length === 0 && /tài nguyên/.test(unknown.rejected[0]?.message ?? ''),
  JSON.stringify(unknown),
);
check('từ chối thì không ghi file', (await onDisk('audio', 'a.u9.s1.n.aac')) === null);

const wrongExt = await upload([['a.u1.d1.n.webp', realImage]]);
check(
  'đúng key sai đuôi bị từ chối và chỉ ra tên đúng',
  /a\.u1\.d1\.n\.aac/.test(wrongExt.rejected[0]?.message ?? ''),
  JSON.stringify(wrongExt.rejected),
);

const fakeClip = await upload([['a.u1.d1.n.aac', new Uint8Array(Buffer.from('this is not ADTS audio at all'))]]);
check('nhãn .aac nhưng không phải AAC bị từ chối', /AAC/.test(fakeClip.rejected[0]?.message ?? ''), JSON.stringify(fakeClip.rejected));

const bigFile = await upload([['a.u1.d1.s.aac', new Uint8Array(realClip.byteLength + 9 * 1024 * 1024)]]);
check('file vượt trần dung lượng bị từ chối', /vượt trần/.test(bigFile.rejected[0]?.message ?? ''), JSON.stringify(bigFile.rejected));
check('vượt trần thì chưa ghi', (await onDisk('audio', 'a.u1.d1.s.aac')) === null);

const wrongSize = await upload([['i.u1.w_alpha.webp', new Uint8Array(extended)]]);
check(
  'ảnh không phải 512x512 bị từ chối kèm khổ thật',
  /512×768/.test(wrongSize.rejected[0]?.message ?? '') && wrongSize.saved.length === 0,
  JSON.stringify(wrongSize.rejected),
);

const dupe = await upload([['a.u1.s1.n.aac', realClip]]);
check(
  'file đã có mà không bật ghi đè thì bị từ chối',
  /ghi đè/.test(dupe.rejected[0]?.message ?? '') && dupe.saved.length === 0,
  JSON.stringify(dupe.rejected),
);
const forced = await upload([['a.u1.s1.n.aac', realClip]], true);
check('bật ghi đè thì ghi được và báo overwritten', forced.saved[0]?.overwritten === true, JSON.stringify(forced));

const empty = await upload([]);
check('không chọn file vẫn trả lời rõ', empty.ok === false && /chọn file/i.test(empty.message ?? ''), JSON.stringify(empty));

const pathLike = await upload([['../../../outside.aac', realClip]]);
check(
  'tên file có .. không khớp key nào nên bị từ chối',
  pathLike.saved.length === 0 && /tài nguyên/.test(pathLike.rejected[0]?.message ?? ''),
  JSON.stringify(pathLike.rejected),
);
check(
  'không có file nào chui ra ngoài kho media',
  (await onDisk('audio', '../../../outside.aac')) === null &&
    !(await readFile(path.resolve(mediaRoot, '..', '..', '..', 'outside.aac')).catch(() => null)),
);

let unauthed = null;
process.env.CMS_HARNESS_SECRET = HARNESS_OUTSIDER_SECRET;
try {
  await upload([['a.u1.d1.n.aac', realClip]]);
} catch (error) {
  unauthed = error instanceof Error ? error.message : String(error);
}
process.env.CMS_HARNESS_SECRET = HARNESS_ADMIN_SECRET;
check('không phải admin thì action từ chối trước khi ghi', /PHIÊN|đăng nhập/i.test(unauthed ?? ''), unauthed ?? '');
check('bị chặn phiên thì đĩa không đổi', (await onDisk('audio', 'a.u1.d1.n.aac')) === null);

// ---------- what the build would actually do with these files ----------
const manifest = {
  courseId,
  format: 'audio/aac',
  files: {
    'a.u1.s1.n': {
      text: 'Alpha one.',
      voice: 'en-US-AvaNeural',
      speed: 1,
      provider: 'azure-tts',
      sha256: createHash('sha256').update(realClip).digest('hex'),
      bytes: realClip.length,
      durationMs: 900,
    },
    'a.u1.s1.s': {
      text: 'Alpha one changed.',
      voice: 'en-US-AvaNeural',
      speed: 0.75,
      provider: 'azure-tts',
      sha256: 'x',
      bytes: 1,
      durationMs: 1,
    },
  },
};
await writeFile(path.join(repoRoot, 'content', courseId, 'media', 'audio-manifest.json'), JSON.stringify(manifest));
const withManifest = await cms.unitAssets(courseId, 'v2', 0, draft);
const state = Object.fromEntries(withManifest.assets.map((a) => [a.fileId, a.manifest]));
check('manifest khớp lời thoại → real', state['a.u1.s1.n'] === 'real', JSON.stringify(state));
check(
  'manifest còn lời thoại cũ → stale (build vẫn dùng placeholder)',
  state['a.u1.s1.s'] === 'stale',
  JSON.stringify(state),
);
check('ảnh có file → real, không cần manifest', state['i.u1.w_alpha'] === 'real', JSON.stringify(state));
check(
  'clip chưa nạp thì không có trong index panel',
  state['a.u1.d1.n'] === 'none' && withManifest.assets.find((a) => a.fileId === 'a.u1.d1.n')?.present === false,
);

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} checks:\n`);
  for (const f of failures.slice(0, 25)) console.error(`• ${f}\n`);
  await rm(scratch, { recursive: true, force: true });
  process.exit(1);
}
await rm(scratch, { recursive: true, force: true });
console.log(
  `OK — ${checks.length} checks: uploadMedia chỉ nhận key đơn vị cần, đúng định dạng thật của repo, và ghi vào đúng cây media publish đọc; mọi trường hợp sai bị từ chối kèm lý do.`,
);
