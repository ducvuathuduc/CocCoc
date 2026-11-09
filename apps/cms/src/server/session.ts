import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { cache } from 'react';
import { config } from './config';
// The spelled-out path is the hook the harness scripts alias to a fake Appwrite account store;
// './auth-core' would resolve before the alias and drag a real Appwrite call into every check.
import { isAdmin, type AdminIdentity } from '@/server/admins';
import { resolveIdentity } from '@/server/auth-core';

export const SESSION_COOKIE = 'coc_cms_session';
const SESSION_TTL_SECONDS = 60 * 60 * 8;

export async function setSessionCookie(secret: string): Promise<void> {
  const jar = await cookies();
  jar.set(SESSION_COOKIE, secret, {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    secure: config().production,
    maxAge: SESSION_TTL_SECONDS,
  });
}

export async function clearSessionCookie(): Promise<void> {
  const jar = await cookies();
  jar.delete(SESSION_COOKIE);
}

export async function readSessionSecret(): Promise<string | undefined> {
  const jar = await cookies();
  return jar.get(SESSION_COOKIE)?.value;
}

/** One Account.get per request, shared by every guard below. */
const sessionIdentity = cache(() => readSessionSecret().then(resolveIdentity));

export const currentIdentity = cache(async (): Promise<AdminIdentity | null> => {
  const identity = await sessionIdentity();
  return identity && isAdmin(identity) ? identity : null;
});

/** For pages: sends the visitor to the sign-in screen when there is no admin session. */
export const requireAdmin = cache(async (): Promise<AdminIdentity> => {
  const identity = await sessionIdentity();
  if (!identity) redirect('/login');
  if (!isAdmin(identity)) redirect('/denied');
  return identity;
});

/** For Server Actions: throws instead of redirecting, so the caller can show an error toast. */
export async function assertAdmin(): Promise<AdminIdentity> {
  const identity = await currentIdentity();
  if (!identity) throw new Error('PHIÊN_HẾT_HẠN: Đăng nhập lại để tiếp tục.');
  return identity;
}
