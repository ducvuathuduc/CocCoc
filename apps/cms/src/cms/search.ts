import type { UnitRecord } from './types';

/**
 * A course is 16 units of rows nobody can scroll through at once, so the first question an author asks
 * is not "edit this" but "is this already taught, and where". This module reads only drafts: it never
 * touches a build, because what the app ships is the media report's business, not the search box's.
 */
export type SearchList = 'vocab' | 'sentences' | 'dialogues' | 'story' | 'unit';

/** Where the editor keeps the text, and what the column is called there. */
export const LIST_LABEL: Record<SearchList, string> = {
  vocab: 'Từ vựng',
  sentences: 'Câu',
  dialogues: 'Hội thoại',
  story: 'Truyện',
  unit: 'Unit',
};

/** The tab key of `unit-editor.tsx` that shows this list. */
export const TAB_KEY: Record<SearchList, string> = {
  vocab: 'vocab',
  sentences: 'sentences',
  dialogues: 'dialogues',
  story: 'story',
  unit: 'basics',
};

export interface SearchEntry {
  unitId: string;
  order: number;
  unitTitle: string;
  list: SearchList;
  listLabel: string;
  /** Editor tab that shows this text; `basics` for the unit's own fields. */
  tab: string;
  /** Zero-based row in that table, or `null` for a whole-unit or block field. */
  row: number | null;
  /** Column name as the editor prints it. */
  field: string;
  text: string;
}

export interface SearchHit extends SearchEntry {
  /** Start and end inside `text`, so the UI can mark what matched. */
  start: number;
  end: number;
}

/**
 * Search is lowercase and dấu-free — `chao hoi` has to find `Chào hỏi`, and typing the dấu is not
 * optional for a phone keyboard. Spaces collapse the same way on both sides, so a draft with a stray
 * double space is still found by a normal query. `fold` keeps the source index of every character it
 * emits, so the highlight is cut out of the text *as authored* rather than out of a folded copy.
 *
 * `đ` needs its own rule: unlike every other Vietnamese letter it has no NFD decomposition, so
 * `normalize` leaves it intact and `gia dinh` would silently fail to find `Gia đình`.
 */
export function fold(text: string): { keys: string; at: number[] } {
  let keys = '';
  const at: number[] = [];
  for (let i = 0; i < text.length; i++) {
    const flat = text[i]
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/\u0111/g, 'd');
    for (const ch of flat) {
      if (ch === ' ' && (keys === '' || keys.endsWith(' '))) continue;
      keys += ch;
      at.push(i);
    }
  }
  return { keys, at };
}

export const foldKey = (text: string): string => fold(text).keys.replace(/\s+$/, '');

/** First occurrence of `needle` in `haystack`, ignoring case and dấu; `null` when absent. */
export function matchRange(
  haystack: string,
  needle: string,
): { start: number; end: number } | null {
  const key = foldKey(needle);
  if (!key) return null;
  const { keys, at } = fold(haystack);
  const found = keys.indexOf(key);
  if (found < 0) return null;
  return { start: at[found], end: at[found + key.length - 1] + 1 };
}

/** Every searchable string of one draft, with the place the editor shows it in. */
export function unitEntries(unit: UnitRecord): SearchEntry[] {
  const { unitId, order } = unit;
  const draft = unit.draft;
  const out: SearchEntry[] = [];
  const push = (list: SearchList, row: number | null, field: string, text: string) => {
    if (!text.trim()) return;
    out.push({
      unitId,
      order,
      unitTitle: draft.title,
      list,
      listLabel: LIST_LABEL[list],
      tab: TAB_KEY[list],
      row,
      field,
      text,
    });
  };

  push('unit', null, 'tên unit', draft.title);
  push('unit', null, 'chủ đề', draft.theme);
  push('unit', null, 'hướng dẫn', draft.guide);
  draft.levels.forEach((level) => push('unit', null, 'mức', level));

  draft.vocab.forEach((row, i) => {
    push('vocab', i, 'từ', row.en);
    row.enAlts.forEach((alt) => push('vocab', i, 'cách nói khác', alt));
    row.forms.forEach((form) => push('vocab', i, 'forms', form));
    push('vocab', i, 'nghĩa', row.vi);
    row.viAlts.forEach((alt) => push('vocab', i, 'nghĩa khác', alt));
    push('vocab', i, 'id', row.id);
  });

  draft.sentences.forEach((row, i) => {
    push('sentences', i, 'câu', row.en);
    row.enAlts.forEach((alt) => push('sentences', i, 'cách nói khác', alt));
    push('sentences', i, 'nghĩa', row.vi);
    row.viAlts.forEach((alt) => push('sentences', i, 'nghĩa khác', alt));
  });

  draft.dialogues.forEach((row, i) => {
    push('dialogues', i, 'lời thoại', row.line);
    push('dialogues', i, 'câu trả lời', row.reply);
    row.replyAlts.forEach((alt) => push('dialogues', i, 'trả lời khác', alt));
    push('dialogues', i, 'nghĩa', row.vi);
  });

  push('story', null, 'tiêu đề truyện', draft.story.title);
  push('story', null, 'đoạn truyện', draft.story.passage);
  draft.story.questions.forEach((row, i) => {
    push('story', i, 'câu hỏi', row.q);
    push('story', i, 'đáp án', row.correct);
    row.wrongs.forEach((alt) => push('story', i, 'đáp án sai', alt));
  });

  return out;
}

