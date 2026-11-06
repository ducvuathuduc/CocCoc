import { NextResponse, type NextRequest } from 'next/server';
import { assertAdmin } from '@/server/session';
import {
  assertSafeId,
  audioTask,
  courseMediaReport,
  imageTask,
  type CourseMediaReport,
} from '@/server/media-service';

/**
 * The same gap list the media page shows, as data, for whoever runs the generators. `audio.keys` are
 * ready for `generate-audio.mjs --only`; `audio.needsBuild` are invented by drafts newer than the built
 * catalog, so the honest answer is "build first", not a list the tool would silently ignore.
 */
export async function GET(request: NextRequest): Promise<Response> {
  try {
    await assertAdmin();
  } catch {
    return NextResponse.json({ error: 'Cần đăng nhập để xem danh sách media.' }, { status: 401 });
  }

  const courseId = request.nextUrl.searchParams.get('course') ?? '';
  if (!courseId) return NextResponse.json({ error: 'Thiếu course.' }, { status: 400 });

  let report: CourseMediaReport | null;
  try {
    report = await courseMediaReport(assertSafeId(courseId, 'course'));
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Khóa không hợp lệ.' },
      { status: 400 },
    );
  }
  if (!report) return NextResponse.json({ error: 'Khóa chưa có bản nháp trong CMS.' }, { status: 404 });

  const audio = report.gaps.filter((gap) => gap.kind === 'audio');
  const task = audioTask(report.gaps);
  return NextResponse.json(
    {
      courseId: report.courseId,
      version: report.version,
      totals: {
        assets: report.totals.total,
        ready: report.totals.ready,
        missingFile: report.totals.missing,
        manifestOutdated: report.totals.unmanifested,
        catalogBehindDraft: report.totals.drift,
        pictureNotUsed: report.totals.unused,
        /** Shipped by a lesson, never asked about by an `imageChoice`: the generator's silent downgrade. */
        pictureNeverQuizzed: report.totals.picturesWithoutDrill,
      },
      audio: {
        keys: task.keys,
        needsBuild: [...task.needsBuild, ...task.drift],
        driftKeys: task.drift,
        /** Gaps whose id only the last build knows (`a.w.*`) — the draft cannot name them. */
        wordClipGaps: audio.filter((gap) => gap.fromBuild).length,
        items: audio.map((gap) => ({
          key: gap.fileId.replace(/\.[ns]$/, ''),
          fileId: gap.fileId,
          text: gap.text,
          speed: gap.speed,
          state: gap.state,
          inCatalog: gap.inCatalog,
          unitId: gap.unitId,
          genUnitId: gap.genUnitId,
        })),
      },
      images: {
        keys: imageTask(report.gaps),
        unusedKeys: report.unusedImages,
        /** Pictures a lesson ships but no picture drill asks about — content work, not media work. */
        unquizzedKeys: report.picturesWithoutDrill,
      },
      /** What the last build actually handed the app: exercise types per unit, plus files it never reads. */
      built: {
        unreadableBundles: report.unreadableBundles,
        exerciseTypes: report.totals.exerciseTypes,
        perUnit: report.units.map((unit) => ({
          genUnitId: unit.genUnitId,
          exerciseTypes: unit.exerciseTypes,
          images: unit.image,
          unusedPictures: unit.unused,
          unquizzedPictures: unit.picturesWithoutDrill,
        })),
      },
      command: task.keys.length
        ? `node tools/content/generate-audio.mjs --course ${report.courseId} --version ${report.version} --only ${task.keys.join(',')}`
        : null,
    },
    { headers: { 'Cache-Control': 'private, no-store' } },
  );
}
