// Login proof for the Appwrite path (`src/server/auth-core.ts`). Two calls make a session here and
// neither alone is enough: `Account.createEmailPasswordSession` proves the password but never hands
// back a secret to a server, and `Users.createSession` hands back a secret without checking the
// password at all. The harness runs the real code against a stand-in Appwrite that behaves exactly
// that way, so a refactor cannot quietly drop the password check, leak the proof session, or start
// trusting whatever email was typed. Offline: no project, no credentials, no network.
import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const selfFile = fileURLToPath(import.meta.url);
const fileMode = process.argv.includes('--file-mode');

const STUB = `
export const world = {
  email: 'cms-admin@cocenglish.test',
  password: 'right-horse',
  userId: 'user-admin',
  rateLimited: false,
  unreachable: false,
  mintError: null,
  seq: 0,
  sessions: new Map(),
  calls: [],
};
export function resetWorld() {
  world.rateLimited = false;
  world.unreachable = false;
  world.mintError = null;
  world.seq = 0;
  world.sessions = new Map();
  world.calls = [];
}
export class AppwriteException extends Error {
  constructor(message, code, type) {
    super(message);
    this.name = 'AppwriteException';
    this.code = code;
    this.type = type;
  }
}
function addSession(userId) {
  const id = 'session-' + ++world.seq;
  const session = { $id: id, userId, secret: 'secret-' + id };
  world.sessions.set(id, session);
  return session;
}
const bySecret = (secret) => [...world.sessions.values()].find((s) => s.secret === secret);
export class Client {
  constructor() {
    this.cfg = { endpoint: '', project: '', key: '', session: '' };
  }
  setEndpoint(v) { this.cfg.endpoint = v; return this; }
  setProject(v) { this.cfg.project = v; return this; }
  setKey(v) { this.cfg.key = v; return this; }
  setSession(v) { this.cfg.session = v; return this; }
}
export class Account {
  constructor(client) { this.client = client; }
  async createEmailPasswordSession({ email, password }) {
    world.calls.push('account.createEmailPasswordSession');
    if (world.unreachable) throw new Error('fetch failed');
    if (world.rateLimited)
      throw new AppwriteException('Too many requests', 429, 'rate_limit_exceeded');
    if (email.toLowerCase() !== world.email || password !== world.password)
      throw new AppwriteException('Wrong credentials', 401, 'user_invalid_credentials');
    const session = addSession(world.userId);
    // Real Appwrite answers a server-side call without a secret, so the session this proves is
    // unusable as a cookie and has to be deleted again.
    return { $id: session.$id, userId: world.userId, secret: undefined };
  }
  async get() {
    world.calls.push(this.client.cfg.key ? 'account.get:with-key' : 'account.get');
    const session = bySecret(this.client.cfg.session);
    if (!session) throw new AppwriteException('Unauthorized', 401, 'session_invalid');
    return { $id: session.userId, email: world.email, name: 'CMS Admin' };
  }
  async deleteSession({ sessionId }) {
    world.calls.push('account.deleteSession');
    if (sessionId === 'current') {
      const session = bySecret(this.client.cfg.session);
      if (session) world.sessions.delete(session.$id);
    }
  }
}
export class Users {
  constructor(client) { this.client = client; }
  async createSession({ userId }) {
    world.calls.push('users.createSession');
    if (!this.client.cfg.key)
      throw new AppwriteException('Missing key', 401, 'general_unauthorized_scope');
    if (world.mintError) throw world.mintError;
    if (userId !== world.userId)
      throw new AppwriteException('User not found', 404, 'user_not_found');
    const session = addSession(userId);
    return { $id: session.$id, userId, secret: session.secret };
  }
  async deleteSession({ sessionId }) {
    world.calls.push('users.deleteSession');
    world.sessions.delete(sessionId);
  }
}
`;

