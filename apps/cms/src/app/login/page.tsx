import { redirect } from 'next/navigation';
import { currentIdentity } from '@/server/session';
import { LoginPage } from './login-page';

export const instant = false;

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const identity = await currentIdentity();
  if (identity) redirect('/');
  const { next } = await searchParams;
  return <LoginPage next={next ?? '/'} />;
}
