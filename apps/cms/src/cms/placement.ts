import type { SentenceRow, StoryQuestionRow, UnitDraft, VocabRow } from './types';

/**
 * The placement test is the one lesson the CMS cannot edit: `build-course.mjs:1005-1028` builds it from
 * ten hard-coded positions inside the *first unit*, so the rows it reads move whenever that unit is
 * reordered and vanish whenever it is shortened. This module mirrors those ten slots on purpose, and
 * `scripts/placement-check.mjs` fails if the mirror and the last build ever disagree.
 */
export type PlacementDrill =
  | 'choice'
  | 'imageChoice'
  | 'textTranslation'
  | 'wordBank'
  | 'fillBlank'
  | 'matchPairs'
  | 'sentenceOrder'
  | 'storyQuestion';

/** Which authored list of the first unit a slot reads. */
export type PlacementList = 'vocab' | 'sentences' | 'story';

export interface PlacementRead {
  list: PlacementList;
  /** Zero-based position the generator indexes into. */
  index: number;
  /** Rows that list must still hold — after the picture filter, for item 10 — to get past this item. */
  needed: number;
  /** How the panel names the list, in Vietnamese. */
  listLabel: string;
  /** True for the slot that counts only vocabulary rows flagged with a picture. */
  picturesOnly: boolean;
}

export interface PlacementItem {
  /** `placement-eNN`, the id the app receives. */
  id: string;
  item: number;
  drill: PlacementDrill;
  /** What the learner has to do, in Vietnamese. */
  question: string;
  reads: PlacementRead;
  /** False when the row is gone: `build-course.mjs` throws on this draft, so the build stops. */
  present: boolean;
  /** The row the slot reads right now, empty when it is gone. */
  label: string;
  /** Words the built item will carry in `vocabularyIds`; empty when the generator derives them from text. */
  vocabularyIds: string[];
  /** The words the generator prints into the prompt, used to tell a stale build from a fresh one. */
  marker: string;
  /** Set when the picture gate changed this item's shape, or when the drill would ship degenerate. */
  note: string;
}

/** One row of the built `bundles/placement.json`, as far as the comparison needs it. */
export interface BuiltPlacementItem {
  id: string;
  type: string;
  prompt: string;
  vocabularyIds: string[];
}

/** `same` — the shipped build already asks what this draft would produce. */
export type PlacementState = 'same' | 'changed' | 'unknown';

interface Slot {
  drill: PlacementDrill;
  question: string;
  list: PlacementList;
  index: number;
  /** Which field of the row lands in the prompt; `null` when the generator writes a fixed prompt. */
  print: 'en' | 'vi' | 'q' | null;
  /** The item asks about exactly this vocabulary row, so its word id is predictable. */
  singleWord?: boolean;
  /** Read the `img`-flagged vocabulary rows instead of all of them (`build-course.mjs:1024`). */
  picturesOnly?: boolean;
}

const LIST_LABEL: Record<PlacementList, string> = {
  vocab: 'từ vựng',
  sentences: 'câu',
  story: 'câu hỏi truyện',
};

/** Items 1-9, in the order `build-course.mjs:1011-1023` pushes them onto the test. */
const SLOTS: Slot[] = [
  { drill: 'choice', question: 'Chọn nghĩa tiếng Việt của từ', list: 'vocab', index: 3, print: 'en', singleWord: true },
  { drill: 'textTranslation', question: 'Viết câu tiếng Anh tương ứng', list: 'sentences', index: 4, print: 'vi' },
  { drill: 'wordBank', question: 'Dịch câu bằng cách chọn từ', list: 'sentences', index: 9, print: 'vi' },
  { drill: 'fillBlank', question: 'Điền từ còn thiếu vào chỗ trống', list: 'sentences', index: 13, print: 'vi' },
  { drill: 'matchPairs', question: 'Nối các cặp từ tương ứng', list: 'vocab', index: 8, print: null },
  { drill: 'sentenceOrder', question: 'Sắp xếp từ thành câu', list: 'sentences', index: 17, print: 'vi' },
  { drill: 'choice', question: 'Chọn từ tiếng Anh cho nghĩa', list: 'vocab', index: 14, print: 'vi', singleWord: true },
  { drill: 'textTranslation', question: 'Viết câu tiếng Anh tương ứng', list: 'sentences', index: 21, print: 'vi' },
  { drill: 'storyQuestion', question: 'Đọc hiểu câu chuyện', list: 'story', index: 2, print: 'q' },
];

