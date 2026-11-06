'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { importCourseFromRepo } from '@/server/actions/import';
import { button } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * Replacing drafts with the repository's authoring tables is a maintainer's operation, not an
 * editing step, so it lives in the advanced area instead of next to the workflow buttons.
 */
export function ContentActions({ courseId }: { courseId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function importFromRepo() {
    setBusy(true);
    try {
      const result = await importCourseFromRepo(courseId);
      if (!result.ok) {
        toast.error(result.message ?? 'Chưa nhập được nội dung.');
        return;
      }
      toast.success(
        `Đã nhập ${result.units} bài. Bài trùng tên đã được thay bằng bản trong thư mục gốc.`,
      );
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Có lỗi xảy ra.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={busy}
          onClick={() => {
            if (
              !window.confirm(
                'Nhập sẽ thay bài đang soạn ở đây bằng bản trong thư mục nội dung gốc, với những bài trùng tên.\n\nBài bạn chưa lưu sẽ mất. Tiếp tục?',
              )
            )
              return;
            importFromRepo();
          }}
          className={cn(button, 'py-1.5')}
        >
          {busy ? 'Đang nhập…' : 'Nhập từ thư mục nội dung gốc'}
        </button>
        <p className="text-xs text-fg-4">
          Dùng khi thư mục gốc đang có bản mới nhất và bạn muốn soạn tiếp ở đây. Bài trùng tên bị
          thay, nên hệ thống hỏi lại trước khi nhập.
        </p>
      </div>
    </div>
  );
}
