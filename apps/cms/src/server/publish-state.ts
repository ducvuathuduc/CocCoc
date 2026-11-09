import { cache } from 'react';
import { structureIssues } from '@/cms/structure';
import { buildRuns, courseUnits, getCourseRecord } from './queries';
import { courseMediaReport } from './media-service';

export interface PublishReadiness {
  version: string;
  unitCount: number;
  gatesOk: boolean;
  gateRunAt?: string;
  blocking?: string;
}

/**
 * A course is publishable when every draft unit is older than the last successful gate run: the
 * publisher ships what `content/<courseId>/dist/<version>` holds, so an edit after the gate means the
 * build the app would get is not the build that was checked.
 */
export const publishReadiness = cache(
  async (courseId: string): Promise<PublishReadiness | null> => {
    const [course, units, runs] = await Promise.all([
      getCourseRecord(courseId),
      courseUnits(courseId),
      buildRuns(courseId),
    ]);
    if (!course) return null;
    const lastGate = runs.find((r) => r.kind === 'GATES' && r.status === 'SUCCEEDED');
    const stale = units.find(
      (u) => !lastGate || Date.parse(u.updatedAt) > Date.parse(lastGate.createdAt),
    );

    let blocking: string | undefined;
    const structural = structureIssues(
      course.draft.sections,
      units.map((u) => u.draft.theme),
    );
    if (units.length === 0) blocking = 'Khóa chưa có bài học nào.';
    else if (structural.length) blocking = `Cấu trúc khóa chưa sẵn sàng: ${structural.join(' ')}`;
    else if (!lastGate)
      blocking = 'Chưa có lần kiểm tra tự động nào thành công — hãy chạy kiểm tra tự động trước.';
    else if (stale)
      blocking = `Bài ${stale.unitId} đã sửa sau lần kiểm tra gần nhất, nên bản kiểm tra không còn khớp với bài đang soạn.`;

    // The offline gate (verifyMediaAssets) throws when a built bundle references a file that is absent
    // from the media tree, so a missing required asset is a hard publish block — the same rule the
    // readiness checklist reports under "Audio, ảnh: thiếu file (chặn phát hành)".
    if (!blocking) {
      const media = await courseMediaReport(courseId);
      if (media && media.totals.missing > 0)
        blocking = `Thiếu ${media.totals.missing} file audio/ảnh bắt buộc — máy kiểm tra nội dung sẽ dừng, chưa thể phát hành. Nạp file tại trang Kho media.`;
    }

    return {
      version: course.draft.version,
      unitCount: units.length,
      gatesOk: !blocking,
      gateRunAt: lastGate?.createdAt,
      blocking,
    };
  },
);
