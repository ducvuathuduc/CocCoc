import { CourseMetaForm } from '@/components/course-tools';
import { CourseStructure } from '@/components/course-structure';
import { CourseTabs } from '@/components/course-tabs';
import { PageTransition } from '@/components/page-transition';
import { PlacementPanel } from '@/components/placement-panel';
import { getCourseRecord, unitIndex } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { card, hint } from '@/lib/ui';
import { cn } from '@/lib/utils';

export const instant = false;

export default async function CourseStructurePage({
  params,
}: {
  params: Promise<{ courseId: string }>;
}) {
  const { courseId } = await params;
  await requireAdmin();
  const course = await getCourseRecord(courseId);

  if (!course) {
    return (
      <PageTransition>
        <div className="space-y-4">
          <CourseTabs courseId={courseId} />
          <p className={hint}>
            Khóa này chưa có bản soạn, nên chưa có phần học nào để xếp. Mở tab <b>Bài học</b> và lấy
            nội dung có sẵn trước.
          </p>
        </div>
      </PageTransition>
    );
  }

  const units = await unitIndex(courseId);
  const unplaced = units.filter(
    (u) => !course.draft.sections.some((s) => s.units.includes(u.theme)),
  ).length;

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <CourseTabs courseId={courseId} />

        <section className={cn(card, 'p-5')}>
          <h2 className="text-sm font-medium">Tên và thông tin chung của khóa</h2>
          <p className={cn(hint, 'mb-4 mt-1')}>
            Tên khóa là chữ hiện ở danh sách khóa và tiêu đề các màn soạn bài. Các mã ngôn ngữ chỉ
            đổi khi cả app đổi theo — nếu không chắc, để nguyên.
          </p>
          <CourseMetaForm
            courseId={courseId}
            revision={course.revision}
            meta={course.draft.course}
            version={course.draft.version}
          />
        </section>

        <section className={cn(card, 'p-5')}>
          <h2 className="text-sm font-medium">Các phần học</h2>
          <p className={cn(hint, 'mb-4 mt-1')}>
            App đi theo thứ tự: phần học → bài học. Mỗi bài phải nằm trong đúng một phần; {unplaced}{' '}
            bài đang chưa nằm ở phần nào. Đổi phần không làm mất nội dung của bài.
          </p>
          <CourseStructure
            courseId={courseId}
            revision={course.revision}
            sections={course.draft.sections}
            units={units}
          />
        </section>

        <PlacementPanel courseId={courseId} />
      </div>
    </PageTransition>
  );
}

export function generateMetadata({ params }: { params: Promise<{ courseId: string }> }) {
  return params.then(() => ({
    title: 'Cấu trúc và thông tin khóa',
  }));
}
