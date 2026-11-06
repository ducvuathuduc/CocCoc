import { LIST_LABEL, TAB_KEY, foldKey, matchRange, type SearchList } from './search';
import type { DialogueRow, SentenceRow, StoryQuestionRow, UnitDraft, UnitRecord, VocabRow } from './types';

/**
 * Search answers "where is this text"; this module answers "and may I write it back everywhere". It walks
 * the same columns `unitEntries` walks — the harness compares the two lists so a column cannot become
 * searchable without saying whether it is replaceable — and it replaces through the folded match the search
 * box uses, so what the preview marks is exactly what the query found.
 *
 * Two columns are deliberately read-only. `id` is the key sentences, dialogues, story questions and media
 * files point at, and `chủ đề` is the key the section panel points at; rewriting either by bulk find/replace
 * would leave the rest of the course referring to something that no longer exists. The plan still reports
 * those matches so the admin learns the rule instead of wondering why nothing changed.
 */
export interface ReplaceCell {
  /** Row in that table, or `null` for a whole-unit or story-block field. */
  row: number | null;
  /** Index inside a list column (`cách nói khác`, `forms`, `đáp án sai`) or inside `levels`. */
  alt: number | null;
  text: string;
  /** Pure on purpose: the plan stores coordinates, and the write is replayed on whatever draft is live when the admin confirms. */
  write: (draft: UnitDraft, text: string) => UnitDraft;
}

export interface ReplaceColumn {
  list: SearchList;
  /** The label `unitEntries` prints for this column. */
  field: string;
  editable: boolean;
  /** Shown when a match exists here but this module refuses to rewrite it. */
  why?: string;
  cells: (draft: UnitDraft) => ReplaceCell[];
}

const fieldCell = (
  read: (draft: UnitDraft) => string,
  rebuild: (draft: UnitDraft, text: string) => UnitDraft,
): ((draft: UnitDraft) => ReplaceCell[]) => (draft) => [
  { row: null, alt: null, text: read(draft), write: (live, text) => rebuild(live, text) },
];

const listCells = <R>(
  rows: (draft: UnitDraft) => R[],
  read: (row: R) => string,
  patch: (row: R, text: string) => R,
  rebuild: (draft: UnitDraft, rows: R[]) => UnitDraft,
): ((draft: UnitDraft) => ReplaceCell[]) => (draft) =>
  rows(draft).map((row, index) => ({
    row: index,
    alt: null as number | null,
    text: read(row),
    write: (live: UnitDraft, text: string) =>
      rebuild(
        live,
        rows(live).map((other, j) => (j === index ? patch(other, text) : other)),
      ),
  }));

const arrayCells = <R>(
  rows: (draft: UnitDraft) => R[],
  read: (row: R) => string[],
  patch: (row: R, alt: number, text: string) => R,
  rebuild: (draft: UnitDraft, rows: R[]) => UnitDraft,
): ((draft: UnitDraft) => ReplaceCell[]) => (draft) =>
  rows(draft).flatMap((row, index) =>
    read(row).map((text, alt) => ({
      row: index,
      alt,
      text,
      write: (live: UnitDraft, next: string) =>
        rebuild(
          live,
          rows(live).map((other, j) => (j === index ? patch(other, alt, next) : other)),
        ),
    })),
  );

const unitArrayCells = (
  read: (draft: UnitDraft) => string[],
  rebuild: (draft: UnitDraft, values: string[]) => UnitDraft,
): ((draft: UnitDraft) => ReplaceCell[]) => (draft) =>
  read(draft).map((text, alt) => ({
    row: null,
    alt,
    text,
    write: (live: UnitDraft, next: string) =>
      rebuild(
        live,
        read(live).map((other, j) => (j === alt ? next : other)),
      ),
  }));

const withVocab = (draft: UnitDraft, vocab: VocabRow[]): UnitDraft => ({ ...draft, vocab });
const withSentences = (draft: UnitDraft, sentences: SentenceRow[]): UnitDraft => ({
  ...draft,
  sentences,
});
const withDialogues = (draft: UnitDraft, dialogues: DialogueRow[]): UnitDraft => ({
  ...draft,
  dialogues,
});
const withQuestions = (draft: UnitDraft, questions: StoryQuestionRow[]): UnitDraft => ({
  ...draft,
  story: { ...draft.story, questions },
});

