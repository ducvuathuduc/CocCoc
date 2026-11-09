'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { createCourse } from '@/server/actions/course';
import { big, card, field, hint, primary, quiet } from '@/lib/ui';
import { cn } from '@/lib/utils';

/** `Tiếng Anh cho trẻ em` -> `tieng_anh_cho_tre_em`, the folder name the builder will read. */
function suggestId(title: string): string {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
}

/**
 * Creating a course does not need the repository: the draft store is the source of truth until the
 * course is exported. Kept to two visible fields — name and code — because a person who has never
 * seen a folder name should still be able to start.
 */
export function CreateCourse({ defaultOpen = false }: { defaultOpen?: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(defaultOpen);
  const [title, setTitle] = useState('');
  const [courseId, setCourseId] = useState('');
  const [editedId, setEditedId] = useState(false);
  const [sourceLocale, setSourceLocale] = useState('vi-VN');
  const [targetLocale, setTargetLocale] = useState('en-US');
  const [pending, startTransition] = useTransition();

  function submit() {
    startTransition(async () => {
      const result = await createCourse({
        courseId: courseId || suggestId(title),
        title,
        sourceLocale,
        targetLocale,
        version: 'v1',
      });
      if (!result.ok) {
        toast.error(result.message ?? 'Chưa tạo được khóa.');
        return;
      }
      toast.success('Đã tạo khóa. Thêm bài học đầu tiên cho khóa này.');
      if (result.warning) toast.warning(result.warning);
      router.push(`/courses/${result.courseId}`);
      router.refresh();
    });
  }

  if (!open)
    return (
      <button type="button" className={cn(primary, big)} onClick={() => setOpen(true)}>
        Tạo khóa mới
      </button>
    );

  const suggested = suggestId(title);
  return (
    <form
      className={cn(card, 'w-full max-w-xl space-y-3 p-5')}
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
    >
      <div>
        <h2 className="text-sm font-medium">Khóa mới</h2>
        <p className={cn(hint, 'mt-1')}>
          Khóa mới bắt đầu trống. Sau khi tạo, bạn thêm bài học và bấm dựng nội dung như bình
          thường.
        </p>
      </div>

      <label className="block space-y-1">
        <span className="text-xs text-fg-3">Tên khóa</span>
        <input
          className={field}
          value={title}
          onChange={(event) => {
            setTitle(event.target.value);
            if (!editedId) setCourseId(suggestId(event.target.value));
          }}
          placeholder="Ví dụ: Tiếng Anh cho trẻ em"
          autoFocus
        />
      </label>

      <label className="block space-y-1">
        <span className="text-xs text-fg-3">Mã khóa</span>
        <input
          className={field}
          value={courseId}
          onChange={(event) => {
            setEditedId(true);
            setCourseId(event.target.value.toLowerCase());
          }}
          placeholder={suggested || 'vi_en'}
        />
        <span className={hint}>
          Mã này thành tên thư mục nội dung. Chỉ chữ thường, số và dấu gạch dưới.
        </span>
      </label>

      <div className="grid grid-cols-2 gap-3">
        <label className="block space-y-1">
          <span className="text-xs text-fg-3">Tiếng của học viên</span>
          <input
            className={field}
            value={sourceLocale}
            onChange={(event) => setSourceLocale(event.target.value)}
          />
        </label>
        <label className="block space-y-1">
          <span className="text-xs text-fg-3">Tiếng đang học</span>
          <input
            className={field}
            value={targetLocale}
            onChange={(event) => setTargetLocale(event.target.value)}
          />
        </label>
      </div>

      <div className="flex gap-2 pt-1">
        <button
          type="submit"
          className={cn(primary, big)}
          disabled={pending || !title.trim() || !(courseId || suggested)}
        >
          {pending ? 'Đang tạo…' : 'Tạo khóa'}
        </button>
        <button type="button" className={quiet} onClick={() => setOpen(false)} disabled={pending}>
          Hủy
        </button>
      </div>
    </form>
  );
}