/** Item 10 with four pictures available, and the text choice it degrades into without them. */
const PICTURE_SLOT: Slot = {
  drill: 'imageChoice',
  question: 'Chọn ảnh đúng với nghĩa',
  list: 'vocab',
  index: 1,
  print: 'vi',
  singleWord: true,
  picturesOnly: true,
};

const CHOICE_FALLBACK: Slot = {
  drill: 'choice',
  question: 'Chọn từ tiếng Anh cho nghĩa',
  list: 'vocab',
  index: 6,
  print: 'vi',
  singleWord: true,
};

type AnyRow = VocabRow | SentenceRow | StoryQuestionRow;

function rowsOf(draft: UnitDraft, slot: Slot): AnyRow[] {
  if (slot.list === 'sentences') return draft.sentences;
  if (slot.list === 'story') return draft.story.questions;
  // `labelOf` reads `q` off story rows and `en`/`vi` off the others, so one array type has to cover
  // three authored shapes; the slot's own `list` is what guarantees the shape it indexes.
  return slot.picturesOnly ? pictureRows(draft.vocab) : draft.vocab;
}

/** Story questions carry `q`/`correct` instead of `en`/`vi`, so fields are read by name. */
function textField(row: AnyRow, key: 'en' | 'vi' | 'q' | 'correct'): string {
  if (key === 'q') return 'q' in row ? row.q : '';
  if (key === 'correct') return 'correct' in row ? row.correct : '';
  if (key === 'en') return 'en' in row ? row.en : '';
  return 'vi' in row ? row.vi : '';
}

function labelOf(list: PlacementList, row: AnyRow): string {
  return list === 'story'
    ? `"${textField(row, 'q')}" — đáp án "${textField(row, 'correct')}"`
    : `"${textField(row, 'en')}" → "${textField(row, 'vi')}"`;
}

const pictureRows = (rows: VocabRow[]): VocabRow[] => rows.filter((row) => row.img);

/** The positions item 10 counts when it walks only the picture-flagged rows. */
function pictureIndexes(rows: VocabRow[]): number[] {
  const out: number[] = [];
  rows.forEach((row, index) => {
    if (row.img) out.push(index);
  });
  return out;
}

/** `build-course.mjs:347-357`: unique on both sides of the pair, at most five pairs. */
function matchPairIndexes(rows: VocabRow[], from: number): number[] {
  const seenEn = new Set<string>();
  const seenVi = new Set<string>();
  const picked: number[] = [];
  rows.forEach((row, index) => {
    if (index < from || picked.length === 5) return;
    if (seenEn.has(row.en.toLowerCase()) || seenVi.has(row.vi.toLowerCase())) return;
    seenEn.add(row.en.toLowerCase());
    seenVi.add(row.vi.toLowerCase());
    picked.push(index);
  });
  return picked;
}

const matchPairRows = (rows: VocabRow[], from: number): VocabRow[] =>
  matchPairIndexes(rows, from).map((index) => rows[index]);

/**
 * The ten slots as the generator will take them: the nine fixed ones, then item 10, whose shape is
 * decided by `build-course.mjs:1024` at build time rather than by the slot table.
 */
function slotsFor(draft: UnitDraft): { slot: Slot; item: number }[] {
  const pictures = pictureRows(draft.vocab).length >= 4;
  return [
    ...SLOTS.map((slot, i) => ({ slot, item: i + 1 })),
    { slot: pictures ? PICTURE_SLOT : CHOICE_FALLBACK, item: 10 },
  ];
}

function buildItem(draft: UnitDraft, genUnitId: string, slot: Slot, item: number): PlacementItem {
  const rows = rowsOf(draft, slot);
  const row = rows[slot.index];
  const vocabularyId = slot.singleWord && row ? `${genUnitId}.${(row as VocabRow).id}` : '';
  return {
    id: `placement-e${String(item).padStart(2, '0')}`,
    item,
    drill: slot.drill,
    question: slot.question,
    reads: {
      list: slot.list,
      index: slot.index,
      needed: slot.index + 1,
      listLabel: LIST_LABEL[slot.list],
      picturesOnly: Boolean(slot.picturesOnly),
    },
    present: Boolean(row),
    label: row ? labelOf(slot.list, row) : '',
    vocabularyIds: vocabularyId ? [vocabularyId] : [],
    marker: row && slot.print ? textField(row, slot.print) : '',
    note: '',
  };
}

/**
 * The ten items the test will ask, read out of the draft the way the generator reads them.
 * `build-course.mjs:1024` gives item 10 as a picture drill only once four picture words exist; before
 * that it becomes a text choice of `vocab[6]`, which is why the slot table is not the whole story.
 */