export function courseEntries(units: UnitRecord[]): SearchEntry[] {
  return units.flatMap((unit) => unitEntries(unit));
}

/** Hits come back in reading order: first unit first, then the table, then the row. */
export function searchEntries(entries: SearchEntry[], query: string, limit = 200): SearchHit[] {
  const key = foldKey(query);
  if (!key) return [];
  const hits: SearchHit[] = [];
  for (const entry of entries) {
    const range = matchRange(entry.text, key);
    if (!range) continue;
    hits.push({ ...entry, ...range });
    if (hits.length >= limit) return hits;
  }
  return hits;
}

export interface RepeatRow {
  unitId: string;
  order: number;
  unitTitle: string;
  /** Row in that unit's table, zero-based. */
  index: number;
  /** The text as authored, which can differ between rows of the same group ("Hi" vs "hi"). */
  text: string;
}

export interface RepeatGroup {
  /** `word` for a vocabulary headword, `sentence` for a sentence in English. */
  kind: 'word' | 'sentence';
  key: string;
  rows: RepeatRow[];
  /** How many distinct units teach it — the number that makes a repeat worth reading. */
  unitCount: number;
}

function repeatGroups(
  units: UnitRecord[],
  kind: RepeatGroup['kind'],
  read: (unit: UnitRecord) => { index: number; text: string }[],
  acrossUnits: boolean,
): RepeatGroup[] {
  const byKey = new Map<string, RepeatGroup>();
  for (const unit of units) {
    for (const row of read(unit)) {
      const key = foldKey(row.text);
      if (!key) continue;
      const group = byKey.get(key) ?? { kind, key, rows: [] as RepeatRow[], unitCount: 0 };
      group.rows.push({
        unitId: unit.unitId,
        order: unit.order,
        unitTitle: unit.draft.title,
        index: row.index,
        text: row.text,
      });
      byKey.set(key, group);
    }
  }
  return [...byKey.values()]
    .map((group) => ({ ...group, unitCount: new Set(group.rows.map((r) => r.unitId)).size }))
    .filter((group) => (acrossUnits ? group.unitCount > 1 : group.rows.length > 1))
    .sort(
      (a, b) =>
        b.unitCount - a.unitCount || b.rows.length - a.rows.length || a.key.localeCompare(b.key),
    );
}

/** Headwords taught in more than one unit — the same word is only introduced once for the learner. */
export const repeatedWords = (units: UnitRecord[]): RepeatGroup[] =>
  repeatGroups(
    units,
    'word',
    (unit) => unit.draft.vocab.map((row, index) => ({ index, text: row.en })),
    true,
  );

export const repeatedSentences = (units: UnitRecord[]): RepeatGroup[] =>
  repeatGroups(
    units,
    'sentence',
    (unit) => unit.draft.sentences.map((row, index) => ({ index, text: row.en })),
    false,
  );

/**
 * A headword can also repeat inside one unit, which the app never sees twice: `build-course.mjs` keys
 * words by id, and the placement match drill drops exact duplicates by design. Reported apart from
 * `repeatedWords` because the fix is different — merge the rows, not reassign the unit.
 */
export function repeatsInsideUnit(units: UnitRecord[]): RepeatGroup[] {
  const out: RepeatGroup[] = [];
  for (const unit of units) {
    const byKey = new Map<string, RepeatGroup>();
    unit.draft.vocab.forEach((row, index) => {
      const key = foldKey(row.en);
      if (!key) return;
      const group = byKey.get(key) ?? { kind: 'word', key, rows: [], unitCount: 1 };
      group.rows.push({
        unitId: unit.unitId,
        order: unit.order,
        unitTitle: unit.draft.title,
        index,
        text: row.en,
      });
      byKey.set(key, group);
    });
    for (const group of byKey.values()) if (group.rows.length > 1) out.push(group);
  }
  return out.sort((a, b) => b.rows.length - a.rows.length || a.key.localeCompare(b.key));
}