/** Every column the search screen can show, in the order the editor shows them. */
export const replaceColumns = (): ReplaceColumn[] => [
  { list: 'unit', field: 'tên unit', editable: true, cells: fieldCell((d) => d.title, (d, t) => ({ ...d, title: t })) },
  {
    list: 'unit',
    field: 'chủ đề',
    editable: false,
    why: 'Chủ đề là khóa mà panel Cấu trúc khóa nối unit vào section — đổi nó ở đó, nếu không section sẽ liệt kê một theme không unit nào mang.',
    cells: fieldCell((d) => d.theme, (d, t) => ({ ...d, theme: t })),
  },
  { list: 'unit', field: 'hướng dẫn', editable: true, cells: fieldCell((d) => d.guide, (d, t) => ({ ...d, guide: t })) },
  {
    list: 'unit',
    field: 'mức',
    editable: true,
    cells: unitArrayCells(
      (d) => d.levels,
      (d, levels) => ({ ...d, levels }),
    ),
  },

  {
    list: 'vocab',
    field: 'từ',
    editable: true,
    cells: listCells(
      (d) => d.vocab,
      (r) => r.en,
      (r, t) => ({ ...r, en: t }),
      withVocab,
    ),
  },
  {
    list: 'vocab',
    field: 'cách nói khác',
    editable: true,
    cells: arrayCells(
      (d) => d.vocab,
      (r) => r.enAlts,
      (r, alt, t) => ({ ...r, enAlts: r.enAlts.map((x, j) => (j === alt ? t : x)) }),
      withVocab,
    ),
  },
  {
    list: 'vocab',
    field: 'forms',
    editable: true,
    cells: arrayCells(
      (d) => d.vocab,
      (r) => r.forms,
      (r, alt, t) => ({ ...r, forms: r.forms.map((x, j) => (j === alt ? t : x)) }),
      withVocab,
    ),
  },
  {
    list: 'vocab',
    field: 'nghĩa',
    editable: true,
    cells: listCells(
      (d) => d.vocab,
      (r) => r.vi,
      (r, t) => ({ ...r, vi: t }),
      withVocab,
    ),
  },
  {
    list: 'vocab',
    field: 'nghĩa khác',
    editable: true,
    cells: arrayCells(
      (d) => d.vocab,
      (r) => r.viAlts,
      (r, alt, t) => ({ ...r, viAlts: r.viAlts.map((x, j) => (j === alt ? t : x)) }),
      withVocab,
    ),
  },
  {
    list: 'vocab',
    field: 'id',
    editable: false,
    why: 'id là khóa mà câu, hội thoại, truyện và file media trỏ vào — đổi id phải làm trong editor để mọi tham chiếu đi cùng một lượt.',
    cells: listCells(
      (d) => d.vocab,
      (r) => r.id,
      (r, t) => ({ ...r, id: t }),
      withVocab,
    ),
  },

  {
    list: 'sentences',
    field: 'câu',
    editable: true,
    cells: listCells(
      (d) => d.sentences,
      (r) => r.en,
      (r, t) => ({ ...r, en: t }),
      withSentences,
    ),
  },
  {
    list: 'sentences',
    field: 'cách nói khác',
    editable: true,
    cells: arrayCells(
      (d) => d.sentences,
      (r) => r.enAlts,
      (r, alt, t) => ({ ...r, enAlts: r.enAlts.map((x, j) => (j === alt ? t : x)) }),
      withSentences,
    ),
  },
  {
    list: 'sentences',
    field: 'nghĩa',
    editable: true,
    cells: listCells(
      (d) => d.sentences,
      (r) => r.vi,
      (r, t) => ({ ...r, vi: t }),
      withSentences,
    ),
  },
  {
    list: 'sentences',
    field: 'nghĩa khác',
    editable: true,
    cells: arrayCells(
      (d) => d.sentences,
      (r) => r.viAlts,
      (r, alt, t) => ({ ...r, viAlts: r.viAlts.map((x, j) => (j === alt ? t : x)) }),
      withSentences,
    ),
  },

  {
    list: 'dialogues',
    field: 'lời thoại',
    editable: true,
    cells: listCells(
      (d) => d.dialogues,
      (r) => r.line,
      (r, t) => ({ ...r, line: t }),
      withDialogues,
    ),
  },
  {
    list: 'dialogues',
    field: 'câu trả lời',
    editable: true,
    cells: listCells(
      (d) => d.dialogues,
      (r) => r.reply,
      (r, t) => ({ ...r, reply: t }),
      withDialogues,
    ),
  },
  {
    list: 'dialogues',
    field: 'trả lời khác',
    editable: true,
    cells: arrayCells(
      (d) => d.dialogues,
      (r) => r.replyAlts,
      (r, alt, t) => ({ ...r, replyAlts: r.replyAlts.map((x, j) => (j === alt ? t : x)) }),
      withDialogues,
    ),
  },
  {
    list: 'dialogues',
    field: 'nghĩa',
    editable: true,
    cells: listCells(
      (d) => d.dialogues,
      (r) => r.vi,
      (r, t) => ({ ...r, vi: t }),
      withDialogues,
    ),
  },

  {
    list: 'story',
    field: 'tiêu đề truyện',
    editable: true,
    cells: fieldCell((d) => d.story.title, (d, t) => ({ ...d, story: { ...d.story, title: t } })),
  },
  {
    list: 'story',
    field: 'đoạn truyện',
    editable: true,
    cells: fieldCell((d) => d.story.passage, (d, t) => ({ ...d, story: { ...d.story, passage: t } })),
  },
  {
    list: 'story',
    field: 'câu hỏi',
    editable: true,
    cells: listCells(
      (d) => d.story.questions,
      (r) => r.q,
      (r, t) => ({ ...r, q: t }),
      withQuestions,
    ),
  },
  {
    list: 'story',
    field: 'đáp án',
    editable: true,
    cells: listCells(
      (d) => d.story.questions,
      (r) => r.correct,
      (r, t) => ({ ...r, correct: t }),
      withQuestions,
    ),
  },
  {
    list: 'story',
    field: 'đáp án sai',
    editable: true,
    cells: arrayCells(
      (d) => d.story.questions,
      (r) => r.wrongs,
      (r, alt, t) => ({ ...r, wrongs: r.wrongs.map((x, j) => (j === alt ? t : x)) }),
      withQuestions,
    ),
  },
];

