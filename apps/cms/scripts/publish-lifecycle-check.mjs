// Publishing-lifecycle proof for the CMS actions (apps/cms/src/server/actions/lifecycle.ts): the
// three write controls an admin presses against a live course — "Gỡ bản live" (unpublish),
// "Nghỉ hưu bản này" (retire), "Quay lại bản này" (rollback) — and the read "Lịch sử bản".
//
// The real path shells out to tools/content/lifecycle-appwrite.mjs, which talks to Appwrite Learning
// (Phase 1 cloud integration — currently BLOCKED, so it cannot run here). What this harness covers is
// the part we CAN prove without a project: the action is wired, the admin gate fires, and every
// unsupported mode returns the plain Vietnamese sentence the UI shows instead of a stack trace. The
// genuine Appwrite round-trip is covered by services/learning/test/content-lifecycle.test.mjs (real
// router, in-memory persistence) and is documented as BLOCKED for end-to-end here.
//
// Runs the real actions against the faked identity from harness-auth.mjs; nothing contacts a project.
import { build } from 'esbuild';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.publish-lifecycle-'));

await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
  'utf8',
);
await writeFile(path.join(scratch, 'stub-auth-core.mjs'), authCoreStub(), 'utf8');

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/server/actions/lifecycle';\n" +
      "export { config } from '@/server/config';\n",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: {
    '@': path.join(appRoot, 'src').replace(/\\/g, '/'),
    '@/server/auth-core': path.join(scratch, 'stub-auth-core.mjs').replace(/\\/g, '/'),
    'next/headers': path.join(scratch, 'stub-headers.mjs').replace(/\\/g, '/'),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};
const join = (list) => list.join(', ');

// ---------- File mode: the CMS stores content locally, so Lifecycle has no shared server ----------
// Force mode 'file' deterministically: an endpoint that is not a URL makes readConfig() (and any
// APPWRITE_* from the shell or repo .secrets/real.env) resolve to the local file store.
for (const key of ['APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY', 'CMS_ALLOW_PUBLISH'])
  delete process.env[key];
process.env.APPWRITE_ENDPOINT = 'file-mode-invalid';
Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-lifecycle',
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
  CMS_DATA_DIR: path.join(scratch, 'data'),
  CMS_REPO_ROOT: path.resolve(appRoot, '..', '..'),
});

const cms = await import(pathToFileURL(bundleFile).href);
check(
  'chế độ máy chủ là file (không có Appwrite)',
  cms.config().mode === 'file',
  cms.config().mode,
);

const read = await cms.getContentVersions('vi_en');
check(
  'xem lịch sử bản ở chế độ file trả về lời tiếng Việt, không ném lỗi',
  read.ok === false &&
    typeof read.message === 'string' &&
    read.message.includes('tệp') &&
    read.message.includes('chưa nối máy chủ dùng chung'),
  read.message ?? '',
);

const unpub = await cms.runLifecycle('vi_en', 'unpublish', {});
check(
  'gỡ bản live ở chế độ file trả về lời tiếng Việt, không ném lỗi',
  unpub.ok === false &&
    typeof unpub.message === 'string' &&
    unpub.message.includes('tệp') &&
    unpub.message.includes('chưa đổi được trạng thái bản'),
  unpub.message ?? '',
);

// ---------- Appwrite mode but publish locked: the real write must never fire ----------
const cms2 = await import(pathToFileURL(bundleFile).href + '?appwrite');
Object.assign(process.env, {
  APPWRITE_ENDPOINT: 'https://example.invalid/v1',
  APPWRITE_PROJECT_ID: 'harness-project',
  APPWRITE_API_KEY: 'harness-key',
  CMS_ALLOW_PUBLISH: '',
  // CMS_DATABASE_ID defaults to cocenglish.
});
check(
  'chế độ máy chủ là appwrite (đủ thông tin)',
  cms2.config().mode === 'appwrite',
  cms2.config().mode,
);
check(
  'công tắc xuất bản đang tắt',
  cms2.config().publishAllowed === false,
  String(cms2.config().publishAllowed),
);

const rollback = await cms2.runLifecycle('vi_en', 'rollback', { versionId: 'v1' });
check(
  'quay lại bản bị khóa công tắc thì trả về đúng câu hướng dẫn CMS_ALLOW_PUBLISH, không gọi máy chủ',
  rollback.ok === false &&
    typeof rollback.message === 'string' &&
    rollback.message.includes('CMS_ALLOW_PUBLISH=1'),
  rollback.message ?? '',
);

// ---------- Appwrite mode + publish allowed: the action WOULD spawn the script (not exercised here) ----------
// config() caches per module instance, so re-import with a fresh query to re-read the env.
Object.assign(process.env, { CMS_ALLOW_PUBLISH: '1' });
const cms3 = await import(pathToFileURL(bundleFile).href + '?open');
check(
  'đủ thông tin + công tắc mở thì action vượt qua cổng, sẵn sàng gọi lifecycle-appwrite.mjs',
  cms3.config().publishAllowed === true,
  String(cms3.config().publishAllowed),
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} publishing-lifecycle checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: lịch sử bản và ba nút đổi trạng thái (gỡ live, nghỉ hưu, quay lại) được nối đúng; cổng admin và cổng chế độ máy chủ đều trả câu tiếng Việt rõ ràng thay vì ném lỗi; ở chế độ Appwrite nhưng công tắc tắt thì action không gọi máy chủ; thực thi thật (gọi lifecycle-appwrite.mjs qua Appwrite Learning) thuộc pha 1 cloud integration đang BLOCKED nên chưa chạy được ở đây.`,
);
