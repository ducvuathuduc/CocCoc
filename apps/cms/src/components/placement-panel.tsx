import Link from 'next/link';
import { TechDetails } from '@/components/tech-details';
import { placementReport } from '@/server/placement-service';
import { badge, card, code, link, td, th, warnBox } from '@/lib/ui';
import { cn } from '@/lib/utils';

const cut = (text: string, max: number): string =>
  text.length > max ? `${text.slice(0, max - 1)}…` : text;

/**
 * The placement test has no editor: `build-course.mjs:1005-1028` picks ten rows by position out of the
 * first unit. This panel is the CMS' only view of it — what the test will ask, and what the shipped app
 * already asks.
 */
export async function PlacementPanel({ courseId }: { courseId: string }) {
  const report = await placementReport(courseId);
  if (!report) return null;

  const blockers = report.rows.filter((r) => !r.item.present);
  const changed = report.rows.filter((r) => r.state === 'changed');
  const notes = report.rows.filter((r) => r.item.note);

  return (
    <section className={cn(card, 'p-4')}>
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="text-sm font-medium">Bài kiểm tra trình độ</h2>
        <span className="text-xs text-fg-4">
          {report.counts.vocab} từ · {report.counts.sentences} câu · {report.counts.questions} câu
          hỏi truyện · {report.counts.pictures} từ có ảnh
        </span>
      </div>
      <p className="mt-1 text-xs text-fg-4">
        Cả 10 câu lấy theo <span className="font-medium text-fg-3">vị trí</span> trong bài mở màn —{' '}
        <Link
          href={`/courses/${courseId}/units/${report.unitId}`}
          transitionTypes={['nav-forward']}
          className={cn(link, 'font-medium')}
        >
          {report.unitTitle || '(chưa đặt tên)'}
        </Link>{' '}
        (bài 1). Xóa hay đổi chỗ một dòng trong bài đó là viết lại bài kiểm tra; rút ngắn bài thì máy
        dựng dừng giữa chừng.
        {report.guideText && (
          <>
            {' '}App đang hẹn với người học: <i>“{report.guideText}”</i>.
          </>
        )}
      </p>

      {blockers.length > 0 && (
        <div
          role="alert"
          className="mt-3 rounded-xl border border-danger-bd bg-danger-bg px-4 py-3 text-sm text-danger-fg"
        >
          <p className="font-medium">
            {blockers.length} câu đang hỏi một nội dung không còn trong bài (
            {blockers.map((r) => r.item.id).join(', ')}).
          </p>
          <ul className="mt-1 space-y-1 text-xs">
            {blockers.map(({ item }) => (
              <li key={item.id}>
                Câu {item.item} ({item.question}) cần{' '}
                {item.reads.picturesOnly
                  ? `từ có ảnh thứ ${item.reads.index + 1}`
                  : `${item.reads.listLabel} dòng ${item.reads.index + 1} (cần ${item.reads.needed})`}
                , nhưng bài không còn đủ dòng.
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs">
            Thêm lại dòng đó, hoặc chấp nhận rằng bài kiểm tra đang hỏi một nội dung không còn tồn
            tại.
          </p>
        </div>
      )}

      {changed.length > 0 && (
        <div className={cn(warnBox, 'mt-3')}>
          <p className="font-medium">
            {changed.length} câu bản dựng đang hỏi khác bản nháp —{' '}
            {changed.map((r) => r.item.id).join(', ')}.
          </p>
          <ul className="mt-1 space-y-1 text-xs">
            {changed.map(({ item, built }) => (
              <li key={item.id}>
                Câu {item.item}: nháp nay đọc {item.label}, app đang hỏi «{' '}
                {cut(built?.prompt ?? '', 90)}».
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs">
            Chạy <span className={code}>node tools/content/build-course.mjs vi_en</span> để bài kiểm
            tra trong app theo kịp bản nháp.
          </p>
        </div>
      )}

      {notes.length > 0 && (
        <p className={cn(warnBox, 'mt-3')}>
          {notes.map(({ item }) => `Câu ${item.item}: ${item.note}`).join(' ')}
        </p>
      )}

      <TechDetails
        title="Bảng 10 câu (dành cho người chạy lệnh dựng)"
        className="mt-3 bg-transparent"
      >
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-elevated text-left text-xs text-fg-4">
              <tr>
                <th className={th}>#</th>
                <th className={th}>Câu hỏi</th>
                <th className={th}>Đọc dòng nào của {report.genUnitId}</th>
                <th className={th}>App đang hỏi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {report.rows.map(({ item, built, state }) => (
                <tr key={item.id} className="align-top transition-colors hover:bg-elevated">
                  <td className={cn(td, 'font-mono text-xs tabular-nums text-fg-4')}>
                    {item.item}
                  </td>
                  <td className={td}>
                    {item.question}
                    <div>
                      <span className={cn(badge, 'font-mono text-[11px]')}>{item.drill}</span>
                    </div>
                  </td>
                  <td className={td}>
                    <span className="text-xs text-fg-3">
                      {item.reads.picturesOnly
                        ? `từ có ảnh thứ ${item.reads.index + 1}`
                        : `${item.reads.listLabel} dòng ${item.reads.index + 1}`}
                    </span>
                    <div
                      className={cn(
                        'text-xs',
                        item.present ? 'text-fg-2' : 'font-medium text-danger-fg',
                      )}
                    >
                      {item.present ? cut(item.label, 90) : `hết dòng — cần ${item.reads.needed}`}
                    </div>
                    {item.vocabularyIds.length > 0 && (
                      <div className="font-mono text-[11px] text-fg-4">
                        {item.vocabularyIds.map((id) => cut(id, 24)).join(', ')}
                      </div>
                    )}
                  </td>
                  <td className={td}>
                    {!item.present ? (
                      <span className="text-xs font-medium text-danger-fg">
                        hết dòng để đọc — không còn gì để so
                      </span>
                    ) : !report.hasBuild ? (
                      <span className="text-xs text-fg-4">chưa có bản dựng để so</span>
                    ) : state === 'unknown' ? (
                      <span className="text-xs text-fg-4">bản dựng không có câu này</span>
                    ) : (
                      <>
                        <div className="text-xs text-fg-2">{cut(built?.prompt ?? '', 90)}</div>
                        <div
                          className={cn(
                            'text-[11px]',
                            state === 'same' ? 'text-fg-4' : 'font-medium text-warn-fg',
                          )}
                        >
                          {state === 'same'
                            ? 'khớp bản nháp'
                            : `khác bản nháp (build: ${built?.type ?? '?'})`}
                        </div>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </TechDetails>
    </section>
  );
}
