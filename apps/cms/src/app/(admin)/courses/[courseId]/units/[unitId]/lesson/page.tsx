import Link from 'next/link';
import { notFound } from 'next/navigation';
import { PageTransition } from '@/components/page-transition';
import { badge, card, code, link, tile } from '@/lib/ui';
import { cn } from '@/lib/utils';
import type { BuiltExercise, BuiltLesson } from '@/cms/lessons';
import { unitLessons } from '@/server/lesson-service';
import { getUnitRecord } from '@/server/queries';
import { requireAdmin } from '@/server/session';

export const instant = false;

/** How many exercises a lesson lists before the screen folds the rest behind a click. */
const OPEN_LIMIT = 4;

export default async function UnitLessonsPage({
  params,
}: {
  params: Promise<{ courseId: string; unitId: string }>;
}) {
  const { courseId, unitId } = await params;
  await requireAdmin();
  const report = await unitLessons(courseId, unitId);
  if (!report) notFound();

  const { unit } = report;
  const nodes = new Map<string, BuiltLesson[]>();
  for (const lesson of report.lessons) {
    const key = lesson.nodeId || '—';
    nodes.set(key, [...(nodes.get(key) ?? []), lesson]);
  }
  const drillKinds = Object.keys(report.types).length;

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          <Link
            href={`/courses/${courseId}/units/${unitId}`}
            transitionTypes={['nav-back']}
            className="inline-block text-xs text-fg-4 hover:-translate-x-0.5 hover:text-primary-text"
          >
            ← {unit.draft.title || unitId}
          </Link>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight">
            App đang hỏi gì trong bài này
          </h1>
          <p className="mt-1 max-w-3xl text-sm leading-relaxed text-fg-3">
            Đây là đúng những gì người học thấy trên điện thoại, lấy từ bản dựng gần nhất — không
            phải những gì bản soạn đang đòi. Nếu bạn vừa sửa nội dung, khác biệt ở đây là bình
            thường: bản dựng chỉ theo kịp sau{' '}
            <Link href={`/builds?course=${courseId}`} className={link}>
              bước kiểm tra và phát hành
            </Link>
            .
          </p>
          <details className="mt-2">
            <summary className="cursor-pointer list-none text-xs text-fg-4 hover:text-primary-text [&::-webkit-details-marker]:hidden">
              Bản dựng này nằm ở đâu
            </summary>
            <p className="mt-1 text-xs text-fg-4">
              <span className={code}>
                content/{courseId}/dist/{report.version}/bundles
              </span>
            </p>
          </details>
        </header>

        <section className="rise grid grid-cols-2 gap-4 md:grid-cols-4">
          <Tile label="Màn trong app" value={report.lessons.length} />
          <Tile label="Câu hỏi" value={report.exerciseCount} />
          <Tile label="Dạng bài" value={drillKinds} />
          <Tile
            label="Câu app hỏi mà bản soạn không còn"
            value={report.stale.length}
            tone={report.stale.length ? 'text-warn-fg' : 'text-fg'}
          />
        </section>

        {!report.manifestFound && (
          <div className={cn(card, 'p-6 text-sm text-fg-3')}>
            Khóa này chưa từng được dựng, nên app chưa có bài học nào để hỏi. Hãy chạy bước kiểm tra
            và phát hành trước.
          </div>
        )}

        {report.missing.length > 0 && (
          <div className={cn(card, 'border-warn-bd bg-warn-bg p-4 text-sm text-warn-fg')}>
            Danh mục bài của bản dựng kể {report.missing.length} bài nhưng không đọc được file — con
            số bên dưới thiếu đúng bấy nhiêu.{' '}
            <details className="mt-1 inline">
              <summary className="cursor-pointer list-none text-xs [&::-webkit-details-marker]:hidden">
                bài nào
              </summary>
              <span className={cn(code, 'block')}>{report.missing.join(', ')}</span>
            </details>
          </div>
        )}

        {report.stale.length > 0 && (
          <div className={cn(card, 'p-4')}>
            <h2 className="text-sm font-medium text-warn-fg">
              {report.stale.length} câu app vẫn hỏi dù bản soạn không còn nội dung đó
            </h2>
            <p className="mt-1 text-xs leading-relaxed text-fg-3">
              Người học sẽ vẫn gặp những câu này cho tới khi dựng lại khóa. Đây là dấu hiệu bản dựng
              đang cũ hơn bản soạn, không phải lỗi mất dữ liệu.
            </p>
            <details className="mt-2">
              <summary className="cursor-pointer list-none text-xs text-fg-4 hover:text-primary-text [&::-webkit-details-marker]:hidden">
                mã câu hỏi (dành cho người chạy lệnh dựng)
              </summary>
              <div className="mt-2 flex flex-wrap gap-1">
                {report.stale.map((id) => (
                  <span key={id} className={cn(code, 'bg-warn-bg text-warn-fg')}>
                    {id}
                  </span>
                ))}
              </div>
            </details>
          </div>
        )}

        {[...nodes.entries()].map(([nodeId, lessons], nodeIndex) => {
          const questions = lessons.reduce((sum, lesson) => sum + lesson.exercises.length, 0);
          return (
            <details
              key={nodeId}
              className={cn(card, 'group px-4 py-3')}
              open={nodeIndex === 0 || lessons.length === 0}
            >
              <summary className="flex cursor-pointer list-none flex-wrap items-baseline gap-x-3 gap-y-1 [&::-webkit-details-marker]:hidden">
                <span className="inline-block text-fg-3 transition-transform group-open:rotate-90">
                  ›
                </span>
                <h2 className="text-sm font-medium">{lessons[0].nodeTitle || `Mức ${nodeId}`}</h2>
                <span className="text-xs tabular-nums text-fg-4">
                  {lessons.length} màn · {questions} câu
                </span>
                <span className="ml-auto text-xs text-fg-4">
                  {nodeIndex === 0 ? 'đang mở' : 'bấm để xem'}
                </span>
              </summary>
              <div className="mt-3 space-y-4 border-t border-line pt-3">
                {lessons.map((lesson) => (
                  <Lesson
                    key={lesson.lessonId}
                    courseId={courseId}
                    unitId={unitId}
                    unitNumber={report.unitNumber}
                    unitIds={report.unitIds}
                    lesson={lesson}
                  />
                ))}
              </div>
            </details>
          );
        })}
      </div>
    </PageTransition>
  );
}

