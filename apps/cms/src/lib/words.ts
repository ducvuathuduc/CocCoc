import type { IconName } from '@/components/icons';

/**
 * One place where developer vocabulary becomes the words the person editing lessons actually uses.
 * Screens show the left-hand term; the technical name stays available inside `TechDetails` so nothing
 * an operator needs in order to reason about a build is lost — it is just not the first thing they read.
 */
export const WORDS = {
  unit: 'bài học',
  units: 'bài học',
  theme: 'chủ đề của bài',
  section: 'phần học',
  sections: 'các phần học',
  draft: 'bản soạn',
  revision: 'lần lưu',
  gate: 'bộ kiểm tra tự động',
  gates: 'bộ kiểm tra tự động',
  repo: 'thư mục nội dung gốc',
  build: 'bản dựng',
  manifest: 'danh mục bài của bản dựng',
  bundle: 'tập tin bài học của bản dựng',
  slot: 'vị trí câu hỏi',
  placement: 'bài kiểm tra trình độ',
  publish: 'phát hành cho app',
  dryRun: 'chạy thử, không ghi gì lên máy chủ',
  media: 'audio và ảnh',
  owed: 'còn thiếu',
  stale: 'tên file cũ còn sót lại',
} as const;

/** The technical name shown as a hint next to a plain label, e.g. `Chủ đề của bài (theme)`. */
export const techName = (term: keyof typeof WORDS): string =>
  term === 'dryRun' ? 'dry-run' : term;

/** Where the author has to look: a machine path like `vocab[3] (hello)` becomes `Từ vựng · dòng 4`. */
const WHERE: Record<string, string> = {
  theme: 'Chủ đề của bài',
  title: 'Tên bài',
  cefr: 'Trình độ',
  levels: 'Tên các mức',
  guide: 'Mẹo học',
  vocab: 'Từ vựng',
  sentences: 'Câu',
  dialogues: 'Hội thoại',
  story: 'Truyện đọc',
};

export function whereIs(path: string): string {
  const root = path.split(/[[.\s]/)[0];
  const label = WHERE[root] ?? root;
  const row = path.match(/\[(\d+)\]/);
  return row ? `${label} · dòng ${Number(row[1]) + 1}` : label;
}

export interface NavLink {
  href: string;
  label: string;
  hint: string;
  icon: IconName;
}

/**
 * The sidebar, grouped by the job it belongs to. A teacher opens "Nội dung" every day; billing and
 * history are read less often, so they sit further down instead of competing for the same attention.
 * Every item is a word, never a noun the operator has to decode.
 */
export const NAV_GROUPS: { title: string; links: NavLink[] }[] = [
  {
    title: 'Hôm nay',
    links: [
      { href: '/', label: 'Tổng quan', hint: 'Số liệu người học và việc cần làm hôm nay', icon: 'overview' },
    ],
  },
  {
    title: 'Nội dung',
    links: [
      { href: '/lessons', label: 'Bài học', hint: 'Tìm, sửa và xem trước từng bài', icon: 'lessons' },
      { href: '/builds', label: 'Xuất bản', hint: 'Kiểm tra rồi đưa bài lên app', icon: 'publish' },
      { href: '/courses', label: 'Tất cả khóa học', hint: 'Mở khóa khác nếu có', icon: 'courses' },
    ],
  },
  {
    title: 'Người dùng',
    links: [
      { href: '/users', label: 'Người học', hint: 'Tìm tài khoản, xem tiến độ, khóa khi cần', icon: 'learners' },
      { href: '/billing', label: 'Gói & thanh toán', hint: 'Ai đang dùng gói trả phí', icon: 'billing' },
      { href: '/ops/inbox', label: 'Thư của người học', hint: 'Góp ý và báo cáo còn đang mở', icon: 'inbox' },
    ],
  },
  {
    title: 'Quản trị',
    links: [
      { href: '/ops/audit', label: 'Lịch sử hoạt động', hint: 'Ai làm gì, lúc nào', icon: 'audit' },
      { href: '/ops/access', label: 'Thành viên & quyền', hint: 'Ai được phép soạn bài', icon: 'access' },
    ],
  },
];

export const ALL_NAV: NavLink[] = NAV_GROUPS.flatMap((group) => group.links);
