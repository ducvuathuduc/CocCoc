'use client';

import Link from 'next/link';
import { useEffect } from 'react';
import { button, card, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

export default function AdminError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="mx-auto max-w-lg py-10" role="alert">
      <div className={cn(card, 'p-6')}>
        <h1 className="text-lg font-semibold tracking-tight">Không tải được trang này</h1>
        <p className="mt-2 text-sm leading-relaxed text-fg-3">
          Dữ liệu chưa đọc được từ máy chủ. Nội dung đã lưu vẫn an toàn; thử tải lại trang.
        </p>
        {error.digest && <p className="mt-2 text-xs text-fg-4">Mã lỗi: {error.digest}</p>}
        <div className="mt-4 flex flex-wrap gap-2">
          <button type="button" onClick={reset} className={cn(primary, 'min-h-11 px-4')}>
            Thử lại
          </button>
          <Link href="/" className={cn(button, 'inline-flex min-h-11 items-center px-4')}>
            Về Tổng quan
          </Link>
        </div>
      </div>
    </div>
  );
}
