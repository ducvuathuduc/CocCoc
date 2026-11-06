import { lintUnit } from '@/cms/lint';
import { repeatedSentences, repeatedWords, repeatsInsideUnit } from '@/cms/search';
import { structureIssues } from '@/cms/structure';
import { courseLessonDrift } from './lesson-service';
import { courseMediaReport } from './media-service';
import { placementReport } from './placement-service';
import { publishReadiness } from './publish-state';
import { getStore } from './store';

export type ReadinessState = 'ok' | 'warn' | 'block';

export interface ReadinessItem {
  id: string;
  label: string;
  state: ReadinessState;
  /** The number the row is about, so the page can lead with it instead of prose. */
  count: number;
  /** False only for the size of the course: every other row counts work left, so `ok` must mean `0`. */
  debt: boolean;
  detail: string;
  /** The screen that owns this number. The checklist links to it rather than growing its own controls. */
  href: string | null;
}

export interface ReadinessReport {
  courseId: string;
  version: string;
  unitCount: number;
  blocked: number;
  warned: number;
  /** Exactly `publishReadiness().gatesOk`, so this page and the Publish button cannot disagree. */
  publishable: boolean;
  publishBlocking?: string;
  items: ReadinessItem[];
}

const item = (
  id: string,
  label: string,
  count: number,
  detail: string,
  href: string | null,
  state: ReadinessState = count > 0 ? 'warn' : 'ok',
): ReadinessItem => ({
  id,
  label,
  state,
  count,
  debt: id !== 'units',
  detail,
  href,
});

/**
 * Everything that still stands between this course and a build the app can use, in one list. Each row comes
 * from the same derivation the screen that owns it uses — the media report, the placement mirror, the
 * bundles of the last build — so the checklist is a summary of those pages, never a second opinion.
 */
