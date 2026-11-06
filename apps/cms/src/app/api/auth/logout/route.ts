import { NextResponse } from 'next/server';
import { logout } from '@/server/auth-core';
import { clearSessionCookie, readSessionSecret } from '@/server/session';

export async function POST(): Promise<Response> {
  const secret = await readSessionSecret();
  if (secret) await logout(secret);
  await clearSessionCookie();
  return NextResponse.json({ ok: true });
}
