import type { StageState } from '@/lib/stages';
import { timeAgo } from '@/lib/utils';
import { buildRuns, lastLivePublish } from './queries';
import { workspaceData, type WorkspaceData } from './workspace';

export type StageKey = 'authoring' | 'checking' | 'publishing';

export interface StageView {
  key: StageKey;
  label: string;
  state: StageState;
  line: string;
}

export type NextKind = 'edit' | 'structure' | 'save-check' | 'review' | 'publish' | 'publish-locked';

export interface CourseWorkflow {
  courseId: string;
  title: string;
  version: string;
  unitCount: number;
  /** Lessons changed after the last green check: what was checked is no longer what is on disk. */
  awaitingValidation: number;
  stages: StageView[];
  /** Which stage the person is standing in, so a screen can point at it without re-deriving it. */
  next: { kind: NextKind; stage: StageKey; label: string; note: string; href: string };
  gate: { at: string; ok: boolean; message: string } | null;
  published: { at: string; version: string } | null;
  /** A check finished after the last real publish, so the app is behind the checked content. */
  checkAfterPublish: boolean;
  publishAllowed: boolean;
  appwriteMode: boolean;
}

/**
 * One reading of "where is this course in Soạn bài → Kiểm tra → Xuất bản, and what is the next thing
 * to do". Every number comes from the store or the run history, and a dry run never counts as a
 * publication, so the screen cannot claim a state the backend does not hold. The home screen already
 * holds its `WorkspaceData`, so it hands it in rather than making the course read twice.
 */
