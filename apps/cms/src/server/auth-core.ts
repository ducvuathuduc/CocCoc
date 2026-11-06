import { Account, AppwriteException, Client, Users } from 'node-appwrite';
import { config } from './config';
import type { AdminIdentity } from './admins';

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}

function accountFor(sessionSecret?: string): Account {
  const c = config();
  const client = new Client().setEndpoint(c.endpoint).setProject(c.projectId);
  if (sessionSecret) client.setSession(sessionSecret);
  return new Account(client);
}

function serverClient(): Client {
  const c = config();
  return new Client().setEndpoint(c.endpoint).setProject(c.projectId).setKey(c.apiKey);
}

/**
 * The session cookie holds the Appwrite session secret, never a key. Only Appwrite can turn a
 * secret into an identity: a copied cookie is worthless on a machine that does not talk to the
 * project, and nothing here skips the password check.
 */
export async function resolveIdentity(
  secret: string | undefined,
): Promise<AdminIdentity | null> {
  if (!secret) return null;
  if (config().mode !== 'appwrite') return null;
  try {
    const user = await accountFor(secret).get();
    return { userId: user.$id, email: user.email, name: user.name || user.email };
  } catch (error) {
    if (error instanceof AppwriteException && error.code === 401) return null;
    throw error;
  }
}

export async function loginWithPassword(
  email: string,
  password: string,
): Promise<{ secret: string; identity: AdminIdentity }> {
  const c = config();
  if (c.mode !== 'appwrite')
    throw new AuthError(
      'Máy này chưa nối Appwrite nên chưa đăng nhập được. Nhờ người quản trị điền APPWRITE_* vào .secrets/real.env.',
    );
  let checked;
  try {
    // Appwrite never returns a session secret to a server-side call, so this session only proves the
    // password is right; the session the cookie can use is minted below. Nothing is skipped: a wrong
    // password throws here, before any secret exists.
    checked = await accountFor().createEmailPasswordSession({ email, password });
  } catch (error) {
    const code = error instanceof AppwriteException ? error.code : undefined;
    if (code === 400 || code === 401) throw new AuthError('Email hoặc mật khẩu không đúng.');
    if (code === 429) throw new AuthError('Bạn thử đăng nhập quá nhiều lần, chờ một phút nhé.');
    throw new AuthError('Không gọi được Appwrite. Kiểm tra APPWRITE_ENDPOINT và project.');
  }
  const users = new Users(serverClient());
  let secret: string | undefined;
  try {
    secret = (await users.createSession({ userId: checked.userId })).secret;
  } catch (error) {
    const type = error instanceof AppwriteException ? error.type : undefined;
    if (type === 'user_not_found') throw new AuthError('Tài khoản này không còn trong project.');
    throw new AuthError('Appwrite không cấp được phiên cho tài khoản này.');
  } finally {
    await users
      .deleteSession({ userId: checked.userId, sessionId: checked.$id })
      .catch(() => undefined);
  }
  if (!secret) throw new AuthError('Appwrite không trả về session secret.');
  const identity = await resolveIdentity(secret);
  if (!identity) throw new AuthError('Phiên đăng nhập không hợp lệ.');
  return { secret, identity };
}

export async function logout(secret: string): Promise<void> {
  if (!secret || config().mode !== 'appwrite') return;
  await accountFor(secret)
    .deleteSession({ sessionId: 'current' })
    .catch(() => undefined);
}
