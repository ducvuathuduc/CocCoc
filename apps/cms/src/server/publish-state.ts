import { structureIssues } from '@/cms/structure';
import { getStore } from './store';

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
export async function publishReadiness(courseId: string): Promise<PublishReadiness | null> {
  const store = getStore();
  const course = await store.getCourse(courseId);
  if (!course) return null;
  const units = await store.listUnits(courseId);
  const lastGate = (await store.listBuildRuns(courseId)).find(
    (r) => r.kind === 'GATES' && r.status === 'SUCCEEDED',
  );
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

  return {
    version: course.draft.version,
    unitCount: units.length,
    gatesOk: !blocking,
    gateRunAt: lastGate?.createdAt,
    blocking,
  };
}
