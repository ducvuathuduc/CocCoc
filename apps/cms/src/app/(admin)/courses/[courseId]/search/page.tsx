import Link from 'next/link';
import { CourseTabs } from '@/components/course-tabs';
import { PageTransition } from '@/components/page-transition';
import { ReplacePanel } from '@/components/replace-panel';
import { replaceColumns, type ReplaceTarget } from '@/cms/replace';
import type { SearchList } from '@/cms/search';
import { courseSearch, type CourseSearchReport } from '@/server/content-search';
import { previewReplace } from '@/server/content-replace';
import type { SearchHit } from '@/cms/search';
import { requireAdmin } from '@/server/session';
import { cn } from '@/lib/utils';
import { card, compact, field, link, primary, td, th } from '@/lib/ui';

export const instant = false;

/** How many duplicate groups the screen lists before pointing at the number instead. */
const GROUP_LIMIT = 40;

/**
 * The panel keeps its checkboxes in the URL (`cols=vocab.từ,…`) so a reload or a shared link shows the
 * same preview. No `cols` means every column the module may rewrite.
 */
function parseCols(cols: string): ReplaceTarget[] {
  const picked = cols
    .split(',')
    .map((entry) => {
      const dot = entry.indexOf('.');
      return dot < 0
        ? null
        : { list: entry.slice(0, dot) as SearchList, field: entry.slice(dot + 1) };
    })
    .filter((t): t is ReplaceTarget => !!t && !!t.field);
  if (picked.length) return picked;
  return replaceColumns()
    .filter((c) => c.editable)
    .map((c) => ({ list: c.list, field: c.field }));
}

export default async function CourseSearchPage({
  params,
  searchParams,
}: {
  params: Promise<{ courseId: string }>;
  searchParams: Promise<{ q?: string; find?: string; to?: string; cols?: string }>;
}) {
  const { courseId } = await params;
  const { q = '', find = '', to = '', cols = '' } = await searchParams;
  await requireAdmin();
  const report = await courseSearch(courseId, q);
  const preview = find.trim()
    ? await previewReplace(courseId, { find, to, targets: parseCols(cols) })
    : null;

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          <CourseTabs courseId={courseId} />
          <h1 className="mt-4 text-2xl font-semibold tracking-tight">Tìm một từ trong khóa</h1>
          <p className="mt-1 max-w-3xl text-sm text-fg-3">
            Tìm trong bài bạn đang soạn ở đây ({report?.unitCount ?? 0} bài). Không cần gõ đúng dấu
            hay viết hoa: <span className="font-mono">chao hoi</span> vẫn ra{' '}
            <span className="font-mono">Chào hỏi</span>. Đây là bản đang sửa, chưa phải bản app đang
            chạy.
          </p>
        </header>

        <form action={`/courses/${courseId}/search`} method="get" className="flex gap-2">
          <input
            name="q"
            defaultValue={q}
            className={cn(field, 'max-w-md')}
            placeholder="apple, xin lỗi, How are you…"
            aria-label="Nội dung cần tìm"
          />
          <button type="submit" className={primary}>
            Tìm
          </button>
          {q && (
            <Link
              href={`/courses/${courseId}/search?find=${encodeURIComponent(q)}`}
              transitionTypes={['nav-forward']}
              className={cn(compact, 'self-center px-3 text-sm')}
            >
              Thay thế “{q}”
            </Link>
          )}
          {q && (
            <Link
              href={`/courses/${courseId}/search`}
              transitionTypes={['nav-back']}
              className={cn(compact, 'self-center px-3 text-sm text-fg-3 hover:text-fg')}
            >
              Xóa
            </Link>
          )}
        </form>

        {!report && (
          <div className={cn(card, 'p-6 text-sm text-fg-3')}>
            Khóa này chưa có bài nào để tìm. Hãy soạn bài trước.
          </div>
        )}

        {preview && <ReplacePanel preview={preview} />}

        {report && (
          <>
            {q ? (
              <Hits report={report} />
            ) : (
              <p className="text-sm text-fg-3">
                Ô tìm trống: bên dưới là những chỗ nội dung lặp lại, thứ mà tìm từng từ không bao
                giờ chỉ ra.
              </p>
            )}
            <Repeats report={report} />
          </>
        )}
      </div>
    </PageTransition>
  );
}

