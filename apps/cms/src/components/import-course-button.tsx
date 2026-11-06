'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { importCourseFromRepo } from '@/server/actions/import';
import { big, hint, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * The one control a new operator needs before there is anything to edit: turn the already-written
 * lessons into drafts. Deliberally a single button with a plain sentence — the three-way
 * import/export/gate bar is for the release screen, not for a course that has no content yet.
 */
export function ImportCourseButton({ courseId }: { courseId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function run() {
    setBusy(true);
    try {
      const result = await importCourseFromRepo(courseId);
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
      <button type="button" className={cn(primary, big)} onClick={run} disabled={busy}>
        {busy ? 'Đang lấy bài…' : 'Lấy các bài đã viết sẵn'}
      </button>
      <p className={hint}>
        Máy đọc danh sách bài trong thư mục nội dung gốc và tạo một bản soạn cho từng bài. Nội dung
        trong thư mục gốc chưa bị thay đổi.
      </p>
    </div>
  );
}
