import type { UnitDraft } from './types';

export interface ContentIssue {
  level: 'error' | 'warning';
  path: string;
  message: string;
}

const MAX_TEXT = 1024;

export function lintUnit(unit: UnitDraft): ContentIssue[] {
  const issues: ContentIssue[] = [];
  const push = (level: ContentIssue['level'], path: string, message: string) =>
    issues.push({ level, path, message });

  if (!unit.theme)
    push('error', 'theme', 'Bài chưa có Chủ đề — ô này quyết định bài nằm trong phần học nào.');
  if (!unit.title.trim())
    push('error', 'title', 'Bài chưa có tên — người học sẽ không biết mình đang học bài nào.');
  if (unit.levels.length !== 5)
    push('error', 'levels', `Bài cần đúng 5 tên mức độ, hiện có ${unit.levels.length}.`);
  unit.levels.forEach((l, i) => {
    if (!l.trim()) push('error', `levels[${i}]`, `Tên mức độ ${i + 1} đang trống.`);
  });
  if (!unit.guide.trim())
    push(
      'warning',
      'guide',
      'Bài chưa có mẹo học — người học sẽ vào thẳng bài tập mà không có ai dẫn.',
    );

  if (!unit.vocab.length) push('error', 'vocab', 'Bài chưa có từ nào — thêm từ ở tab Từ vựng.');
  const seenEn = new Map<string, number>();
  unit.vocab.forEach((v, i) => {
    const at = `vocab[${i}] (${v.en || '?'})`;
    if (!v.en.trim() || !v.vi.trim())
      push('error', at, 'Một từ cần đủ cả tiếng Anh và nghĩa tiếng Việt.');
    if (v.level < 1 || v.level > 5) push('error', at, 'Cấp phải là số từ 1 đến 5.');
    const key = v.en.toLowerCase();
    const previous = seenEn.get(key);
    if (previous !== undefined)
      push('error', at, `Trùng từ với dòng ${previous + 1} trong cùng bài.`);
    else seenEn.set(key, i);
    if (!v.id)
      push('error', at, 'Từ này không tạo được mã để app tra cứu — sửa lại cách viết tiếng Anh.');
    if (v.forms.some((f) => !f.trim())) push('error', at, 'Danh sách các dạng từ có ô trống.');
  });

  const vocabIds = new Set(unit.vocab.map((v) => v.id));
  if (vocabIds.size !== unit.vocab.length)
    push(
      'error',
      'vocab',
      'Hai từ khác nhau đang dùng chung một mã — viết lại một trong hai từ cho khác.',
    );

  const seenSentence = new Map<string, number>();
  unit.sentences.forEach((s, i) => {
    const at = `sentences[${i}]`;
    if (!s.en.trim() || !s.vi.trim())
      push('error', at, 'Một câu cần đủ cả câu tiếng Anh và nghĩa tiếng Việt.');
    if (/[<>{}|]/.test(s.en))
      push('warning', at, 'Câu có ký tự lạ (< > { } |) — app có thể hiển thị sai.');
    const key = s.en.toLowerCase();
    const previous = seenSentence.get(key);
    if (previous !== undefined) push('error', at, `Trùng câu với dòng ${previous + 1}.`);
    else seenSentence.set(key, i);
  });

  unit.dialogues.forEach((d, i) => {
    const at = `dialogues[${i}]`;
    if (!d.line.trim() || !d.reply.trim() || !d.vi.trim())
      push(
        'error',
        at,
        'Một lượt hội thoại cần đủ: người kia nói gì, bạn học đáp gì, và nghĩa tiếng Việt.',
      );
  });

  if (!unit.story.title.trim()) push('warning', 'story.title', 'Đoạn truyện chưa có tên.');
  if (!unit.story.passage.trim()) push('warning', 'story.passage', 'Đoạn truyện chưa có nội dung.');
  if (unit.story.passage.length > 4096)
    push(
      'error',
      'story.passage',
      `Đoạn truyện dài ${unit.story.passage.length} ký tự, vượt mức 4096 — hãy cắt cho ngắn lại.`,
    );
  if (unit.story.questions.length < 6)
    push(
      'warning',
      'story.questions',
      `Cần 6 câu hỏi cho đoạn truyện, hiện có ${unit.story.questions.length}.`,
    );
  unit.story.questions.forEach((q, i) => {
    const at = `story.questions[${i}]`;
    if (!q.q.trim() || !q.correct.trim())
      push('error', at, 'Câu hỏi chưa có nội dung hoặc chưa có đáp án đúng.');
    if (q.wrongs.length < 2) push('error', at, 'Câu hỏi cần thêm ít nhất 2 đáp án sai.');
    if (q.wrongs.some((w) => w.toLowerCase() === q.correct.toLowerCase()))
      push('error', at, 'Có đáp án sai trùng với đáp án đúng.');
  });

  for (const [path, value] of [
    ['title', unit.title],
    ['guide', unit.guide],
  ] as const) {
    if (value.length > MAX_TEXT)
      push(
        'warning',
        path,
        `Dài ${value.length} ký tự, vượt mức ${MAX_TEXT} ký tự — app dễ bị cắt mất phần cuối.`,
      );
  }

  return issues;
}

export function hasErrors(issues: ContentIssue[]): boolean {
  return issues.some((i) => i.level === 'error');
}