export interface ReplaceTarget {
  list: SearchList;
  field: string;
}

export interface ReplaceRequest {
  find: string;
  to: string;
  targets: ReplaceTarget[];
}

export interface ReplaceEdit {
  unitId: string;
  order: number;
  unitTitle: string;
  list: SearchList;
  listLabel: string;
  /** The editor tab that shows the row, so the preview can link straight into it. */
  tab: string;
  row: number | null;
  alt: number | null;
  field: string;
  before: string;
  after: string;
  /** How many occurrences of `find` this one cell held. */
  count: number;
}

export interface ReplaceSkipped {
  list: SearchList;
  field: string;
  reason: string;
  cells: number;
  matches: number;
}

export interface ReplacePlan {
  find: string;
  to: string;
  /** Cells the search actually looked at, so "nothing matched" can say what it covered. */
  scanned: number;
  edits: ReplaceEdit[];
  unitIds: string[];
  rows: number;
  matches: number;
  skipped: ReplaceSkipped[];
}

/**
 * Every occurrence, matched the way the search box matches (lowercase, dấu-free) and written back exactly as
 * the admin typed it. The scan always moves past the span it replaced, so `find` inside `to` — turning
 * "friend" into "best friend" — cannot loop.
 */
function replaceAll(text: string, find: string, to: string): { text: string; count: number } {
  if (!foldKey(find)) return { text, count: 0 };
  let out = '';
  let rest = text;
  let count = 0;
  while (count < 500) {
    const range = matchRange(rest, find);
    if (!range) break;
    out += rest.slice(0, range.start) + to;
    rest = rest.slice(range.end);
    count += 1;
  }
  return { text: out + rest, count };
}