function Hits({ report }: { report: CourseSearchReport }) {
  if (report.hits.length === 0) {
    return (
      <section className={cn(card, 'p-4 text-sm text-fg-2')}>
        Không có dòng nào trong {report.entryCount} dòng chữ của khóa khớp “{report.query}”. Thử bỏ
        dấu, hoặc tìm một từ trong câu thay vì cả câu.
      </section>
    );
  }
  return (
    <section className={cn(card, 'overflow-x-auto p-4')}>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <h2 className="font-medium">{report.hits.length} kết quả</h2>
        <span className="text-xs text-fg-4">
          trong {report.entryCount} dòng chữ của {report.unitCount} bài học
        </span>
        {report.truncated && (
          <span className="rounded-full bg-warn-bg px-2 py-0.5 text-xs font-medium text-warn-fg">
            chỉ hiện {report.limit} đầu — tìm cụ thể hơn
          </span>
        )}
      </div>
      <table className="mt-3 w-full text-sm">
        <thead>
          <tr>
            <th className={th}>Bài học</th>
            <th className={th}>Ở đâu</th>
            <th className={th}>Nội dung</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-line">
          {report.hits.map((hit, n) => (
            <tr key={`${hit.unitId}-${hit.tab}-${hit.row}-${hit.field}-${n}`} className="align-top">
              <td className={cn(td, 'whitespace-nowrap')}>
                <UnitLink courseId={report.courseId} hit={hit} />
              </td>
              <td className={cn(td, 'whitespace-nowrap text-xs text-fg-3')}>
                {hit.listLabel} · {hit.row === null ? 'thông tin chung' : `dòng ${hit.row + 1}`} ·{' '}
                {hit.field}
              </td>
              <td className={td}>
                <Marked hit={hit} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function UnitLink({ courseId, hit }: { courseId: string; hit: SearchHit }) {
  const row = hit.row === null ? '' : `&row=${hit.row}`;
  return (
    <Link
      href={`/courses/${courseId}/units/${hit.unitId}?tab=${hit.tab}${row}`}
      transitionTypes={['nav-forward']}
      className={cn(link, 'text-sm font-medium')}
    >
      Bài {hit.order + 1}: {hit.unitTitle || hit.unitId}
    </Link>
  );
}

function Marked({ hit }: { hit: SearchHit }) {
  return (
    <span className="break-words">
      {hit.text.slice(0, hit.start)}
      <mark className="rounded bg-primary-soft px-0.5 text-primary-text">
        {hit.text.slice(hit.start, hit.end)}
      </mark>
      {hit.text.slice(hit.end)}
    </span>
  );
}

function Repeats({ report }: { report: CourseSearchReport }) {
  const blocks = [
    {
      title: 'Từ vựng dạy ở nhiều nơi',
      groups: report.words,
      note: 'Cùng một từ xuất hiện ở hơn một dòng. Không sai — app sẽ giới thiệu lại — nhưng nếu hai bài cùng dạy một nghĩa thì một trong hai là thừa.',
    },
    {
      title: 'Một từ lặp lại trong cùng một bài',
      groups: report.insideUnit,
      note: 'Hai dòng cùng một từ trong chính bài đó. Bản soạn mới không lưu được như vậy nữa, nên đây là những bài lưu từ trước khi có bước kiểm tra.',
    },
    {
      title: 'Câu lặp lại',
      groups: report.sentences,
      note: 'Cùng một câu tiếng Anh ở nhiều nơi — thường là lúc sửa câu mà quên xóa bản cũ.',
    },
  ];
  return (
    <div className="space-y-4">
      {blocks.map((block) => (
        <section key={block.title} className={cn(card, 'p-4')}>
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-sm font-medium">{block.title}</h2>
            <span
              className={cn(
                'rounded-full px-2 py-0.5 text-xs font-medium tabular-nums',
                block.groups.length ? 'bg-warn-bg text-warn-fg' : 'bg-ok-bg text-ok-fg',
              )}
            >
              {block.groups.length ? `${block.groups.length} nhóm` : 'không có'}
            </span>
          </div>
          <p className="mt-1 text-xs text-fg-4">{block.note}</p>
          {block.groups.length > 0 && (
            <ul className="mt-3 space-y-2">
              {block.groups.slice(0, GROUP_LIMIT).map((group) => (
                <li key={`${group.kind}:${group.key}`} className="text-sm">
                  <span className="font-medium">{group.rows[0].text}</span>
                  <span className="ml-2 text-xs text-fg-4">
                    {group.rows.length} dòng · {group.unitCount} bài
                  </span>
                  <span className="mt-0.5 block text-xs text-fg-3">
                    {group.rows.map((row) => (
                      <span key={`${row.unitId}:${row.index}`} className="mr-2 inline-block">
                        <Link
                          href={`/courses/${report.courseId}/units/${row.unitId}?tab=${
                            group.kind === 'word' ? 'vocab' : 'sentences'
                          }&row=${row.index}`}
                          transitionTypes={['nav-forward']}
                          className={link}
                        >
                          bài {row.order + 1} · dòng {row.index + 1}
                        </Link>
                      </span>
                    ))}
                  </span>
                </li>
              ))}
              {block.groups.length > GROUP_LIMIT && (
                <li className="text-xs text-fg-4">
                  … còn {block.groups.length - GROUP_LIMIT} nhóm nữa chưa liệt kê.
                </li>
              )}
            </ul>
          )}
        </section>
      ))}
    </div>
  );
}

export function generateMetadata({ params }: { params: Promise<{ courseId: string }> }) {
  return params.then(() => ({ title: 'Tìm và thay thế nội dung' }));
}
