'use client';

import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { uploadMedia } from '@/server/actions/media';
import { TechDetails } from '@/components/tech-details';
import { code, field, primary, warnBox } from '@/lib/ui';
import { cn } from '@/lib/utils';

/** `experimental.serverActions.bodySizeLimit` is 10 MB, and multipart adds a little per part. */
const BATCH_BYTES = 8 * 1024 * 1024;

/** Keeps one action request under the body limit without asking the admin to split folders by hand. */
function batches(files: File[]): File[][] {
  const out: File[][] = [];
  let current: File[] = [];
  let bytes = 0;
  for (const file of files) {
    if (current.length && bytes + file.size > BATCH_BYTES) {
      out.push(current);
      current = [];
      bytes = 0;
    }
    current.push(file);
    bytes += file.size;
  }
  if (current.length) out.push(current);
  return out;
}

const summary = (saved: number, rejected: number): string =>
  rejected === 0
    ? `Đã nạp ${saved} file vào kho media.`
    : saved === 0
      ? `${rejected} file bị từ chối, chưa ghi file nào.`
      : `Đã nạp ${saved} file, ${rejected} file bị từ chối.`;

/**
 * Fills the gaps the panel lists: drop the clips and pictures a generator produced, named exactly as the
 * keys below. The file's own name chooses the slot, so a folder from `generate-audio.mjs` can be loaded
 * in one go; every refusal is listed with its reason instead of silently skipping the file.
 */
export function MediaUpload({
  courseId,
  scope = 'unit',
}: {
  courseId: string;
  scope?: 'unit' | 'course';
}) {
  const router = useRouter();
  const input = useRef<HTMLInputElement>(null);
  const overwrite = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState('');
  const [rejected, setRejected] = useState<{ name: string; message: string }[]>([]);
  const [refreshing, startRefresh] = useTransition();

  async function submit() {
    const picked = [...(input.current?.files ?? [])];
    if (!picked.length) {
      toast.error('Chưa chọn file nào.');
      return;
    }
    if (
      overwrite.current?.checked &&
      !window.confirm(
        `Bạn sắp nạp ${picked.length} file và cho phép ghi đè. File cùng tên đang có trong kho sẽ bị thay bằng file mới và không khôi phục được. Tiếp tục?`,
      )
    )
      return;
    setBusy(true);
    setRejected([]);
    let savedCount = 0;
    let rejectedCount = 0;
    try {
      for (const batch of batches(picked)) {
        setProgress(
          `Đang nạp ${savedCount + rejectedCount + 1}–${savedCount + rejectedCount + batch.length}/${picked.length}…`,
        );
        const data = new FormData();
        for (const file of batch) data.append('files', file, file.name);
        if (overwrite.current?.checked) data.append('overwrite', '1');
        const result = await uploadMedia(courseId, data);
        savedCount += result.saved.length;
        rejectedCount += result.rejected.length;
        if (result.rejected.length) setRejected((previous) => [...previous, ...result.rejected]);
        if (result.message) {
          toast.error(result.message);
          return;
        }
        if (result.warning) toast.warning(result.warning);
      }
      if (rejectedCount) toast.warning(summary(savedCount, rejectedCount));
      else toast.success(summary(savedCount, rejectedCount));
      if (savedCount) startRefresh(() => router.refresh());
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không nạp được file.');
    } finally {
      setBusy(false);
      setProgress('');
      if (input.current) input.current.value = '';
    }
  }

  return (
    <div className="mt-3">
      <div className="flex flex-wrap items-center gap-2">
        <input
          ref={input}
          type="file"
          multiple
          accept=".aac,.webp,audio/aac,image/webp"
          className={cn(field, 'max-w-full text-xs')}
          aria-label={
            scope === 'unit'
              ? 'Chọn file âm thanh hoặc ảnh cho bài này'
              : 'Chọn file âm thanh hoặc ảnh cho khóa này'
          }
        />
        <label className="flex items-center gap-1.5 text-xs text-fg-3">
          <input ref={overwrite} type="checkbox" className="size-4 accent-primary" /> cho phép thay
          file đã có trong kho
        </label>
        <button
          type="button"
          className={cn(primary, 'h-8 shrink-0 px-3 text-xs')}
          onClick={submit}
          disabled={busy || refreshing}
        >
          {busy ? progress || 'Đang nạp…' : 'Nạp âm thanh và ảnh'}
        </button>
      </div>
      <p className={cn('mt-1 text-xs leading-relaxed text-fg-4')}>
        Máy tự nhận mỗi file thuộc về câu, từ hay ảnh nào, nên không cần chọn bài thủ công. File sai
        tên, sai định dạng, quá dung lượng hoặc không thuộc danh sách cần đều bị từ chối kèm lý do,
        không ghi âm thầm.
      </p>
      <TechDetails title="Quy ước tên file">
        <p className="text-xs text-fg-3">
          <code className={code}>a.u3.s7.n.aac</code> là tiếng của câu 7 trong bài 3,{' '}
          <code className={code}>i.u3.apple.webp</code> là ảnh của từ apple. Hậu tố{' '}
          <code className={code}>.n</code> là bản thường, <code className={code}>.s</code> là bản
          chậm. Tên chính là địa chỉ: máy không đoán, nên file ngoài danh sách cần bị từ chối.
        </p>
      </TechDetails>
      {rejected.length > 0 && (
        <ul className={cn(warnBox, 'mt-2 space-y-1 text-xs')}>
          {rejected.map((item) => (
            <li key={item.name}>
              <code className={code}>{item.name}</code> — {item.message}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
