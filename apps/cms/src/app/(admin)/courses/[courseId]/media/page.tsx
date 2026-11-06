import Link from 'next/link';
import { CourseTabs } from '@/components/course-tabs';
import { MediaUpload } from '@/components/media-upload';
import { PageTransition } from '@/components/page-transition';
import { TechDetails } from '@/components/tech-details';
import { audioTask, courseMediaReport, imageTask, type MediaGap } from '@/server/media-service';
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
  const audio = audioTask(report.gaps);
  const images = imageTask(report.gaps);
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

          <TechDetails title="Dành cho người chạy lệnh dựng">
            <p className="text-xs text-fg-3">
              Tên file chính là mã của nó: <code className={code}>a.u3.s7.n</code> là tiếng của câu 7
              trong bài 3, <code className={code}>i.u3.apple.webp</code> là ảnh quả táo, hậu tố{' '}
              <code className={code}>.n</code> là bản thường và <code className={code}>.s</code> là
              bản chậm.
            </p>
            <p className="text-xs text-fg-3">
              Danh sách này do CMS suy ra từ bản nháp đã lưu theo quy tắc đánh số của{' '}
              <code className={code}>build-course.mjs</code>, và khớp với những gì từng unit hiển
              thị. Bản máy đọc được:{' '}
              <a
                href={`/api/media/owed?course=${encodeURIComponent(courseId)}`}
                className={cn(link, 'font-mono text-xs')}
              >
                /api/media/owed?course={courseId}
              </a>
            </p>
            <p className="mt-2 text-xs text-fg-3">
              {totals.ready} đủ điều kiện dựng · {totals.missing} chưa có file ·{' '}
              {totals.unmanifested} clip đã có file nhưng{' '}
              <code className={code}>audio-manifest.json</code> chưa lấy được · {totals.drift} dòng
              có lời thoại trong nháp khác với catalog bản dựng · {totals.unused} ảnh có file nhưng
              không bài nào của bản dựng chở · {totals.picturesWithoutDrill} ảnh bài có chở nhưng
              chưa câu hỏi nào đố tới.
            </p>
            {audio.keys.length > 0 ? (
              <pre className="mt-2 overflow-x-auto rounded-lg bg-elevated p-3 text-xs text-fg-2">
                {`node tools/content/generate-audio.mjs --course ${courseId} --version ${report.version} --only ${audio.keys.join(',')}
node tools/content/generate-audio.mjs --check`}
              </pre>
            ) : (
              <p className="mt-2 text-xs text-fg-3">
                Mọi clip app cần đều đã nằm trong catalog và đã có manifest khớp.
              </p>
            )}
            {audio.needsBuild.length > 0 && (
              <p className={cn(warnBox, 'mt-2')}>
                {audio.needsBuild.length} key ({audio.needsBuild.slice(0, 5).join(', ')}
                {audio.needsBuild.length > 5 ? ', …' : ''}) do bản nháp mới thêm nên chưa có trong{' '}
                <code className={code}>dist/{report.version}/audio-catalog.json</code>.{' '}
                <code className={code}>generate-audio.mjs</code> chỉ đi theo catalog, nên phải chạy{' '}
                <code className={code}>
                  node tools/content/build-course.mjs --course {courseId}
                </code>{' '}
                trước thì các key này mới sinh được audio.
              </p>
            )}
            {audio.drift.length > 0 && (
              <p className={cn(warnBox, 'mt-2')}>
                {audio.drift.length} dòng ({audio.drift.slice(0, 5).join(', ')}
                {audio.drift.length > 5 ? ', …' : ''}) có catalog bản dựng ghi lời khác với bản nháp
                đã lưu — thường xảy ra sau khi sửa câu hoặc{' '}
                <Link href={`/courses/${courseId}`} className={link}>
                  đổi thứ tự bài
                </Link>
                , vì <code className={code}>generate-audio.mjs</code> thu âm theo catalog chớ không
                theo nháp. Chạy{' '}
                <code className={code}>
                  node tools/content/build-course.mjs --course {courseId}
                </code>{' '}
                để cập nhật catalog rồi thu âm lại những key này; khi đó chúng sẽ xuất hiện ở danh
                sách <code className={code}>--only</code> phía trên.
              </p>
            )}
            {report.unreadableBundles.length > 0 && (
              <p className={cn(warnBox, 'mt-2')}>
                {report.unreadableBundles.length} file trong{' '}
                <code className={code}>dist/{report.version}/bundles/</code> đọc được nhưng không có{' '}
                <code className={code}>unitId</code> hoặc <code className={code}>assets</code> (
                {report.unreadableBundles.slice(0, 5).join(', ')}
                {report.unreadableBundles.length > 5 ? ', …' : ''}). Clip từ vựng lấy từ chính những
                file này, nên danh sách trên có thể đang thiếu tài nguyên app thật sự cần — dựng lại
                khóa sẽ vá lại các bundle.
              </p>
            )}
            {totals.unused > 0 && (
              <p className={cn(warnBox, 'mt-2')}>
                {totals.unused} ảnh đã có file và đúng chuẩn nhưng không một bài tập nào của{' '}
                <code className={code}>dist/{report.version}/bundles/</code> chở (
                {report.units
                  .filter((u) => u.unused > 0)
                  .slice(0, 5)
                  .map((u) => `${u.genUnitId}: ${u.unused}`)
                  .join(', ')}
                {report.units.filter((u) => u.unused > 0).length > 5 ? ', …' : ''}). App chỉ hiện
                ảnh trong bài <code className={code}>imageChoice</code>, và{' '}
                <code className={code}>build-course.mjs:923</code> bỏ qua dạng bài này khi chưa có 4
                từ đánh dấu <code className={code}>img</code> được giới thiệu tới lúc dựng. Đây là
                việc của nội dung, không phải của kho media: thêm từ có ảnh rồi dựng lại, không cần
                tạo file nào cả.
              </p>
            )}
            {totals.picturesWithoutDrill > 0 && (
              <p className={cn(warnBox, 'mt-2')}>
                {totals.picturesWithoutDrill} ảnh đã vào được bài của{' '}
                <code className={code}>dist/{report.version}/bundles/</code> nhưng không một câu hỏi{' '}
                <code className={code}>imageChoice</code> nào đố tới, nên app không bao giờ đưa
                chúng lên màn hình (
                {report.units
                  .filter((u) => u.picturesWithoutDrill > 0)
                  .slice(0, 5)
                  .map((u) => `${u.genUnitId}: ${u.picturesWithoutDrill}/${u.image}`)
                  .join(', ')}
                {report.units.filter((u) => u.picturesWithoutDrill > 0).length > 5 ? ', …' : ''}).{' '}
                <code className={code}>build-course.mjs:918-925</code> đổi bài chọn ảnh sang bài
                chọn chữ khi chưa có 4 từ đánh dấu <code className={code}>img</code> được giới thiệu
                tới lúc dựng, và <code className={code}>:928-944</code> làm tương tự với lượt thoại.
                Mở panel từng unit để xem đúng những dạng bài bản dựng đã sinh cho unit đó.
              </p>
            )}
            {images.length > 0 && (
              <p className="mt-2 text-xs text-fg-3">
                {images.length} ảnh còn thiếu —{' '}
                <code className={code}>python3 tools/content/lesson_art</code> vẽ theo key, tên file
                phải đúng như <code className={code}>{images[0]}.webp</code> thì CMS mới nhận.
              </p>
            )}
          </TechDetails>
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
          <TechDetails title="Mã dựng của từng bài (cần khi chạy lệnh)">
            <ul className="space-y-0.5 font-mono text-xs text-fg-3">
              {report.units.map((summary) => (
                <li key={summary.unitId}>
                  {summary.unitId} → {summary.genUnitId}
                </li>
              ))}
            </ul>
          </TechDetails>
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