function Lesson({
  courseId,
  unitId,
  unitNumber,
  unitIds,
  lesson,
}: {
  courseId: string;
  unitId: string;
  unitNumber: string;
  unitIds: Record<string, string>;
  lesson: BuiltLesson;
}) {
  const shared = { courseId, unitId, unitNumber, unitIds };
  return (
    <article className="rounded-lg border border-line bg-elevated/40 p-3">
      <div className="flex flex-wrap items-baseline gap-2">
        <h3 className="text-sm font-medium">{lesson.title}</h3>
        <span className="text-xs tabular-nums text-fg-4">{lesson.exercises.length} câu</span>
      </div>
      <ol className="mt-2 space-y-2">
        {lesson.exercises.slice(0, OPEN_LIMIT).map((exercise, i) => (
          <Exercise key={exercise.id} {...shared} exercise={exercise} n={i + 1} />
        ))}
        {lesson.exercises.length > OPEN_LIMIT && (
          <li>
            <details>
              <summary className="cursor-pointer text-xs text-fg-3 hover:text-primary-text">
                … còn {lesson.exercises.length - OPEN_LIMIT} câu nữa
              </summary>
              <ol className="mt-2 space-y-2">
                {lesson.exercises.slice(OPEN_LIMIT).map((exercise, i) => (
                  <Exercise
                    key={exercise.id}
                    {...shared}
                    exercise={exercise}
                    n={OPEN_LIMIT + i + 1}
                  />
                ))}
              </ol>
            </details>
          </li>
        )}
      </ol>
    </article>
  );
}