for (const entry of await readdir(path.join(appRoot, 'node_modules')).catch(() => []))
  if (entry.startsWith('.auth-login-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });

const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.auth-login-'));
// The bundle keeps `node-appwrite` external, so the stub living in this scratch dir's own
// node_modules is what the real auth-core code resolves at run time.
const stubDir = path.join(scratch, 'node_modules', 'node-appwrite');
await mkdir(stubDir, { recursive: true });
await writeFile(
  path.join(stubDir, 'package.json'),
  '{"name":"node-appwrite","type":"module","main":"index.js"}',
  'utf8',
);
await writeFile(path.join(stubDir, 'index.js'), STUB, 'utf8');

process.env.APPWRITE_ENDPOINT ??= 'https://appwrite.test/v1';
process.env.APPWRITE_PROJECT_ID ??= 'proj-test';
process.env.APPWRITE_API_KEY ??= 'key-test';
process.env.CMS_ADMIN_USER_IDS = 'user-admin';

const bundled = await build({
  stdin: {
    contents: "export * from '@/server/auth-core'; export * from '@/server/admins';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: { '@': path.join(appRoot, 'src') },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

const { world, resetWorld, AppwriteException } = await import(
  pathToFileURL(path.join(stubDir, 'index.js')).href
);
const cms = await import(pathToFileURL(bundleFile).href);

let checks = 0;
const failures = [];
function assert(label, ok, detail = '') {
  checks += 1;
  if (!ok) failures.push(`${label}${detail ? `\n  ${detail}` : ''}`);
}
const liveSessions = () => [...world.sessions.values()];
const errorFrom = (fn) => fn().then(() => null, (e) => e);
function finish(extra = '') {
  if (failures.length) {
    console.error(`FAIL — ${failures.length}/${checks} login checks failed:`);
    for (const f of failures) console.error(`  - ${f}`);
  } else {
    console.log(`OK — ${checks} checks: ${extra}`);
  }
}

const NO_APPWRITE =
  'Máy này chưa nối Appwrite nên chưa đăng nhập được. Nhờ người quản trị điền APPWRITE_* vào .secrets/real.env.';

if (fileMode) {
  // The child runs with the Appwrite trio emptied, so config() picks the file store.
  resetWorld();
  const refused = await errorFrom(() => cms.loginWithPassword(world.email, world.password));
  assert('máy chưa nối Appwrite thì không ai đăng nhập được', refused?.message === NO_APPWRITE, refused?.message);
  assert('và từ chối ngay trước khi gọi Appwrite', world.calls.length === 0, world.calls.join(','));
  assert('chế độ file thì mọi secret đều vô hiệu', (await cms.resolveIdentity('anything')) === null);
  await rm(scratch, { recursive: true, force: true });
  finish('chế độ file từ chối đăng nhập mà không gọi Appwrite.');
  process.exitCode = failures.length ? 1 : 0;
} else {
  // 1. A good password yields a cookie secret Appwrite itself recognises.
  resetWorld();
  const signed = await cms.loginWithPassword('CMS-Admin@cocenglish.test', 'right-horse');
  assert('đăng nhập đúng cho ra session secret', signed.secret?.startsWith('secret-') === true, signed.secret);
  assert(
    'đúng thứ tự: soát mật khẩu trước, mint session sau',
    world.calls[0] === 'account.createEmailPasswordSession' && world.calls[1] === 'users.createSession',
    world.calls.join(' → '),
  );
  assert(
    'danh tính lấy từ Appwrite, không phải từ ô email',
    signed.identity.userId === 'user-admin' && signed.identity.email === world.email,
    JSON.stringify(signed.identity),
  );
  assert(
    'danh tính đọc bằng session secret, không bằng key',
    world.calls.includes('account.get') && !world.calls.includes('account.get:with-key'),
    world.calls.join(' → '),
  );
  assert(
    'session chứng minh mật khẩu bị xóa ngay, chỉ còn session của cookie',
    liveSessions().length === 1 && liveSessions()[0].secret === signed.secret,
    JSON.stringify(liveSessions()),
  );
  assert('userId có trong CMS_ADMIN_USER_IDS thì isAdmin bật', cms.isAdmin(signed.identity) === true);

  // 2. A wrong password never reaches the minting call.
  resetWorld();
  const bad = await errorFrom(() => cms.loginWithPassword(world.email, 'guess'));
  assert('sai mật khẩu bị từ chối bằng đúng câu của màn hình', bad?.message === 'Email hoặc mật khẩu không đúng.', bad?.message);
  assert(
    'sai mật khẩu thì không mint session, không session nào sống sót',
    !world.calls.includes('users.createSession') && liveSessions().length === 0,
    world.calls.join(' → '),
  );

  resetWorld();
  const other = await errorFrom(() => cms.loginWithPassword('someone@cocenglish.test', world.password));
  assert('email lạ cũng bị từ chối như mật khẩu sai', other?.message === 'Email hoặc mật khẩu không đúng.', other?.message);

  // 3. Every other Appwrite answer maps to a message the operator can act on.
  resetWorld();
  world.rateLimited = true;
  const limited = await errorFrom(() => cms.loginWithPassword(world.email, world.password));
  assert('429 báo đúng chuyện thử quá nhiều lần', limited?.message === 'Bạn thử đăng nhập quá nhiều lần, chờ một phút nhé.', limited?.message);

  resetWorld();
  world.unreachable = true;
  const offline = await errorFrom(() => cms.loginWithPassword(world.email, world.password));
  assert('không gọi được Appwrite thì nói tới endpoint/project', offline?.message === 'Không gọi được Appwrite. Kiểm tra APPWRITE_ENDPOINT và project.', offline?.message);

  resetWorld();
  world.mintError = new Error('appwrite down');
  const mintDown = await errorFrom(() => cms.loginWithPassword(world.email, world.password));
  assert('mint thất bại thì nói rõ Appwrite không cấp phiên', mintDown?.message === 'Appwrite không cấp được phiên cho tài khoản này.', mintDown?.message);
  assert('mint thất bại vẫn dọn session chứng minh mật khẩu', liveSessions().length === 0, JSON.stringify(liveSessions()));

  resetWorld();
  world.mintError = new AppwriteException('User not found', 404, 'user_not_found');
  const gone = await errorFrom(() => cms.loginWithPassword(world.email, world.password));
  assert('tài khoản đã bị xóa khỏi project thì nói đúng chuyện', gone?.message === 'Tài khoản này không còn trong project.', gone?.message);
  assert('lỗi này cũng không để session rời', liveSessions().length === 0, JSON.stringify(liveSessions()));

  // 4. A session Appwrite does not recognise opens nothing.
  resetWorld();
  assert('secret bịa ra không phải danh tính', (await cms.resolveIdentity('secret-from-nowhere')) === null);
  assert('secret trống cũng vậy', (await cms.resolveIdentity(undefined)) === null);

  // 5. Logging out drops the session on the Appwrite side, so cookies do not pile up.
  resetWorld();
  const bye = await cms.loginWithPassword(world.email, world.password);
  await cms.logout(bye.secret);
  assert('thoát tài khoản xóa đúng session của cookie', liveSessions().length === 0, JSON.stringify(liveSessions()));
  world.calls.length = 0;
  await cms.logout('');
  assert('thoát khi không có session trong cookie thì không gọi Appwrite', world.calls.length === 0, world.calls.join(','));

  // 6. Signing in is not the same as being allowed in: the gate keys on the Appwrite userId only.
  resetWorld();
  const outsider = await cms.loginWithPassword(world.email, world.password);
  assert(
    'đăng nhập hợp lệ mà userId không trong CMS_ADMIN_USER_IDS thì vẫn bị chặn',
    cms.isAdmin({ ...outsider.identity, userId: 'somebody-else' }) === false,
    JSON.stringify(outsider.identity),
  );
  assert(
    'không có ô nào để tự khai userId — quyền chỉ đến từ danh tính Appwrite',
    cms.isAdmin(outsider.identity) === true,
  );

  // 7. The file store must not become a back door when the trio is missing.
  const child = spawnSync(process.execPath, [selfFile, '--file-mode'], {
    encoding: 'utf8',
    env: { ...process.env, APPWRITE_ENDPOINT: '', APPWRITE_PROJECT_ID: '', APPWRITE_API_KEY: '' },
  });
  const out = (child.stdout ?? '') + (child.stderr ?? '');
  assert(
    'máy chưa nối Appwrite thì không ai đăng nhập được',
    child.status === 0 && out.includes('OK — 3 checks'),
    `status=${child.status}\n${out}`,
  );

  await rm(scratch, { recursive: true, force: true });
  finish(
    'đăng nhập soát mật khẩu qua Appwrite trước rồi mới mint session, dọn session chứng minh, danh tính là của Appwrite chứ không phải ô email, từng lỗi Appwrite có một câu riêng, mint hỏng không để session rời, thoát là xóa session, secret bịa không mở được gì, userId ngoài danh sách vẫn bị chặn, và máy chưa nối Appwrite thì không ai đăng nhập được.',
  );
  process.exitCode = failures.length ? 1 : 0;
}
