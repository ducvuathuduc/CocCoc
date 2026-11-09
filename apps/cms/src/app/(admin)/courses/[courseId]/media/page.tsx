import Link from 'next/link';
import { CourseTabs } from '@/components/course-tabs';
import { MediaUpload } from '@/components/media-upload';
import { PageTransition } from '@/components/page-transition';
import { courseMediaReport, type MediaGap } from '@/server/media-service';
import { requireAdmin } from '@/server/session';
import { cn } from '@/lib/utils';
import { badge, card, code, link, row, td, th, warnBox } from '@/lib/ui';

export const instant = false;

const STATES = [
  { value: 'all', label: 'Tất cả' },
  { value: 'missing', label: 'Chưa có file' },
  { value: 'unmanifested', label: 'Có file, app chưa đọc được' },
  { value: 'drift', label: 'Lời thoại khác bản soạn' },
] as const;

/** Rendered ceiling: a course with every clip missing would otherwise paste 1 600 rows into one page. */
const LIST_LIMIT = 200;

const STATE_LABEL: Record<MediaGap['state'], string> = {
  missing: 'chưa có file',
  unmanifested: 'có file, app chưa đọc được',
  drift: 'lời thoại khác bản soạn',
};

function filters(state: string, unit: string): string {
  const query = new URLSearchParams();
  if (state !== 'all') query.set('state', state);
  if (unit) query.set('unit', unit);
  const encoded = query.toString();
  return encoded ? `?${encoded}` : '';
}

/** Counts are links, so the table answers "which lines?" without a second click through the unit page. */
function owedCell(courseId: string, unitId: string, count: number, state: MediaGap['state']) {
  return (
    <td className={cn(td, 'tabular-nums')}>
      {count > 0 ? (
        <Link
          href={`/courses/${courseId}/media?unit=${encodeURIComponent(unitId)}&state=${state}`}
          className="text-warn-fg hover:underline"
        >
          {count}
        </Link>
      ) : (
        <span className="text-fg-4">0</span>
      )}
    </td>
  );
}

function GapRow({ courseId, gap }: { courseId: string; gap: MediaGap }) {
  return (
    <tr className={cn(row, 'border-b border-line/60')}>
      <td className={td}>
        <Link
          href={`/courses/${courseId}/units/${gap.unitId}`}
          transitionTypes={['nav-forward']}
          className={link}
        >
          {gap.unitId}
        </Link>
      </td>
      <td className={cn(td, 'whitespace-nowrap')}>
        <code className={code}>
          {gap.fileId}
          {gap.kind === 'image' ? '.webp' : ''}
        </code>
        <div className="mt-0.5 text-[11px] text-fg-4">{gap.label}</div>
      </td>
      <td className={cn(td, 'max-w-[24rem] text-xs text-fg-3')}>
        {gap.text}
        {gap.drift && <div className="mt-0.5 text-[11px] text-warn-fg">bản soạn: {gap.draft}</div>}
      </td>
      <td className={td}>
        {gap.kind === 'audio' ? (
          <span className={badge}>{gap.speed === 0.75 ? 'Chậm' : 'Bình thường'}</span>
        ) : (
          <span className="text-xs text-fg-4">— ảnh</span>
        )}
      </td>
      <td className={td}>
        <span className={gap.state === 'missing' ? badge : undefined}>
          {STATE_LABEL[gap.state]}
        </span>
        {gap.kind === 'audio' && !gap.inCatalog && (
          <div className="mt-0.5 text-[11px] text-warn-fg">
            bản dựng chưa ghi nhận file này — dựng lại khóa là có
          </div>
        )}
      </td>
    </tr>
  );
}

