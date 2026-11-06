import { PageTransition } from '@/components/page-transition';
import { TechDetails } from '@/components/tech-details';
import { config } from '@/server/config';
import { requireAdmin } from '@/server/session';
import { cn } from '@/lib/utils';
import { badge, card, code } from '@/lib/ui';

export const instant = false;

export default async function AccessPage() {
  const identity = await requireAdmin();
  const c = config();

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Thành viên &amp; Quyền truy cập</h1>
          <p className="mt-1 text-sm text-fg-3">
            Chỉ những tài khoản dưới đây mở được nơi soạn bài. Thêm hay bớt người là việc của người
            quản trị máy chủ — trang này chỉ để xem.
          </p>
        </header>

        <section className={cn(card, 'p-4')}>
          <h2 className="text-sm font-medium">Bạn đang đăng nhập bằng</h2>
          <dl className="mt-2 space-y-1.5 text-sm">
            <div className="flex gap-2">
              <dt className="w-44 shrink-0 text-fg-4">Mã tài khoản</dt>
              <dd className="font-mono text-fg">{identity.userId}</dd>
            </div>
            <div className="flex gap-2">
              <dt className="w-44 shrink-0 text-fg-4">Email</dt>
              <dd className="text-fg">{identity.email}</dd>
            </div>
            <div className="flex gap-2">
              <dt className="w-44 shrink-0 text-fg-4">Bài soạn đang lưu ở</dt>
              <dd className="text-fg">
                {c.mode === 'appwrite'
                  ? 'máy chủ dùng chung (Appwrite)'
                  : 'một tệp trên máy này — chỉ là máy thử việc'}
              </dd>
            </div>
          </dl>
        </section>

        <section className={cn(card, 'p-4')}>
          <h2 className="text-sm font-medium">Danh sách được vào soạn bài</h2>
          {c.admins.size === 0 ? (
            <p className="mt-2 text-sm text-warn-fg">
              Danh sách đang trống — không tài khoản nào được vào soạn bài. Nhờ người quản trị máy
              chủ thêm tài khoản vào danh sách.
            </p>
          ) : (
            <ul className="mt-2 flex flex-wrap gap-1.5">
              {[...c.admins].map((id) => (
                <li key={id} className={cn(badge, 'font-mono')}>
                  {id}
                </li>
              ))}
            </ul>
          )}
          <TechDetails title="Dành cho người quản trị máy chủ">
            <p className="text-xs text-fg-3">
              Danh sách lấy từ biến môi trường <code className={code}>CMS_ADMIN_USER_IDS</code>{' '}
              (phân cách bằng dấu phẩy) — chính là các <code className={code}>userId</code> hiển thị
              phía trên. Tài khoản người học và các service API thuộc Appwrite Auth, không nằm trong
              phạm vi sửa của trang này.
            </p>
          </TechDetails>
        </section>
      </div>
    </PageTransition>
  );
}
