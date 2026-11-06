'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { setLearnerAccess } from '@/server/actions/users';
import { big, button, hint, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * The only change this screen can make to a learner: the account status on Appwrite Auth. Locking is
 * reversible from the same button, so the screen does not ask for a confirmation — it says in plain
 * words what will stop working.
 */
export function LearnerAccessButton({
  userId,
  locked,
  isSiteAdmin,
}: {
  userId: string;
  locked: boolean;
  isSiteAdmin: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const willLock = !locked;

  async function run() {
    setBusy(true);
    try {
      const result = await setLearnerAccess(userId, willLock);
      if (!result.ok) {
        toast.error(result.message ?? 'Không đổi được quyền truy cập của tài khoản này.');
        return;
      }
      if (result.unchanged)
        toast.message(willLock ? 'Tài khoản đã bị khóa trước đó.' : 'Tài khoản đang mở sẵn.');
      else
        toast.success(
          willLock
            ? 'Đã khóa: app sẽ không đăng nhập được bằng tài khoản này nữa.'
            : 'Đã mở lại: người học đăng nhập bình thường.',
        );
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không đổi được quyền truy cập.');
    } finally {
      setBusy(false);
    }
  }

  if (isSiteAdmin)
    return (
      <p className={cn(hint, 'max-w-md')}>
        Tài khoản này nằm trong danh sách được vào CMS, nên không có khóa ở đây: khóa nó là mất luôn
        quyền soạn bài.
      </p>
    );

  return (
    <div className="space-y-2">
      <button
        type="button"
        onClick={run}
        disabled={busy}
        className={cn(
          willLock ? button : primary,
          big,
          willLock && 'border border-danger-fg/40 text-danger-fg hover:bg-danger-bg',
        )}
      >
        {busy ? 'Đang đổi…' : willLock ? 'Khóa tài khoản' : 'Mở khóa tài khoản'}
      </button>
      <p className={cn(hint, 'max-w-md')}>
        Khóa chỉ ngăn đăng nhập. Bài đã học, điểm và dữ liệu của người này vẫn nguyên; mở khóa thì mọi
        thứ trở lại.
      </p>
    </div>
  );
}