export default async function CourseMediaPage({
  params,
  searchParams,
}: {
  params: Promise<{ courseId: string }>;
  searchParams: Promise<{ state?: string; unit?: string }>;
}) {
  const { courseId } = await params;
  const query = await searchParams;
  const state = (STATES.find((option) => option.value === query.state)?.value ?? 'all') as
    'all' | MediaGap['state'];
  const unit = query.unit ?? '';
  await requireAdmin();

  const report = await courseMediaReport(courseId);
  if (!report) {
    return (
      <PageTransition>
        <div className="space-y-4">
          <CourseTabs courseId={courseId} />
          <h1 className="text-2xl font-semibold tracking-tight">Âm thanh và ảnh của khóa</h1>
          <div className={cn(card, 'p-6 text-sm text-fg-3')}>
            Khóa này chưa có bài soạn nào, nên chưa biết app cần những file gì. Vào{' '}
            <Link href={`/courses/${courseId}`} className={link}>
              danh sách bài
            </Link>{' '}
            và soạn bài trước.
          </div>
        </div>
      </PageTransition>
    );
  }

  const gaps = report.gaps.filter(
    (gap) => (state === 'all' || gap.state === state) && (!unit || gap.unitId === unit),
  );
  const { totals } = report;

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <header>
          <CourseTabs courseId={courseId} />
          <h1 className="mt-4 text-2xl font-semibold tracking-tight">Âm thanh và ảnh của khóa</h1>
          <p className="mt-1 text-sm text-fg-3">
            App cần <b>{totals.total}</b> file cho <b>{report.units.length}</b> bài. Đã có{' '}
            <b className="text-ok-fg">{totals.ready}</b>, còn thiếu{' '}
            <b className={totals.missing ? 'text-warn-fg' : 'text-ok-fg'}>{totals.missing}</b>. Muốn
            nạp file, kéo xuống khung cuối trang; muốn biết bài nào thiếu gì, xem bảng{' '}
            <b>Từng bài</b>.
          </p>
        </header>

        <section className={cn(card, 'p-4')}>
          <h2 className="text-sm font-medium">Từng nhóm file cần làm gì</h2>
          <p className="mt-1 text-sm text-fg-3">
            Mỗi câu nói, mỗi từ và mỗi ảnh có một file riêng. Nạp file ở khung cuối trang, máy tự
            nhận ra từng file thuộc về bài nào và chỗ nào — không cần chọn bài thủ công.
          </p>
          <ul className="mt-2 space-y-1 text-sm text-fg-2">
            {totals.missing > 0 && (
              <li>
                <b>{totals.missing}</b> file chưa tồn tại: cần thu âm hoặc vẽ ảnh, rồi nạp lên đây.
              </li>
            )}
            {totals.unmanifested > 0 && (
              <li>
                <b>{totals.unmanifested}</b> file đã có nhưng app chưa đọc được — không phải tạo
                lại, chỉ cần dựng lại khóa là app ghi nhận.
              </li>
            )}
            {totals.drift > 0 && (
              <li>
                <b>{totals.drift}</b> câu đã sửa lời trong bản soạn, còn app vẫn phát lời cũ — dựng
                lại khóa rồi thu âm lại đúng những câu đó.
              </li>
            )}
            {totals.unused > 0 && (
              <li>
                <b>{totals.unused}</b> ảnh đang để không, chưa bài nào dùng — không hỏng gì, chỉ là
                công vẽ chưa được dùng tới.
              </li>
            )}
            {totals.picturesWithoutDrill > 0 && (
              <li>
                <b>{totals.picturesWithoutDrill}</b> ảnh đã vào bài nhưng chưa câu hỏi nào đố tới —
                muốn hiện trên màn hình thì thêm từ có ảnh vào bài đó rồi dựng lại.
              </li>
            )}
            {report.unreadableBundles.length > 0 && (
              <li>
                <b>{report.unreadableBundles.length}</b> tệp bài dựng đọc không được, nên danh sách
                thiếu ở đây có thể chưa đủ — dựng lại khóa sẽ vá lại.
              </li>
            )}
            {totals.missing +
              totals.unmanifested +
              totals.drift +
              totals.unused +
              totals.picturesWithoutDrill ===
              0 && (
              <li className="text-ok-fg">
                Đủ rồi — mọi file app cần đều đã có và app đọc được hết.
              </li>
            )}
          </ul>

        </section>

        <section className={cn(card, 'p-4')}>
          <h2 className="mb-1 text-sm font-medium">Từng bài</h2>
          <p className="mb-3 text-xs text-fg-4">
            Bấm vào số ở cột <b>Chưa có file</b> để xem đúng những file bài đó còn thiếu. Hai cột{' '}
            <b>Ảnh chưa bài nào dùng</b> và <b>Ảnh chưa câu nào hỏi</b> là file đã có sẵn — không cần
            nạp thêm gì, chỉ chưa được dùng tới.
          </p>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-xs text-fg-4">
                <tr>
                  <th className={th}>Bài</th>
                  <th className={th}>Cần bao nhiêu file</th>
                  <th className={th}>Chưa có file</th>
                  <th className={th}>App chưa đọc được</th>
                  <th className={th}>Lời khác bản soạn</th>
                  <th className={th}>Ảnh chưa bài nào dùng</th>
                  <th className={th}>Ảnh chưa câu nào hỏi</th>
                  <th className={th}>Đã đủ</th>
                </tr>
              </thead>
              <tbody>
                {report.units.map((summary) => (
                  <tr key={summary.unitId} className={cn(row, 'border-b border-line/60')}>
                    <td className={td}>
                      <Link
                        href={`/courses/${courseId}/units/${summary.unitId}`}
                        transitionTypes={['nav-forward']}
                        className={link}
                      >
                        {summary.title || '(bài chưa đặt tên)'}
                      </Link>
                      <div className="text-[11px] text-fg-4">{summary.unitId}</div>
                    </td>
                    <td className={cn(td, 'text-xs tabular-nums text-fg-3')}>
                      {summary.total} ({summary.audio} tiếng · {summary.image} ảnh)
                    </td>
                    {owedCell(courseId, summary.unitId, summary.missing, 'missing')}
                    {owedCell(courseId, summary.unitId, summary.unmanifested, 'unmanifested')}
                    {owedCell(courseId, summary.unitId, summary.drift, 'drift')}
                    <td
                      className={cn(
                        td,
                        'tabular-nums',
                        summary.unused > 0 ? 'text-warn-fg' : 'text-fg-4',
                      )}
                    >
                      {summary.unused}
                    </td>
                    <td
                      className={cn(
                        td,
                        'tabular-nums',
                        summary.picturesWithoutDrill > 0 ? 'text-warn-fg' : 'text-fg-4',
                      )}
                    >
                      {summary.picturesWithoutDrill}
                    </td>
                    <td className={cn(td, 'tabular-nums text-fg-3')}>{summary.ready}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className={cn(card, 'p-4')}>
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="mr-auto text-sm font-medium">
              {gaps.length} file đang xem · tổng {report.gaps.length}
            </h2>
            {STATES.map((option) => (
              <Link
                key={option.value}
                href={`/courses/${courseId}/media${filters(option.value, unit)}`}
                className={cn(badge, state === option.value && 'bg-primary text-primary-fg')}
              >
                {option.label}
              </Link>
            ))}
            {unit && (
              <Link href={`/courses/${courseId}/media${filters(state, '')}`} className={badge}>
                bỏ lọc bài {unit}
              </Link>
            )}
          </div>
          {gaps.length === 0 ? (
            <p className="mt-3 text-sm text-fg-3">
              Không còn file nào ở tình trạng này — bản dựng kế tiếp sẽ lấy file thật cho mọi tài
              nguyên đang lọc.
            </p>
          ) : (
            <>
              <div className="mt-3 overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="text-left text-xs text-fg-4">
                    <tr>
                      <th className={th}>Bài</th>
                      <th className={th}>Tên file cần có</th>
                      <th className={th}>App phát / hiển thị gì</th>
                      <th className={th}>Tốc độ đọc</th>
                      <th className={th}>Tình trạng</th>
                    </tr>
                  </thead>
                  <tbody>
                    {gaps.slice(0, LIST_LIMIT).map((gap) => (
                      <GapRow key={gap.fileId} courseId={courseId} gap={gap} />
                    ))}
                  </tbody>
                </table>
              </div>
              {gaps.length > LIST_LIMIT && (
                <p className={cn(warnBox, 'mt-3')}>
                  Đang hiển thị {LIST_LIMIT}/{gaps.length} file. Danh sách đầy đủ cho máy đọc:{' '}
                  <code className={code}>/api/media/owed?course={courseId}</code>
                </p>
              )}
            </>
          )}
          <h3 className="mt-5 text-sm font-medium">Nạp âm thanh và ảnh</h3>
          <MediaUpload courseId={courseId} scope="course" />
        </section>
      </div>
    </PageTransition>
  );
}

export function generateMetadata({ params }: { params: Promise<{ courseId: string }> }) {
  return params.then(() => ({ title: 'Âm thanh và ảnh của khóa' }));
}