function Exercise({
  courseId,
  unitId,
  unitNumber,
  unitIds,
  exercise,
  n,
}: {
  courseId: string;
  unitId: string;
  unitNumber: string;
  unitIds: Record<string, string>;
  exercise: BuiltExercise;
  n: number;
}) {
  return (
    <li className="rounded-lg border border-line bg-card p-3">
      <div className="flex flex-wrap items-center gap-2 text-xs">
        <span className="tabular-nums text-fg-4">Câu {n}</span>
        <span className={badge}>{exercise.label}</span>
      </div>
      <p className="mt-1 text-sm">{exercise.prompt}</p>
      {exercise.answer && exercise.pairs.length === 0 && (
        <p className="mt-1 text-sm">
          <span className="text-xs text-fg-4">Đáp án: </span>
          <span className="font-medium text-ok-fg">{exercise.answer}</span>
        </p>
      )}
      {exercise.choices.length > 0 && (
        <ul className="mt-2 flex flex-wrap gap-1.5 text-xs">
          {exercise.choices.map((choice, i) => (
            <li
              key={`${choice.text}${i}`}
              className={cn(
                'rounded-md border px-2 py-1',
                choice.correct ? 'border-ok-bd bg-ok-bg text-ok-fg' : 'border-line text-fg-3',
              )}
            >
              {choice.correct && '✓ '}
              {choice.text}
              {choice.imageAssetId && (
                <span className={cn(code, 'ml-1')} title={choice.imageAssetId}>
                  có ảnh
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
      {exercise.pairs.length > 0 && (
        <ul className="mt-2 grid gap-1 text-xs text-fg-3 sm:grid-cols-2">
          {exercise.pairs.map((pair, i) => (
            <li key={`${pair.left}${pair.right}${i}`}>
              <span className="text-fg">{pair.left}</span> → {pair.right}
            </li>
          ))}
        </ul>
      )}
      {exercise.accepted.length > 1 && (
        <p className="mt-1 text-xs text-fg-4">
          Các cách trả lời khác cũng được chấp nhận: {exercise.accepted.slice(1).join(' · ')}
        </p>
      )}
      {exercise.passage && (
        <details className="mt-2">
          <summary className="cursor-pointer text-xs text-fg-3 hover:text-primary-text">
            Đoạn truyện
          </summary>
          <p className="mt-1 text-xs leading-relaxed text-fg-2">{exercise.passage}</p>
        </details>
      )}
      {(exercise.hint || exercise.explanation) && (
        <details className="mt-1">
          <summary className="cursor-pointer text-xs text-fg-4 hover:text-primary-text">
            Gợi ý &amp; giải thích
          </summary>
          {exercise.hint && <p className="mt-1 text-xs text-fg-3">{exercise.hint}</p>}
          {exercise.explanation && <p className="mt-1 text-xs text-fg-3">{exercise.explanation}</p>}
        </details>
      )}
      {exercise.variant && (
        <p className="mt-1 text-xs leading-relaxed text-fg-3">
          Nếu điện thoại không dùng được mic hay loa, câu này tự đổi thành{' '}
          <span className="font-medium">{exercise.variant.label}</span>: {exercise.variant.prompt}
          {exercise.variant.answer && <> — đáp án {exercise.variant.answer}</>}
        </p>
      )}
      <div className="mt-2 flex flex-wrap items-center gap-1.5 text-xs">
        {exercise.refs.length > 0 && <span className="text-fg-4">Nội dung này soạn ở:</span>}
        {exercise.refs.map((ref) => (
          <Link
            key={`${ref.unitNumber}${ref.tab}${ref.row}`}
            href={`/courses/${courseId}/units/${unitIds[ref.unitNumber] ?? unitId}?tab=${ref.tab}`}
            transitionTypes={['nav-back']}
            className={cn(
              link,
              'rounded-md border px-2 py-0.5 no-underline hover:border-primary/40',
              ref.unitNumber === unitNumber ? 'border-line' : 'border-line-strong bg-elevated',
            )}
          >
            {ref.unitNumber !== unitNumber && `${ref.unitNumber} · `}
            {ref.label} · dòng {ref.row + 1}
          </Link>
        ))}
        {(exercise.unknown.length > 0 || exercise.variantUnknown.length > 0) && (
          <span className="text-warn-fg">
            {exercise.unknown.length + exercise.variantUnknown.length} mã câu của bài này không còn
            trong bản soạn — dựng lại khóa là hết
          </span>
        )}
      </div>
      {(exercise.skills.length > 0 ||
        exercise.locale ||
        exercise.audioAssetId ||
        exercise.unknown.length > 0 ||
        exercise.variantUnknown.length > 0) && (
        <details className="mt-1.5">
          <summary className="cursor-pointer list-none text-xs text-fg-4 hover:text-primary-text [&::-webkit-details-marker]:hidden">
            mã máy dựng dùng
          </summary>
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs">
            {exercise.skills.map((skill) => (
              <span key={skill} className={code}>
                {skill}
              </span>
            ))}
            {exercise.locale && <span className={code}>{exercise.locale}</span>}
            {exercise.audioAssetId && <span className={code}>{exercise.audioAssetId}</span>}
            {exercise.unknown.map((id) => (
              <span
                key={id}
                className="rounded-md border border-warn-bd bg-warn-bg px-2 py-0.5 text-warn-fg"
              >
                {id} — không còn trong nháp
              </span>
            ))}
            {exercise.variantUnknown.map((id) => (
              <span
                key={`v${id}`}
                className="rounded-md border border-warn-bd bg-warn-bg px-2 py-0.5 text-warn-fg"
              >
                {id} — nháp hết dòng, bài thay thế vẫn hỏi
              </span>
            ))}
          </div>
        </details>
      )}
    </li>
  );
}

function Tile({ label, value, tone }: { label: string; value: number; tone?: string }) {
  return (
    <div className={tile}>
      <div className="text-xs text-fg-4">{label}</div>
      <div className={cn('mt-1 text-xl font-semibold tabular-nums tracking-tight', tone)}>
        {value}
      </div>
    </div>
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ courseId: string; unitId: string }>;
}) {
  const { courseId, unitId } = await params;
  const unit = await getUnitRecord(courseId, unitId);
  const title = unit?.draft.title.trim();
  return { title: title ? `App hỏi gì: ${title}` : `App đang hỏi gì trong bài ${unitId}` };
}