export async function courseReadiness(courseId: string): Promise<ReadinessReport | null> {
  const store = getStore();
  const course = await store.getCourse(courseId);
  if (!course) return null;
  const units = await store.listUnits(courseId);
  const publish = await publishReadiness(courseId);

  const items: ReadinessItem[] = [];
  const push = (next: ReadinessItem) => items.push(next);

  push(
    item(
      'units',
      'Bài đã có bản soạn',
      units.length,
      units.length
        ? `${units.length} bài trong bản ${course.draft.version}`
        : 'Chưa có bài nào — máy dựng không còn gì để dựng.',
      `/courses/${courseId}`,
      units.length ? 'ok' : 'block',
    ),
  );

  const structural = structureIssues(
    course.draft.sections,
    units.map((u) => u.draft.theme),
  );
  push(
    item(
      'structure',
      'Các phần học',
      structural.length,
      structural.length
        ? structural.join(' ')
        : 'Mọi bài thuộc đúng một phần học, và không phần nào rỗng.',
      `/courses/${courseId}/structure`,
      structural.length ? 'block' : 'ok',
    ),
  );

  const broken = units.filter((u) => lintUnit(u.draft).some((i) => i.level === 'error'));
  const soft = units.filter(
    (u) => !broken.includes(u) && lintUnit(u.draft).some((i) => i.level === 'warning'),
  );
  push(
    item(
      'lint-errors',
      'Bài đang chưa lưu được',
      broken.length,
      broken.length
        ? `${broken.map((u) => u.unitId).join(', ')} — màn soạn bài đang từ chối lưu những bài này, nên bản soạn chưa phải đầu vào hợp lệ của máy dựng.`
        : 'Không bài nào bị từ chối khi lưu.',
      '/ops/reports',
      broken.length ? 'block' : 'ok',
    ),
  );
  push(
    item(
      'lint-warnings',
      'Bài có điều nên sửa thêm',
      soft.length,
      soft.length
        ? `${soft.map((u) => u.unitId).join(', ')} — thiếu gợi ý, thiếu tên hoặc đoạn truyện, số câu hỏi đọc hiểu khác 6, hoặc chữ quá dài. Không chặn bản dựng nhưng app sẽ nghèo nội dung.`
        : 'Không bài nào thiếu gợi ý, thiếu đoạn truyện hay lệch số câu hỏi đọc hiểu.',
      '/ops/reports',
    ),
  );

  const runs = await store.listBuildRuns(courseId);
  const lastGate = runs.find((r) => r.kind === 'GATES' && r.status === 'SUCCEEDED');
  const editedAfterGate = units.filter(
    (u) => !lastGate || Date.parse(u.updatedAt) > Date.parse(lastGate.createdAt),
  );
  push(
    item(
      'gate',
      'Bộ kiểm tra tự động gần nhất',
      editedAfterGate.length,
      !lastGate
        ? 'Chưa chạy bộ kiểm tra nào tới đích — app chưa có bản đã kiểm để tải.'
        : editedAfterGate.length
          ? `${editedAfterGate.length} bài sửa sau lần kiểm tra ${lastGate.createdAt.slice(0, 16).replace('T', ' ')}: ${editedAfterGate.map((u) => u.unitId).join(', ')} — bản dựng hiện tại không còn là bản đã kiểm.`
          : `Kiểm tra đạt lúc ${lastGate.createdAt.slice(0, 16).replace('T', ' ')}, sau mọi lần sửa bản soạn.`,
      `/builds?course=${courseId}`,
      !lastGate || editedAfterGate.length ? 'block' : 'ok',
    ),
  );

  const placement = await placementReport(courseId);
  if (placement) {
    push(
      item(
        'placement-blockers',
        'Bài kiểm tra trình độ còn đọc được',
        placement.blockers.length,
        placement.blockers.length
          ? `${placement.blockers.join(', ')} — bài ${placement.genUnitId} không còn dòng ở đúng vị trí máy dựng chỉ, và bản dựng dừng ở đó chứ không âm thầm bỏ câu.`
          : 'Cả 10 vị trí máy dựng đọc vẫn còn trong bài mở màn.',
        `/courses/${courseId}/structure`,
        placement.blockers.length ? 'block' : 'ok',
      ),
    );
    push(
      item(
        'placement-changed',
        'Bài kiểm tra trình độ hỏi khác bản soạn',
        placement.changed.length,
        placement.changed.length
          ? `App đang hỏi ${placement.changed.length} câu khác bản soạn hiện hành (${placement.changed.join(', ')}) — lần dựng kế tiếp sẽ viết lại.`
          : 'Mỗi câu app đang hỏi vẫn khớp một dòng trong bản soạn, nên lần dựng tới không đổi bài kiểm tra.',
        `/courses/${courseId}/structure`,
      ),
    );
  }

  const drift = await courseLessonDrift(courseId);
  if (drift) {
    push(
      item(
        'build-found',
        'Bài của bản dựng đọc được',
        drift.missing.length + drift.unreadable.length,
        !drift.manifestFound
          ? `Chưa có danh mục bài (manifest.json) cho bản ${drift.version} — khóa này chưa từng được dựng.`
          : drift.missing.length || drift.unreadable.length
            ? `${drift.missing.length} bài danh mục nêu mà không có file (${drift.missing.slice(0, 3).join(', ')}), ${drift.unreadable.length} file không phải bài học (${drift.unreadable.slice(0, 3).join(', ')}).`
            : `${drift.lessonCount} bài · ${drift.exerciseCount} câu, đủ file cho mọi id danh mục nêu.`,
        `/courses/${courseId}/units/${units[0]?.unitId ?? ''}/lesson`,
        !drift.manifestFound
          ? 'block'
          : drift.missing.length + drift.unreadable.length
            ? 'warn'
            : 'ok',
      ),
    );
    const staleTotal = drift.stale.reduce((sum, unit) => sum + unit.ids.length, 0);
    push(
      item(
        'build-drift',
        'Câu app hỏi nhưng bản soạn không còn',
        staleTotal,
        staleTotal
          ? `${drift.stale.length} bài: ${drift.stale.map((u) => `${u.unitNumber} (${u.ids.length})`).join(', ')} — app vẫn hỏi những dòng này cho tới khi dựng lại.`
          : `${drift.exerciseCount} câu của bản dựng đều trỏ lại được một dòng trong bản soạn.`,
        drift.stale.length
          ? `/courses/${courseId}/units/${drift.stale[0].unitId}/lesson`
          : `/courses/${courseId}/units/${units[0]?.unitId ?? ''}/lesson`,
        staleTotal ? 'warn' : 'ok',
      ),
    );
  }

  const media = await courseMediaReport(courseId);
  if (media) {
    const owed = media.totals.missing + media.totals.unmanifested + media.totals.drift;
    push(
      item(
        'media',
        'Audio và ảnh: chưa có file, hoặc đã có file mà app chưa dùng được',
        owed,
        owed
          ? `${media.totals.missing} chưa có file · ${media.totals.unmanifested} có file nhưng máy chưa đọc được · ${media.totals.drift} lời thoại khác bản soạn · ${media.totals.ready} đã đủ. Phát hành chỉ gửi file đang tồn tại; phần thiếu app sẽ dùng phương án không audio/ảnh.`
          : `${media.totals.ready} file audio/ảnh đều có mặt và máy đọc được.`,
        `/courses/${courseId}/media`,
      ),
    );
    const silent = media.totals.unused + media.totals.picturesWithoutDrill;
    push(
      item(
        'pictures',
        'Ảnh chưa bài nào đố tới',
        silent,
        silent
          ? `${media.totals.unused} ảnh không bản dựng nào chở · ${media.totals.picturesWithoutDrill} ảnh có mặt nhưng chưa bài nào chọn ảnh để hỏi. Đây là việc soạn nội dung (thêm từ có ảnh rồi dựng lại), không phải việc của kho file.`
          : 'Mọi ảnh đã nạp đều nằm trong một bản dựng và có một bài chọn ảnh đố tới.',
        `/courses/${courseId}/media`,
      ),
    );
  }

  const words = repeatedWords(units);
  const inside = repeatsInsideUnit(units);
  const sentences = repeatedSentences(units);
  push(
    item(
      'repeats',
      'Nội dung dạy trùng',
      words.length + inside.length + sentences.length,
      words.length + inside.length + sentences.length
        ? `${words.length} từ dạy ở nhiều hơn một bài · ${inside.length} từ trùng trong cùng một bài · ${sentences.length} câu tiếng Anh lặp lại.`
        : 'Không từ nào dạy ở hai bài, không câu nào lặp lại.',
      `/courses/${courseId}/search`,
    ),
  );

  return {
    courseId,
    version: course.draft.version,
    unitCount: units.length,
    blocked: items.filter((i) => i.state === 'block').length,
    warned: items.filter((i) => i.state === 'warn').length,
    publishable: publish?.gatesOk ?? false,
    publishBlocking: publish?.blocking,
    items,
  };
}
