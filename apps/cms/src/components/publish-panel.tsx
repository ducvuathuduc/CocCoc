'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { TechDetails } from '@/components/tech-details';
import { publishCourseVersion } from '@/server/actions/publish';
import type { PublishReadiness } from '@/server/publish-state';
import type { BuildRun } from '@/cms/types';
import { button, card, hint, link, log, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

const OUTCOME: Record<string, string> = {
  SUCCEEDED: 'Đã xong',
  FAILED: 'Có lỗi',
  RUNNING: 'Đang chạy',
};

export function PublishPanel({
  courseId,
  readiness,
  appwriteMode,
  publishAllowed,
}: {
  courseId: string;
  readiness: PublishReadiness;
  appwriteMode: boolean;
  publishAllowed: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [armed, setArmed] = useState(false);
  const [last, setLast] = useState<BuildRun | null>(null);

  const blocked = !readiness.gatesOk;
  const canDryRun = !busy && !blocked && appwriteMode;
  const canPublish = !busy && !blocked && appwriteMode && publishAllowed;

  async function publish(live: boolean) {
    setBusy(true);
    setArmed(false);
    try {
      const result = await publishCourseVersion(courseId, live);
      if (result.run) setLast(result.run);
      if (result.ok)
        toast.success(
          result.run?.message ??
            (live ? 'Đã xuất bản. Người học sẽ nhận bản này.' : 'Chạy thử xong, chưa xuất bản.'),
        );
      else toast.error(result.message ?? 'Chưa xuất bản được.');
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không gọi được máy chủ.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className={cn(card, 'p-4')}>
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-sm font-medium">Xuất bản nội dung</h2>
        <span
          className={cn(
            'rounded-full px-2 py-0.5 text-xs font-medium ring-1',
            readiness.gatesOk
              ? 'bg-ok-bg text-ok-fg ring-ok-bd'
              : 'bg-warn-bg text-warn-fg ring-warn-bd',
          )}
        >
          {readiness.gatesOk ? 'Bài đã qua kiểm tra' : 'Bài chưa qua kiểm tra'}
        </span>
      </div>

      <p className="mt-1 text-sm text-fg-3">
        Khóa này có {readiness.unitCount} bài học.{' '}
        {readiness.gatesOk ? 'Bản vừa kiểm tra đã sẵn sàng để xuất bản.' : readiness.blocking}
      </p>
      <p className="mt-1 text-xs">
        <Link href={`/courses/${courseId}/readiness`} className={link}>
          {readiness.gatesOk
            ? 'Xem các điều kiện xuất bản'
            : 'Xem những gì cần xử lý trước khi xuất bản'}
        </Link>
      </p>

      <div className="mt-4 flex flex-wrap items-center gap-2">
        <button
          type="button"
          disabled={!canDryRun}
          onClick={() => publish(false)}
          className={cn(button, 'py-1.5')}
        >
          {busy ? 'Đang chạy…' : 'Chạy thử (không xuất bản)'}
        </button>

        {!armed ? (
          <button
            type="button"
            disabled={!canPublish}
            onClick={() => setArmed(true)}
            className={cn(primary, 'py-1.5')}
          >
            Xuất bản nội dung
          </button>
        ) : (
          <div className="w-full animate-fade-up rounded-xl border border-danger-bd bg-danger-bg px-4 py-3">
            <p className="text-sm font-medium text-danger-fg">
              Bản này sẽ được đưa đến người học đang dùng app.
            </p>
            <p className="mt-1 text-sm text-danger-fg">
              App sẽ dùng {readiness.unitCount} bài học của bản này cho tới lần xuất bản sau. Bản cũ
              không bị xóa.
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                disabled={!canPublish}
                onClick={() => publish(true)}
                className={cn(primary, 'py-1.5')}
              >
                Xuất bản ngay
              </button>
              <button
                type="button"
                onClick={() => setArmed(false)}
                className={cn(button, 'py-1.5')}
              >
                Quay lại
              </button>
            </div>
          </div>
        )}

        {blocked && (
          <p className={cn(hint, 'w-full')}>
            Hai nút trên chỉ mở sau khi khóa vượt qua bước kiểm tra tự động ở trên.
          </p>
        )}
        {!blocked && !appwriteMode && (
          <p className={cn(hint, 'w-full')}>
            Bản soạn đang lưu trên máy này, chưa nối máy chủ dùng chung, nên chưa xuất bản được.
          </p>
        )}
        {!blocked && appwriteMode && !publishAllowed && (
          <p className={cn(hint, 'w-full')}>
            Chức năng xuất bản đang bị khóa ở máy chủ. Nhờ người quản trị bật công tắc cho phép.
          </p>
        )}
        {!blocked && appwriteMode && publishAllowed && !armed && (
          <p className={cn(hint, 'w-full')}>
            Nút bên trên thay đổi thật. Muốn an toàn thì bấm “Chạy thử” trước — chạy thử không ghi
            gì lên máy chủ.
          </p>
        )}
      </div>

      <TechDetails title="Dành cho người quản trị máy chủ" className="mt-3">
        <p>
          Khóa <code className="font-mono">{courseId}</code>, bản{' '}
          <code className="font-mono">{readiness.version}</code>. Trạng thái “đã qua kiểm tra” nghĩa
          là lần chạy <code className="font-mono">build-course</code> +{' '}
          <code className="font-mono">lint-course</code> +{' '}
          <code className="font-mono">check-content</code> gần nhất thành công và diễn ra sau lần
          sửa nháp cuối.
        </p>
        <p>
          “Xuất bản” = <code className="font-mono">publish</code>: upload bundle ở{' '}
          <code className="font-mono">
            content/{'{courseId}'}/dist/{'{version}'}
          </code>{' '}
          lên Appwrite rồi chuyển con trỏ bản publish của khóa. “Chạy thử” ={' '}
          <code className="font-mono">dryRun</code>, không ghi gì. Nút thật cần{' '}
          <code className="font-mono">CMS_ALLOW_PUBLISH=1</code> và máy chủ chạy ở chế độ Appwrite (
          <code className="font-mono">CMS_MODE=appwrite</code>); ở chế độ file thì cả hai nút tắt.
        </p>
      </TechDetails>

      {last && (
        <details className="mt-3 animate-fade-up" open={last.status === 'FAILED'}>
          <summary className="cursor-pointer text-xs text-fg-4 hover:text-primary-text">
            {OUTCOME[last.status] ?? 'Máy đã chạy'} · xem chi tiết ({last.log.length} dòng)
          </summary>
          <pre className={cn(log, 'mt-2 max-h-72 overflow-auto')}>{last.log.join('\n')}</pre>
        </details>
      )}
    </section>
  );
}
