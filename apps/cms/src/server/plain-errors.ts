// What a failed content step says to an author. The repo's own tools fail with stack traces, issue
// codes and file names; none of that helps someone writing a lesson, so each known failure becomes a
// sentence that names what to do. The raw output stays in the run record (and the server console)
// for whoever debugs it, and is never put in front of the author.

export type GateLabel = 'build-course' | 'lint-course' | 'check-content';

const GENERIC: Record<GateLabel, string> = {
  'build-course':
    'Máy chưa dựng được bài từ nội dung hiện có. Thường là một bài còn thiếu từ, câu hoặc câu hỏi truyện.',
  'lint-course': 'Nội dung có chỗ chưa đúng quy tắc. Mở từng bài và sửa các dòng được đánh dấu.',
  'check-content':
    'Bản dựng chưa qua bước kiểm tra cuối. Xem trang “Âm thanh và ảnh” để biết còn thiếu gì.',
};

const rules: { gate: GateLabel; test: RegExp; say: string }[] = [
  {
    gate: 'build-course',
    test: /reading 'en'|reading 'vi'|orderAmbiguous|sentences?\b.*(empty|none)/i,
    say: 'Một bài chưa có câu nào, hoặc có quá ít câu để tạo bài tập. Mở bài đó, thêm câu ở tab Câu rồi lưu lại.',
  },
  {
    gate: 'build-course',
    test: /vocabularyId|reading 'en'.*vocab|picked\[0\]/i,
    say: 'Một bài chưa đủ từ vựng để tạo bài tập. Mở bài đó, thêm từ ở tab Từ vựng rồi lưu lại.',
  },
  {
    gate: 'build-course',
    test: /questions?|story/i,
    say: 'Truyện của một bài chưa có đủ câu hỏi. Mở tab Truyện và thêm cho đủ 6 câu.',
  },
  {
    gate: 'build-course',
    test: /MISSING_TYPE_(\w+)/,
    say: 'Khóa còn thiếu một dạng bài tập. Thêm từ có ảnh, hội thoại hoặc câu cho đủ để máy tạo mọi dạng.',
  },
  {
    gate: 'build-course',
    test: /section|unassigned|theme/i,
    say: 'Có bài chưa nằm trong phần học nào. Vào “Cấu trúc & thông tin” và xếp bài vào một phần.',
  },
  {
    gate: 'check-content',
    test: /missing media|thiếu|sha256 mismatch|byte count|placeholder|MEDIA_/i,
    say: 'Âm thanh hoặc ảnh của khóa chưa đủ. Mở “Âm thanh và ảnh” để xem còn thiếu file nào.',
  },
];

/** One sentence for a failed content step. */
export function explainGateFailure(gate: GateLabel, raw: string): string {
  const hit = rules.find((rule) => rule.gate === gate && rule.test.test(raw));
  return `Chưa qua bước kiểm tra. ${hit?.say ?? GENERIC[gate]}`;
}

const publishRules: { test: RegExp; say: string }[] = [
  {
    test: /MEDIA_|missing media|sha256 mismatch/i,
    say: 'Âm thanh hoặc ảnh của bản này chưa đủ trên máy chủ nên chưa cho app nhận. Hoàn tất các file còn thiếu rồi thử lại.',
  },
  {
    test: /VERSION_EXISTS|REVISION_CONFLICT|already published/i,
    say: 'Số bản này đã được đưa lên app trước đó. Đổi sang số bản mới (ví dụ v3) ở “Cấu trúc & thông tin”, kiểm tra lại rồi xuất bản.',
  },
  {
    test: /STORAGE_UNAVAILABLE|ECONN|ETIMEDOUT|fetch failed|timeout/i,
    say: 'Máy chủ dữ liệu đang không trả lời. Thử lại sau ít phút.',
  },
  {
    test: /MAINTAINER_REQUIRED|\b401\b|\b403\b|forbidden|unauthori[sz]ed/i,
    say: 'Tài khoản này chưa được phép xuất bản.',
  },
];

/** One sentence for a failed publish. */
export function explainPublishFailure(raw: string): string {
  const hit = publishRules.find((rule) => rule.test.test(raw));
  return `Chưa cho app nhận bản được. ${hit?.say ?? 'Thử lại sau; nếu vẫn lỗi, báo người quản trị.'}`;
}
