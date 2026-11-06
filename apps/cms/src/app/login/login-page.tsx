'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { ThemeToggle } from '@/components/theme';
import { cn } from '@/lib/utils';
import { card, field, primary } from '@/lib/ui';

export function LoginPage({ next }: { next: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setError(null);
    start(async () => {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          email: form.get('email') ?? '',
          password: form.get('password') ?? '',
        }),
      });
      const body = (await response.json().catch(() => ({}))) as { error?: string };
      if (!response.ok) {
        setError(body.error ?? 'Đăng nhập không thành công.');
        return;
      }
      router.replace(next);
      router.refresh();
    });
  }

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background px-4 text-fg">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(65%_45%_at_50%_0%,var(--primary-soft),transparent_70%)]"
      />
      <div className="absolute right-4 top-4 w-32">
        <ThemeToggle />
      </div>
      <form
        onSubmit={submit}
        className={cn(card, 'relative w-full max-w-sm animate-scale-in p-8 shadow-lift')}
      >
        <div className="flex items-center gap-2">
          <span className="size-2.5 rounded-full bg-primary shadow-[0_0_0_4px_var(--primary-soft)]" />
          <h1 className="text-xl font-semibold tracking-tight">CocEnglish CMS</h1>
        </div>
        <p className="mt-1 text-sm text-fg-3">Quản lý nội dung và vận hành cho app.</p>

        <label className="mt-6 block text-sm text-fg-2">
          Email
          <input
            name="email"
            type="email"
            required
            autoComplete="username"
            className={cn(field, 'mt-1')}
          />
        </label>

        <label className="mt-4 block text-sm text-fg-2">
          Mật khẩu
          <input
            name="password"
            type="password"
            required
            autoComplete="current-password"
            className={cn(field, 'mt-1')}
          />
        </label>

        {error && (
          <p
            role="alert"
            className="mt-4 animate-pop rounded-lg bg-danger-bg px-3 py-2 text-sm text-danger-fg ring-1 ring-danger-bd"
          >
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={pending}
          className={cn(
            primary,
            'mt-6 flex w-full items-center justify-center gap-2 py-2 disabled:opacity-60',
          )}
        >
          {pending && (
            <span className="size-3.5 animate-spin rounded-full border-2 border-white/40 border-t-white" />
          )}
          {pending ? 'Đang đăng nhập…' : 'Đăng nhập'}
        </button>

        <p className="mt-4 text-center text-xs text-fg-4">
          Tài khoản quản trị do máy chủ cấp, không tự đăng ký ở đây.
        </p>
      </form>
    </main>
  );
}
