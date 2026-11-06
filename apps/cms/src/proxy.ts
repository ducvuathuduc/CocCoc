import { NextResponse, type NextRequest } from 'next/server';
import { SESSION_COOKIE } from '@/server/session';

const PUBLIC_PREFIXES = ['/login', '/denied', '/api/auth/'];

/**
 * Presence check only. Server Actions re-verify the session and the admin allow-list, because a
 * Server Action is a POST to the route that renders it and can be reached without this proxy.
 */
export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (PUBLIC_PREFIXES.some((prefix) => pathname.startsWith(prefix))) return NextResponse.next();
  if (!request.cookies.get(SESSION_COOKIE)?.value) {
    const target = new URL('/login', request.nextUrl);
    if (pathname !== '/') target.searchParams.set('next', pathname);
    return NextResponse.redirect(target);
  }
  return NextResponse.next();
}

export const config = {
  // `/_next/*` must stay unauthenticated: the dev HMR websocket and the client chunk graph are Next
  // internals, and a 307 on the websocket leaves the page rendered but never hydrated.
  matcher: ['/((?!_next|favicon.ico|.*\\.svg$).*)'],
};
