'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { toast } from 'sonner';
import { createUnitDraft, saveCourseMeta } from '@/server/actions/course';
import { deleteUnitDraft, moveUnitDraft } from '@/server/actions/unit';
import type { Cefr, CourseMeta } from '@/cms/types';
import { button, danger, field, ghost, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

export function CourseMetaForm({
  courseId,
  revision,
  meta,
  version,
}: {
  courseId: string;
  revision: number;
  meta: CourseMeta;
  version: string;
}) {
  const router = useRouter();
  const [values, setValues] = useState({ ...meta, version });
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    try {
      const result = await saveCourseMeta({ ...values, courseId, expectedRevision: revision });
      if (result.ok) {
        toast.success('Đã lưu thông tin khóa.');
        if (result.warning) toast.warning(result.warning);
        router.refresh();
      } else toast.error(result.message ?? 'Không lưu được.');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không lưu được.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form
      className="grid grid-cols-2 gap-3"
      onSubmit={(e) => {
        e.preventDefault();
        void submit();
      }}
    >
      <label className="col-span-2 text-xs text-fg-4">
        Tên khóa học
        <input
          className={field}
          value={values.title}
          onChange={(e) => setValues({ ...values, title: e.target.value })}
        />
      </label>
      <label className="text-xs text-fg-4">
        Học từ ngôn ngữ nào
        <input
          className={field}
          value={values.sourceLocale}
          onChange={(e) => setValues({ ...values, sourceLocale: e.target.value })}
        />
      </label>
      <label className="text-xs text-fg-4">
        Sang ngôn ngữ nào
        <input
          className={field}
          value={values.targetLocale}
          onChange={(e) => setValues({ ...values, targetLocale: e.target.value })}
        />
      </label>
      <label className="text-xs text-fg-4">
        Thư mục nội dung
        <input
          className={field}
          value={values.version}
          onChange={(e) => setValues({ ...values, version: e.target.value })}
        />
      </label>
      <label className="text-xs text-fg-4">
        Khóa này đang ở giai đoạn nào
        <select
          className={field}
          value={values.status}
          onChange={(e) => setValues({ ...values, status: e.target.value as CourseMeta['status'] })}
        >
          <option value="DRAFT">Chưa xong — đang soạn</option>
          <option value="ACTIVE">Đang dùng cho app</option>
          <option value="RETIRED">Đã ngừng dùng</option>
        </select>
      </label>
      <div className="col-span-2">
        <button type="submit" className={primary} disabled={busy}>
          {busy ? 'Đang lưu…' : 'Lưu thông tin'}
        </button>
      </div>
    </form>
  );
}

export function NewUnitForm({ courseId }: { courseId: string }) {
  const router = useRouter();
  const [name, setName] = useState('');
  const [cefr, setCefr] = useState<Cefr>('A1');
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    try {
      const result = await createUnitDraft(courseId, name, cefr);
      if (!result.ok || !result.unitId) {
        toast.error(result.message ?? 'Không tạo được bài học.');
        return;
      }
      router.push(`/courses/${courseId}/units/${result.unitId}`);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không tạo được bài học.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form
      className="flex flex-wrap items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        void submit();
      }}
    >
      <input
        className={cn(field, 'w-60')}
        aria-label="Tên bài học mới"
        placeholder="Tên bài học, ví dụ Gia đình"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      <select
        className={cn(field, 'w-24')}
        aria-label="Trình độ của bài học mới"
        value={cefr}
        onChange={(e) => setCefr(e.target.value as Cefr)}
      >
        <option value="A1">A1</option>
        <option value="A2">A2</option>
        <option value="B1">B1</option>
        <option value="B2">B2</option>
      </select>
      <button type="submit" className={button} disabled={busy || !name.trim()}>
        {busy ? 'Đang tạo…' : '+ Thêm bài học'}
      </button>
    </form>
  );
}

