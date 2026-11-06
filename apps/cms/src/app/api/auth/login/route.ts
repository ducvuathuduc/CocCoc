import { NextResponse, type NextRequest } from 'next/server';
import { isAdmin } from '@/server/admins';
import { AuthError, loginWithPassword } from '@/server/auth-core';
import { setSessionCookie } from '@/server/session';

export async function POST(request: NextRequest): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as {
    email?: string;
    password?: string;
  };

  try {
    const { secret, identity } = await loginWithPassword(
      (body.email ?? '').trim(),
      body.password ?? '',
    );
    if (!isAdmin(identity)) {
      return NextResponse.json(
        { error: 'Tài khoản này không có quyền CMS. Cần thêm userId vào CMS_ADMIN_USER_IDS.' },
        { status: 403 },
      );
    }
    await setSessionCookie(secret);
    return NextResponse.json({ ok: true });
  } catch (error) {
    if (error instanceof AuthError)
      return NextResponse.json({ error: error.message }, { status: 401 });
    return NextResponse.json({ error: 'Lỗi không xác định khi đăng nhập.' }, { status: 500 });
  }
}
