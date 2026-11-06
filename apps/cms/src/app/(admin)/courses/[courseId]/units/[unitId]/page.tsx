import { notFound } from 'next/navigation';
import { UnitEditor } from '@/components/unit-editor';
import { UnitMedia } from '@/components/unit-media';
import { getCourseRecord, getUnitRecord } from '@/server/queries';
import { requireAdmin } from '@/server/session';

export const instant = false;

export default async function UnitPage({
  params,
  searchParams,
}: {
  params: Promise<{ courseId: string; unitId: string }>;
  searchParams: Promise<{ tab?: string; row?: string }>;
}) {
  const { courseId, unitId } = await params;
  const { tab, row } = await searchParams;
  await requireAdmin();
  const unit = await getUnitRecord(courseId, unitId);
  if (!unit) notFound();
  const course = await getCourseRecord(courseId);

  return (
    <UnitEditor
      courseId={courseId}
      unitId={unitId}
      order={unit.order}
      revision={unit.revision}
      initialTab={tab}
      initialRow={row === undefined || Number.isNaN(Number(row)) ? undefined : Number(row)}
      initial={unit.draft}
      mediaPanel={
        <UnitMedia
          courseId={courseId}
          version={course?.draft.version ?? 'v2'}
          order={unit.order}
          draft={unit.draft}
        />
      }
    />
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ courseId: string; unitId: string }>;
}) {
  const { courseId, unitId } = await params;
  // Editors keep several lesson tabs open at once, so the tab label has to be the lesson's name —
  // a code like 02-family says nothing about which one to click back.
  const unit = await getUnitRecord(courseId, unitId);
  const title = unit?.draft.title.trim();
  return { title: title ? `Soạn bài: ${title}` : `Soạn bài ${unitId}` };
}