export function DeleteUnitButton({
  courseId,
  unitId,
  title,
}: {
  courseId: string;
  unitId: string;
  title: string;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (
      !window.confirm(
        `Xóa bài “${title || unitId}” khỏi danh sách bài?\n\n` +
          `Bài này sẽ biến mất khỏi màn soạn bài; tệp trong thư mục nội dung gốc vẫn còn nguyên cho tới lần ghi ra kế tiếp.\n` +
          `Các bài đứng sau sẽ đổi mã trong app (u05 thành u04…), nên tiến độ người học đã lưu theo mã cũ có thể lệch.\n` +
          `Bài cũng bị gỡ khỏi phần học đang chứa nó.`,
      )
    )
      return;
    setBusy(true);
    try {
      const result = await deleteUnitDraft(courseId, unitId);
      if (result.ok) {
        toast.success('Đã xóa bài khỏi bản soạn.');
        if (result.warning) toast.warning(result.warning);
        router.refresh();
      } else toast.error(result.message ?? 'Không xóa được.');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không xóa được.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <button type="button" className={danger} onClick={submit} disabled={busy}>
      {busy ? 'Đang xóa…' : 'Xóa'}
    </button>
  );
}

const pad = (index: number): string => `u${String(index + 1).padStart(2, '0')}`;

/**
 * Reorder is a real editing need, but the repo numbers units by position, so moving one rewrites the
 * `uNN` code of the units it passes. The dialog says exactly which codes change before it writes.
 * The row stays locked through the re-render, because a click landing on the pre-refresh table would
 * ask for a position counted from stale props.
 */
export function UnitMoveButtons({
  courseId,
  unitId,
  title,
  position,
  total,
}: {
  courseId: string;
  unitId: string;
  title: string;
  position: number;
  total: number;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [refreshing, startRefresh] = useTransition();
  const locked = busy || refreshing;

  async function move(to: number) {
    const passing = to < position ? position - to : to - position;
    const shifted =
      to < position
        ? `${pad(to)}…${pad(position - 1)} thành ${pad(to + 1)}…${pad(position)}`
        : `${pad(position + 1)}…${pad(to)} thành ${pad(position)}…${pad(to - 1)}`;
    if (
      !window.confirm(
        `Chuyển “${title || unitId}” từ vị trí ${position + 1} sang ${to + 1}?\n\n` +
          `${passing} bài đi ngang sẽ đổi mã trong app: ${shifted}.\n` +
          `Tiến độ người học chỉ lệch khi bạn phát hành, và file trong thư mục nội dung gốc chưa đổi cho tới lần xuất kế tiếp.`,
      )
    )
      return;
    setBusy(true);
    try {
      const result = await moveUnitDraft(courseId, unitId, to);
      if (result.ok) {
        toast.success(
          result.moved
            ? `Đã chuyển “${title || unitId}” sang vị trí ${to + 1} (${result.moved} bài đổi mã).`
            : 'Thứ tự không đổi.',
        );
        if (result.warning) toast.warning(result.warning);
        startRefresh(() => router.refresh());
      } else toast.error(result.message ?? 'Không chuyển được.');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không chuyển được.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center justify-end gap-1">
      <button
        type="button"
        className={ghost}
        onClick={() => move(position - 1)}
        disabled={locked || position === 0}
        aria-label={`Chuyển ${title || unitId} lên trên`}
      >
        ↑
      </button>
      <button
        type="button"
        className={ghost}
        onClick={() => move(position + 1)}
        disabled={locked || position >= total - 1}
        aria-label={`Chuyển ${title || unitId} xuống dưới`}
      >
        ↓
      </button>
    </div>
  );
}

export function BackToCourse({ courseId }: { courseId: string }) {
  return (
    <Link
      href={`/courses/${courseId}`}
      transitionTypes={['nav-back']}
      className="inline-block text-sm text-fg-3 hover:-translate-x-0.5 hover:text-primary-text"
    >
      ← Bài học
    </Link>
  );
}