const wanted = (targets: ReplaceTarget[], column: ReplaceColumn): boolean =>
  targets.some((t) => t.list === column.list && t.field === column.field);

/** What would change, unit by unit and row by row — computed without touching the store. */
export function planReplace(units: UnitRecord[], request: ReplaceRequest): ReplacePlan {
  const edits: ReplaceEdit[] = [];
  const skipped = new Map<string, ReplaceSkipped>();
  let scanned = 0;
  for (const unit of units) {
    for (const column of replaceColumns()) {
      if (!wanted(request.targets, column)) continue;
      for (const cell of column.cells(unit.draft)) {
        scanned += 1;
        const { text, count } = replaceAll(cell.text, request.find, request.to);
        if (!count || text === cell.text) continue;
        if (!column.editable) {
          const key = `${column.list}.${column.field}`;
          const hit = skipped.get(key) ?? {
            list: column.list,
            field: column.field,
            reason: column.why ?? '',
            cells: 0,
            matches: 0,
          };
          hit.cells += 1;
          hit.matches += count;
          skipped.set(key, hit);
          continue;
        }
        edits.push({
          unitId: unit.unitId,
          order: unit.order,
          unitTitle: unit.draft.title,
          list: column.list,
          listLabel: LIST_LABEL[column.list],
          tab: TAB_KEY[column.list],
          row: cell.row,
          alt: cell.alt,
          field: column.field,
          before: cell.text,
          after: text,
          count,
        });
      }
    }
  }
  edits.sort(
    (a, b) =>
      a.order - b.order ||
      (a.row ?? -1) - (b.row ?? -1) ||
      (a.alt ?? -1) - (b.alt ?? -1) ||
      a.field.localeCompare(b.field),
  );
  return {
    find: request.find,
    to: request.to,
    scanned,
    edits,
    unitIds: [...new Set(edits.map((e) => e.unitId))],
    rows: edits.length,
    matches: edits.reduce((sum, e) => sum + e.count, 0),
    skipped: [...skipped.values()],
  };
}

export interface ReplaceDrift {
  list: SearchList;
  field: string;
  row: number | null;
  expected: string;
  found: string;
}

export interface ReplaceApplyResult {
  draft: UnitDraft;
  applied: number;
  /** Cells whose live text is no longer the text the preview showed — someone edited this unit in the meantime. */
  drift: ReplaceDrift[];
}

/**
 * Replays a plan's edits for one unit onto the draft that is live now. It re-reads each cell instead of
 * reusing the previewed string, so an edit made in another window between preview and confirm stops the batch
 * instead of being silently overwritten.
 */
export function applyReplace(draft: UnitDraft, edits: ReplaceEdit[]): ReplaceApplyResult {
  const columns = replaceColumns();
  let next = draft;
  let applied = 0;
  const drift: ReplaceDrift[] = [];
  for (const edit of edits) {
    const column = columns.find((c) => c.list === edit.list && c.field === edit.field);
    if (!column?.editable) continue;
    const cell = column.cells(next).find((c) => c.row === edit.row && c.alt === edit.alt);
    if (!cell || cell.text !== edit.before) {
      drift.push({
        list: edit.list,
        field: edit.field,
        row: edit.row,
        expected: edit.before,
        found: cell?.text ?? '(dòng không còn tồn tại)',
      });
      continue;
    }
    next = cell.write(next, edit.after);
    applied += 1;
  }
  return { draft: next, applied, drift };
}

export interface ReplaceChoiceGroup {
  list: SearchList;
  listLabel: string;
  fields: { field: string; editable: boolean; why?: string }[];
}

/** The columns a screen can offer as checkboxes, grouped by the table they belong to. */
export function replaceChoices(): ReplaceChoiceGroup[] {
  const out: ReplaceChoiceGroup[] = [];
  for (const column of replaceColumns()) {
    const group = out.find((g) => g.list === column.list);
    if (group) group.fields.push({ field: column.field, editable: column.editable, why: column.why });
    else
      out.push({
        list: column.list,
        listLabel: LIST_LABEL[column.list],
        fields: [{ field: column.field, editable: column.editable, why: column.why }],
      });
  }
  return out;
}