export async function courseWorkflow(
  courseId: string,
  known?: WorkspaceData | null,
): Promise<CourseWorkflow | null> {
  const data = known ?? (await workspaceData(courseId));
  if (!data) return null;

  const { counts, publish, firstProblem, course } = data;
  const runs = await buildRuns(courseId);
  const builds = `/builds?course=${courseId}`;
  const lastGate = runs.find((run) => run.kind === 'GATES') ?? null;
  const livePublish = lastLivePublish(runs);
  const problems = counts.errors + counts.empty;
  const structural = data.structureIssues.length > 0;
  const checkAfterPublish =
    Boolean(livePublish) &&
    Boolean(publish.gateAt) &&
    Date.parse(publish.gateAt as string) > Date.parse(livePublish?.createdAt ?? '');

  const next = structural
    ? {
        kind: 'structure' as NextKind,
        stage: 'authoring' as StageKey,
        label: 'Sửa cấu trúc khóa',
        note: data.structureIssues.join(' '),
        href: `/courses/${courseId}/structure`,
      }
    : counts.total === 0 || problems > 0
      ? {
          kind: 'edit' as NextKind,
          stage: 'authoring' as StageKey,
          label: counts.total === 0 ? 'Soạn bài đầu tiên' : `Sửa ${problems} bài chưa xong`,
          note:
            counts.total === 0
              ? 'Thêm bài học đầu tiên để bắt bộ nội dung.'
              : 'Bước kiểm tra chỉ đọc những bài đã sạch lỗi, nên sửa nốt rồi quay lại đây.',
          href: firstProblem
            ? `/courses/${courseId}/units/${firstProblem.unitId}`
            : `/courses/${courseId}`,
        }
      : !publish.gatesOk && lastGate?.status === 'FAILED'
        ? {
            kind: 'review' as NextKind,
            stage: 'checking' as StageKey,
            label: 'Xem những gì bước kiểm tra báo',
            note: lastGate.message,
            href: `/courses/${courseId}/readiness`,
          }
        : !publish.gatesOk
          ? {
              kind: 'save-check' as NextKind,
              stage: 'checking' as StageKey,
              label:
                publish.awaitingValidation > 0 ? 'Lưu bài và kiểm tra' : 'Kiểm tra toàn khóa',
              note:
                publish.awaitingValidation > 0
                  ? `${publish.awaitingValidation} bài đã sửa từ lần kiểm tra trước. Bước kiểm tra đọc bản đã lưu, nên cần ghi lại trước khi kiểm tra.`
                  : 'Kiểm tra đọc lại toàn bộ bài của khóa và báo còn thiếu gì.',
              href: builds,
            }
          : !publish.appwriteMode || !publish.publishAllowed
            ? {
                kind: 'publish-locked' as NextKind,
                stage: 'publishing' as StageKey,
                label: 'Chờ quản trị mở quyền xuất bản',
                note: !publish.appwriteMode
                  ? 'Máy này lưu bài trên tệp riêng, chưa nối kho dùng chung, nên chưa gửi lên app được.'
                  : 'Nội dung đã sẵn sàng; người quản trị máy chủ cần bật cho phép xuất bản.',
                href: builds,
              }
            : {
                kind: 'publish' as NextKind,
                stage: 'publishing' as StageKey,
                label: checkAfterPublish ? 'Xuất bản bản mới đã kiểm tra' : 'Xuất bản cho app',
                note: checkAfterPublish
                  ? 'Bản kiểm tra gần nhất mới hơn bản app đang dùng; xuất bản để người học nhận bản này.'
                  : 'Bản đã kiểm tra sẵn sàng gửi cho người học. Bản cũ không bị xóa.',
                href: builds,
              };

  return {
    courseId,
    title: course.title,
    version: course.version,
    unitCount: counts.total,
    awaitingValidation: publish.awaitingValidation,
    stages: [
      {
        key: 'authoring',
        label: 'Soạn bài',
        state:
          counts.total === 0
            ? 'current'
            : structural || problems
              ? 'attention'
              : 'done',
        line:
          counts.total === 0
            ? 'Chưa có bài học nào.'
            : structural
              ? 'Cách chia phần học của khóa chưa khớp với bài.'
              : problems
                ? `Còn ${counts.errors} bài có lỗi cần sửa${
                    counts.empty ? ` · ${counts.empty} bài chưa có nội dung` : ''
                  }.`
                : `Cả ${counts.total} bài đã soạn, không còn lỗi.`,
      },
      {
        key: 'checking',
        label: 'Kiểm tra',
        state: publish.gatesOk
          ? 'done'
          : lastGate?.status === 'FAILED'
            ? 'attention'
            : counts.total === 0 || structural || problems
              ? 'waiting'
              : 'current',
        line: publish.gatesOk
          ? `Kiểm tra gần nhất đã qua ${timeAgo(lastGate?.createdAt ?? '')}.`
          : lastGate?.status === 'FAILED'
            ? 'Lần kiểm tra gần nhất chưa qua.'
            : publish.awaitingValidation > 0
              ? `${publish.awaitingValidation} bài đã sửa sau lần kiểm tra gần nhất.`
              : 'Chưa kiểm tra lần nào.',
      },
      {
        key: 'publishing',
        label: 'Xuất bản',
        state: !publish.gatesOk
          ? 'waiting'
          : livePublish && !checkAfterPublish
            ? 'done'
            : 'current',
        line: !publish.appwriteMode
          ? 'Máy này chưa nối kho nội dung dùng chung.'
          : !publish.publishAllowed
            ? 'Quyền xuất bản đang bị khóa trên máy chủ.'
            : livePublish
              ? checkAfterPublish
                ? 'Bản app đang dùng đã cũ hơn bản vừa kiểm tra.'
                : `App đã nhận bản này ${timeAgo(livePublish.createdAt)}.`
              : 'Chưa lần xuất bản nào thành công.',
      },
    ],
    next,
    gate: lastGate
      ? { at: lastGate.createdAt, ok: lastGate.status === 'SUCCEEDED', message: lastGate.message }
      : null,
    published: livePublish
      ? { at: livePublish.createdAt, version: livePublish.versionId }
      : null,
    checkAfterPublish,
    publishAllowed: publish.publishAllowed,
    appwriteMode: publish.appwriteMode,
  };
}
