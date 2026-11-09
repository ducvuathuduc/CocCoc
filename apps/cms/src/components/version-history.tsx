'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { runLifecycle, type ContentVersionRow } from '@/server/actions/lifecycle';
import { button, danger, hint } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

const STATUS_VIEW: Record<ContentVersionRow['status'], { label: string; badge: string }> = {
  LIVE: { label: 'Đang live', badge: 'bg-ok-bg text-ok-fg ring-ok-bd' },
  SUPERSEDED: { label: 'Đã thay thế', badge: 'bg-elevated text-fg-3 ring-line' },
  RETIRED: { label: 'Đã nghỉ hưu', badge: 'bg-danger-bg text-danger-fg ring-danger-bd' },
};

/**
 * The editorial view of a course's publish history. Every row is one version; nothing is ever
 * deleted, so a retired or superseded version stays visible and clickable until the operator acts.
 * Actions call the real Learning lifecycle routes through the CMS server action; the CAS token is
 * the version we believe is live, so two editors cannot roll past each other.
 */
export function VersionHistory({
  courseId,
  versions,
  publishAllowed,
}: {
  courseId: string;
  versions: ContentVersionRow[];
  publishAllowed: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState<string | null>(null);

  const liveVersion = versions.find((v) => v.status === 'LIVE')?.versionId ?? null;

  async function act(
    key: string,
    action: 'unpublish' | 'retire' | 'rollback',
    versionId: string | null,
    confirm: string,
  ) {
    if (!window.confirm(confirm)) return;
    setBusy(key);
    try {
      const result = await runLifecycle(courseId, action, {
        versionId: versionId ?? undefined,
        expectedPublishedVersion: liveVersion,
      });
      if (!result.ok) {
        toast.error(result.message ?? 'Chưa thực hiện được.');
        return;
      }
      toast.success('Đã cập nhật trạng thái bản. Danh sách bên dưới đã làm mới.');
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Có lỗi xảy ra.');
    } finally {
      setBusy(null);
    }
  }

  if (versions.length === 0) {
    return (
      <p className={cn(hint, 'px-1')}>
        Khóa này chưa có bản nào được cho app nhận. Hãy chạy xuất bản ở trên trước.
      </p>
    );
  }

  return (
    <div className="space-y-2">
      <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line">
        {versions.map((v) => {
          const view = STATUS_VIEW[v.status];
          const isLive = v.status === 'LIVE';
          const isRetired = v.status === 'RETIRED';
          return (
            <li
              key={v.versionId}
              className="flex flex-wrap items-center gap-x-4 gap-y-2 bg-card px-4 py-3"
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-sm font-medium">{v.versionId}</span>
                  <span
                    className={cn(
                      'rounded-full px-2 py-0.5 text-xs font-medium ring-1',
                      view.badge,
                    )}
                  >
                    {view.label}
                  </span>
                </div>
                <p className="mt-0.5 text-xs text-fg-4">
                  {v.publishedAt
                    ? `Cho app nhận ${timeAgo(v.publishedAt)}`
                    : 'Chưa từng cho app nhận'}
                  {isRetired && v.retiredAt ? ` · nghỉ hưu ${timeAgo(v.retiredAt)}` : ''}
                </p>
              </div>

              <div className="ml-auto flex flex-wrap items-center gap-2">
                {isLive ? (
                  <button
                    type="button"
                    disabled={busy !== null || !publishAllowed}
                    onClick={() =>
                      act(
                        `unpublish-${v.versionId}`,
                        'unpublish',
                        null,
                        `Gỡ bản live sẽ làm khóa này biến mất khỏi app người học ngay.\nBản cũ không bị xóa.\n\nTiếp tục?`,
                      )
                    }
                    className={cn(danger, 'py-1.5')}
                  >
                    {busy === `unpublish-${v.versionId}` ? 'Đang gỡ…' : 'Gỡ bản live'}
                  </button>
                ) : (
                  <>
                    {!isRetired && (
                      <button
                        type="button"
                        disabled={busy !== null || !publishAllowed}
                        onClick={() =>
                          act(
                            `rollback-${v.versionId}`,
                            'rollback',
                            v.versionId,
                            `App sẽ dùng bản ${v.versionId} thay cho bản đang live.\nBản cũ không bị xóa.\n\nTiếp tục?`,
                          )
                        }
                        className={cn(button, 'py-1.5')}
                      >
                        {busy === `rollback-${v.versionId}` ? 'Đang quay lại…' : 'Quay lại bản này'}
                      </button>
                    )}
                    {!isRetired && (
                      <button
                        type="button"
                        disabled={busy !== null || !publishAllowed}
                        onClick={() =>
                          act(
                            `retire-${v.versionId}`,
                            'retire',
                            v.versionId,
                            `Nghỉ hưu bản ${v.versionId} nghĩa là bản này sẽ không bao giờ được cho app dùng lại${isLive ? ' và khóa sẽ bị gỡ khỏi app ngay' : ''}.\nHành động này không thể hoàn tác.\n\nTiếp tục?`,
                          )
                        }
                        className={cn(danger, 'py-1.5')}
                      >
                        {busy === `retire-${v.versionId}` ? 'Đang nghỉ hưu…' : 'Nghỉ hưu bản này'}
                      </button>
                    )}
                    {isRetired && <span className={cn(hint)}>Không thể dùng lại bản này.</span>}
                  </>
                )}
              </div>
            </li>
          );
        })}
      </ul>

      {!publishAllowed && (
        <p className={cn(hint)}>
          Các nút thay đổi thật bị khóa ở máy chủ. Nhờ người quản trị bật công tắc cho phép (
          <code className="rounded bg-elevated px-1 py-0.5">CMS_ALLOW_PUBLISH=1</code>) để mở.
        </p>
      )}
    </div>
  );
}
