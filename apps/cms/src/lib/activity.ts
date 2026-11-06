import type { AuditEntry } from '@/cms/types';

/**
 * Audit rows carry the operation names the server action wrote. A content creator should read what
 * happened, not the verb; the literal name stays available in the detail fold of `/ops/audit`.
 */
export const OPERATION_LABELS: Record<string, string> = {
  'unit.create': 'Tạo bài học',
  'unit.update': 'Cập nhật nội dung bài học',
  'unit.replace': 'Cập nhật nội dung bài học',
  'unit.reorder': 'Thay đổi thứ tự bài học',
  'unit.delete': 'Xóa bài học',
  'course.create': 'Tạo khóa học',
  'course.update': 'Cập nhật thông tin khóa học',
  'course.import': 'Nhập nội dung từ thư mục gốc',
  'content.export': 'Lưu bản nội dung',
  'content.gates': 'Chạy kiểm tra tự động',
  'content.publish': 'Xuất bản nội dung',
  'content.publish_dry_run': 'Chạy thử xuất bản',
  'media.upload': 'Tải lên audio hoặc ảnh',
  'media.delete': 'Xóa audio hoặc ảnh',
  'auth.login': 'Đăng nhập',
  'auth.logout': 'Đăng xuất',
};

export function operationLabel(operation: string): string {
  return OPERATION_LABELS[operation] ?? 'Cập nhật nội dung';
}

export interface ActivityTarget {
  courseId: string;
  courseTitle: string;
  /** `order` is zero-based, the same one the editor shows as “Bài N”. */
  units: { unitId: string; order: number; title: string }[];
}

/**
 * `targetId` is a storage key (`vi_en/01-greetings`, `vi_en/a.u1.s1.n`). The dashboard names the
 * lesson instead; when it cannot, it names the course — never the raw path.
 */
export function describeTarget(targetId: string, target: ActivityTarget): string {
  if (!targetId) return target.courseTitle;
  const slash = targetId.indexOf('/');
  if (slash === -1) return target.courseTitle;
  const courseId = targetId.slice(0, slash);
  const rest = targetId.slice(slash + 1);
  if (courseId !== target.courseId || !rest) return target.courseTitle;

  const unit = target.units.find((u) => u.unitId === rest);
  if (unit) return `Bài ${unit.order + 1} · ${unit.title}`;

  // Media ids are derived (`a.u1.s1.n`, `i.u1.hello`, `a.w.hello.n`); only the build maps a word id
  // back to its lesson, so a word clip falls back to the course instead of inventing a lesson.
  const media = /\.u(\d+)\./.exec(rest) ?? /^u(\d+)\./.exec(rest);
  if (media) {
    const owner = target.units.find((u) => u.order + 1 === Number(media[1]));
    return owner ? `Bài ${owner.order + 1} · ${owner.title}` : `Bài ${Number(media[1])}`;
  }
  return target.courseTitle;
}

export interface ActivityItem {
  entry: AuditEntry;
  label: string;
  target: string;
}

export function describeActivity(entry: AuditEntry, target: ActivityTarget): ActivityItem {
  return {
    entry,
    label: operationLabel(entry.operation),
    target: describeTarget(entry.targetId, target),
  };
}