export function placementItems(draft: UnitDraft, genUnitId: string): PlacementItem[] {
  const items = slotsFor(draft).map(({ slot, item }) => buildItem(draft, genUnitId, slot, item));

  const pairs = matchPairRows(draft.vocab, 8);
  const match = items[4];
  match.vocabularyIds = pairs.map((row) => `${genUnitId}.${row.id}`);
  if (pairs.length) match.label = `${pairs.length} cặp, từ "${pairs[0].en}" trở đi`;
  match.note = pairs.length === 1 ? 'Chỉ có một cặp để nối — bài nối sẽ vô nghĩa.' : '';

  const pictureCount = pictureRows(draft.vocab).length;
  items[9].note =
    pictureCount >= 4
      ? ''
      : `Mới có ${pictureCount} từ đánh dấu ảnh (cần 4), nên câu 10 là bài chọn chữ.`;
  return items;
}

/**
 * Compares one predicted item against the item the last build shipped. Words are compared by id where
 * the generator makes them predictable, otherwise by the text it prints into the prompt, so an edit
 * that leaves the row in place but changes its wording still counts as a change. A row that is gone
 * leaves nothing to compare, and `blockers` already says the build stops there.
 */
export function placementState(
  item: PlacementItem,
  built: BuiltPlacementItem | undefined,
): PlacementState {
  if (!item.present || !built) return 'unknown';
  if (built.type !== item.drill) return 'changed';
  if (item.marker && !built.prompt.includes(item.marker)) return 'changed';
  if (item.vocabularyIds.length && item.vocabularyIds.join(',') !== built.vocabularyIds.join(','))
    return 'changed';
  return 'same';
}

/** Why a row of the first unit carries a `#N` badge in the editor. */
export interface PlacementRowMark {
  item: number;
  drill: PlacementDrill;
  /** Text on the badge; the item number alone would not say which row the match drill starts at. */
  badge: string;
  /** Full explanation, shown as the badge's tooltip. */
  title: string;
  /** The row is reached through the picture count, so its own position does not decide it. */
  byPictureOrder: boolean;
  /** The match drill sweeps rows after its start row, so it marks several at once. */
  isPairRange: boolean;
}

export interface PlacementMarks {
  /** Keyed `${list}:${index}`, where `index` is the row's real position in the draft. */
  marks: Map<string, PlacementRowMark[]>;
  /** Items whose row the draft no longer holds — the build stops there, and no row can be marked. */
  missing: number[];
}

/**
 * Which authored row answers for which placement item, so the editor can print that on the row
 * itself. It reads the same slots as `placementItems`, including the sweep of pairs the match drill
 * takes and the picture filter of item 10, so a badge follows its row through deletes and reorders
 * instead of staying where the slot was written.
 */
export function placementMarks(draft: UnitDraft): PlacementMarks {
  const marks = new Map<string, PlacementRowMark[]>();
  const missing: number[] = [];
  const add = (list: PlacementList, index: number, mark: PlacementRowMark) => {
    const key = `${list}:${index}`;
    const bucket = marks.get(key);
    if (bucket) bucket.push(mark);
    else marks.set(key, [mark]);
  };

  for (const { slot, item } of slotsFor(draft)) {
    if (slot.drill === 'matchPairs') {
      const picked = matchPairIndexes(draft.vocab, slot.index);
      if (!picked.length) missing.push(item);
      picked.forEach((index, pair) =>
        add('vocab', index, {
          item,
          drill: slot.drill,
          badge: `#${item}·cặp ${pair + 1}`,
          title: `Câu ${item} của bài kiểm tra trình độ: ${slot.question} — bài nối lấy ${picked.length} cặp liên tiếp từ dòng này.`,
          byPictureOrder: false,
          isPairRange: index !== slot.index,
        }),
      );
      continue;
    }
    const rows = rowsOf(draft, slot);
    const index = slot.picturesOnly ? pictureIndexes(draft.vocab)[slot.index] : slot.index;
    if (index === undefined || !rows[slot.index]) {
      missing.push(item);
      continue;
    }
    add(slot.list, index, {
      item,
      drill: slot.drill,
      badge: slot.picturesOnly ? `#${item}·ảnh ${slot.index + 1}` : `#${item}`,
      title: `Câu ${item} của bài kiểm tra trình độ: ${slot.question}.`,
      byPictureOrder: Boolean(slot.picturesOnly),
      isPairRange: false,
    });
  }
  return { marks, missing };
}
