import Link from 'next/link';
import { cn } from '@/lib/utils';
import { button, card, code } from '@/lib/ui';

export default function DeniedPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4 text-fg">
      <div className={cn(card, 'animate-scale-in max-w-md p-8 shadow-lift')}>
        <h1 className="text-lg font-semibold tracking-tight">Tài khoản này không có quyền CMS</h1>
        <p className="mt-2 text-sm text-fg-3">
          Thêm <span className={code}>userId</span> của bạn vào
          <span className={cn(code, 'ml-1')}> CMS_ADMIN_USER_IDS</span> rồi đăng nhập lại.
        </p>
        <form action="/api/auth/logout" method="post" className="mt-6">
          <button type="submit" className={cn(button, 'px-4')}>
            Đăng xuất
          </button>
        </form>
        <Link href="/login" className="mt-3 inline-block text-sm text-fg-3 hover:text-primary-text">
          Quay lại trang đăng nhập
        </Link>
      </div>
    </main>
  );
}
