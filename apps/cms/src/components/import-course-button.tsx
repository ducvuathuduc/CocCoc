'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { importCourseFromRepo } from '@/server/actions/import';
import { button, hint, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * Turns authoring tables that are already in the repository into editable drafts. Deliberately one
 * button and one plain sentence: the three-way import/export/gate bar belongs on the release screen,
 * not on a course that has no draft yet.
 */
export function ImportCourseButton({
  courseId,
  version = 'v2',
  variant = 'primary',
}: {
  courseId: string;
  version?: string;
  variant?: 'primary' | 'quiet';
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function run() {
    setBusy(true);
    try {
      const result = await importCourseFromRepo(courseId, version);
      if (!result.ok) {
        toast.error(result.message ?? 'Không lấy được nội dung cũ.');
        return;
      }
      toast.success(`Đã lấy ${result.units} bài vào đây. Bấm vào tên bài để sửa.`);
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không lấy được nội dung cũ.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <button
        type="button"
        className={cn(variant === 'primary' ? primary : button, 'min-h-11 px-4')}
        onClick={run}
        disabled={busy}
      >
        {busy ? 'Đang lấy bài…' : `Lấy khóa ${courseId} (${version})`}
      </button>
      <p className={hint}>
        Máy đọc danh sách bài trong thư mục nội dung gốc và tạo một bản soạn cho từng bài. Nội dung
        trong thư mục gốc chưa bị thay đổi.
      </p>
    </div>
  );
}
