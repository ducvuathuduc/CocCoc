import type { UnitDraft } from './types';

/**
 * What the app actually plays is not the draft: it is `content/<course>/dist/<version>/bundles/*.json`,
 * written by `tools/content/build-course.mjs` at the last build. This module reads those files back and
 * says, per exercise, what the learner is asked, what counts as correct, and which draft row the item
 * came from. It deliberately re-derives nothing — no slot table, no matcher, no dedupe — because a second
 * implementation of the generator in the CMS would be a second source of truth, and the whole point of the
 * screen is to report the generator's own output.
 *
 * Word ids keep the unit prefix the build gave them, because a unit's review lessons ask about words
 * earlier units taught: 275 of unit 16's 399 exercises name a word owned by one of thirteen other units.
 * An index built from one draft would call all of those lost.
 */

export type DraftTab = 'vocab' | 'sentences' | 'dialogues' | 'story';

/** Where a `uNN.<wordId>` points back to in the editor — in whichever unit taught that word. */
export interface BuiltWordRef {
  tab: DraftTab;
  /** Zero-based row in that table; the screen prints `row + 1`. */
  row: number;
  label: string;
  /** The unit number the id carries, which is not always the unit being read. */
  unitNumber: string;
}

export interface BuiltChoice {
  text: string;
  correct: boolean;
  imageAssetId: string | null;
}

export interface BuiltExercise {
  id: string;
  type: string;
  /** Vietnamese name of the drill, as the screen labels it. */
  label: string;
  prompt: string;
  locale: string;
  audioAssetId: string | null;
  /** What the app accepts, in one line. */
  answer: string;
  choices: BuiltChoice[];
  pairs: { left: string; right: string }[];
  /** Every text the app grades as right, not only the first. */
  accepted: string[];
  passage: string | null;
  hint: string | null;
  explanation: string | null;
  skills: string[];
  /** Word ids the build says this item teaches, named as the build names them (`u2.mother`). */
  wordIds: string[];
  refs: BuiltWordRef[];
  /** `wordIds` no draft in the course owns — the build is older than the drafts. */
  unknown: string[];
  /** The drill a phone without a microphone or speaker falls back to (`build-course.mjs:918-944`). */
  variant: { type: string; label: string; prompt: string; answer: string } | null;
  /** Word ids only the fallback drill asks about and no draft owns. */
  variantUnknown: string[];
}

export interface BuiltLesson {
  lessonId: string;
  title: string;
  nodeId: string;
  nodeTitle: string;
  /** `lesson` | `story` | `mastery`, from the manifest. */
  nodeKind: string;
  order: number;
  exercises: BuiltExercise[];
}

/** One node of the manifest: the lesson plan the generator laid out under a unit. */
export interface BuiltNode {
  nodeId: string;
  title: string;
  kind: string;
  lessonIds: string[];
}

const DRILL_LABEL: Record<string, string> = {
  choice: 'Trắc nghiệm',
  imageChoice: 'Chọn ảnh',
  listenChoice: 'Nghe — chọn câu',
  matchPairs: 'Nối cặp từ',
  wordBank: 'Chọn từ vào chỗ trống',
  sentenceOrder: 'Sắp xếp câu',
  fillBlank: 'Điền từ còn thiếu',
  textTranslation: 'Dịch sang tiếng Anh',
  dictation: 'Nghe — viết lại câu',
  speakRepeat: 'Nói lại câu',
  dialogueTurn: 'Hội thoại — trả lời',
  storyQuestion: 'Câu hỏi truyện',
};

export const drillLabel = (type: string): string => DRILL_LABEL[type] ?? `dạng ${type}`;

/** True for every drill the current generator emits; a new type makes the harness say so. */
export const knownDrills = (): string[] => Object.keys(DRILL_LABEL);

const str = (value: unknown): string | null => (typeof value === 'string' && value ? value : null);

/**
 * The ids stay whole (`u2.mother`): a review lesson of unit 9 asks about words unit 2 taught, and dropping
 * the prefix would make that look like a word this unit lost.
 */
function wordIdsOf(vocabularyIds: unknown): string[] {
  if (!Array.isArray(vocabularyIds)) return [];
  return vocabularyIds.filter(
    (id): id is string => typeof id === 'string' && id.includes('.') && !id.endsWith('.'),
  );
}

function choicesOf(content: unknown, rule: unknown): BuiltChoice[] {
  if (!content || typeof content !== 'object') return [];
  const raw = (content as { choices?: unknown }).choices;
  if (!Array.isArray(raw)) return [];
  const correct = str((rule as { correctChoiceId?: unknown } | undefined)?.correctChoiceId) ?? '';
  return raw.flatMap((choice) => {
    if (!choice || typeof choice !== 'object') return [];
    const item = choice as { text?: unknown; id?: unknown; imageAssetId?: unknown };
    return [
      {
        text: str(item.text) ?? '',
        correct: str(item.id) === correct,
        imageAssetId: str(item.imageAssetId),
      },
    ];
  });
}

/** The right-hand order of a pair/token answer, so the screen shows what the app grades, not a shuffle. */
function orderedIds(rule: unknown, field: string): string[] {
  const raw = (rule as Record<string, unknown> | undefined)?.[field];
  return Array.isArray(raw) ? raw.filter((id): id is string => typeof id === 'string') : [];
}

function pairsOf(content: unknown, rule: unknown): { left: string; right: string }[] {
  const raw = (content as { pairs?: unknown } | undefined)?.pairs;
  if (!Array.isArray(raw)) return [];
  const byId = new Map<string, { left: string; right: string }>();
  for (const pair of raw) {
    if (!pair || typeof pair !== 'object') continue;
    const item = pair as { id?: unknown; left?: unknown; right?: unknown };
    const left = (item.left as { text?: unknown } | undefined)?.text;
    const right = (item.right as { text?: unknown } | undefined)?.text;
    if (typeof item.id === 'string' && typeof left === 'string' && typeof right === 'string')
      byId.set(item.id, { left, right });
  }
  const order = orderedIds(rule, 'correctPairIds');
  return (order.length ? order : [...byId.keys()]).flatMap((id) => byId.get(id) ?? []);
}

function tokensOf(content: unknown, rule: unknown): string {
  const raw = (content as { tokens?: unknown } | undefined)?.tokens;
  if (!Array.isArray(raw)) return '';
  const byId = new Map<string, string>();
  for (const token of raw) {
    if (!token || typeof token !== 'object') continue;
    const item = token as { id?: unknown; text?: unknown };
    if (typeof item.id === 'string' && typeof item.text === 'string') byId.set(item.id, item.text);
  }
  const order = orderedIds(rule, 'correctTokenIds');
  if (order.length) {
    const lined = order.map((id) => byId.get(id)).filter((text): text is string => !!text);
    if (lined.length) return lined.join(' ');
  }
  return [...byId.values()].join(' ');
}

/**
 * One line that says what counts as right. Each drill is asked differently, so the answer is read from the
 * field the generator actually grades: a choice id, a reference sentence, the first accepted text, a pair
 * order, a token order. The other accepted spellings are not repeated here — `accepted` lists them.
 */
function answerOf(type: string, content: unknown, rule: unknown, choices: BuiltChoice[]): string {
  const item = (content ?? {}) as Record<string, unknown>;
  const grading = (rule ?? {}) as Record<string, unknown>;
  if (typeof grading.correctChoiceId === 'string') {
    const hit = choices.find((choice) => choice.correct);
    if (hit) return hit.text;
  }
  if (typeof item.referenceText === 'string') return item.referenceText;
  if (Array.isArray(grading.acceptedText)) {
    const first = grading.acceptedText.find((text) => typeof text === 'string');
    if (first) return first;
  }
  if (type === 'matchPairs') {
    const pairs = pairsOf(item, grading);
    return pairs.map((pair) => `${pair.left} → ${pair.right}`).join('; ');
  }
  if (type === 'wordBank' || type === 'sentenceOrder') return tokensOf(item, grading);
  if (typeof item.question === 'string') return item.question;
  return '';
}

function variantOf(exercise: Record<string, unknown>, words: Map<string, BuiltWordRef>) {
  const raw = exercise.nonAudioAlternative ?? exercise.nonSpeechAlternative;
  if (!raw || typeof raw !== 'object') return null;
  const variant = raw as Record<string, unknown>;
  const type = str(variant.type) ?? '';
  const content = variant.content;
  const rule = variant.gradingRule;
  const spoken = (variant.prompt ?? {}) as Record<string, unknown>;
  const choices = choicesOf(content, rule);
  return {
    type,
    label: drillLabel(type),
    prompt: str(spoken.text) ?? '',
    answer: answerOf(type, content, rule, choices),
    wordIds: wordIdsOf(variant.vocabularyIds).filter((id) => !words.has(id)),
  };
}

/** Every text the app grades as right, not only the one printed as the answer. */
function acceptedOf(rule: unknown): string[] {
  const raw = (rule as { acceptedText?: unknown } | undefined)?.acceptedText;
  return Array.isArray(raw) ? raw.filter((text): text is string => typeof text === 'string') : [];
}

/**
 * Every word id one unit's draft owns, keyed the way the build names it (`u2.mother`). Merging these maps
 * across the course gives an index a review lesson can be traced through.
 */
export function wordIndex(draft: UnitDraft, unitNumber: string): Map<string, BuiltWordRef> {
  const out = new Map<string, BuiltWordRef>();
  draft.vocab.forEach((row, index) => {
    if (row.id)
      out.set(`${unitNumber}.${row.id}`, { tab: 'vocab', row: index, label: row.en, unitNumber });
  });
  return out;
}

/** `null` when the file is not a lesson bundle at all, so the caller can say which files it skipped. */
export function parseLesson(
  raw: unknown,
  node: BuiltNode | undefined,
  words: Map<string, BuiltWordRef>,
): BuiltLesson | null {
  if (!raw || typeof raw !== 'object') return null;
  const bundle = raw as Record<string, unknown>;
  const lessonId = str(bundle.lessonId);
  if (!lessonId || !Array.isArray(bundle.exercises)) return null;
  const exercises: BuiltExercise[] = [];
  for (const entry of bundle.exercises) {
    if (!entry || typeof entry !== 'object') continue;
    const exercise = entry as Record<string, unknown>;
    const type = str(exercise.type) ?? '';
    const content = exercise.content;
    const rule = exercise.gradingRule;
    const prompt = (exercise.prompt ?? {}) as Record<string, unknown>;
    const choices = choicesOf(content, rule);
    const ids = wordIdsOf(exercise.vocabularyIds);
    const refs = ids.flatMap((id) => words.get(id) ?? []);
    const variant = variantOf(exercise, words);
    exercises.push({
      id: str(exercise.id) ?? lessonId,
      type,
      label: drillLabel(type),
      prompt: str(prompt.text) ?? '',
      locale: str(prompt.locale) ?? '',
      audioAssetId: str(prompt.audioAssetId),
      answer: answerOf(type, content, rule, choices),
      choices,
      pairs: type === 'matchPairs' ? pairsOf(content, rule) : [],
      accepted: acceptedOf(rule),
      passage: str((content as { passage?: unknown } | undefined)?.passage ?? null),
      hint: str(exercise.hint),
      explanation: str(exercise.explanation),
      skills: Array.isArray(exercise.skillIds)
        ? exercise.skillIds.filter((skill): skill is string => typeof skill === 'string')
        : [],
      wordIds: ids,
      refs,
      unknown: ids.filter((id) => !words.has(id)),
      variant: variant
        ? { type: variant.type, label: variant.label, prompt: variant.prompt, answer: variant.answer }
        : null,
      variantUnknown: variant ? variant.wordIds : [],
    });
  }
  return {
    lessonId,
    title: str(bundle.title) ?? lessonId,
    nodeId: str(bundle.nodeId) ?? node?.nodeId ?? '',
    nodeTitle: node?.title ?? '',
    nodeKind: node?.kind ?? '',
    order: typeof bundle.order === 'number' ? bundle.order : 0,
    exercises,
  };
}

/** Word ids the build asked about while no draft owns them any more, kept whole so the prefix stays true. */
export function staleWordIds(lessons: BuiltLesson[]): string[] {
  const out = new Set<string>();
  for (const lesson of lessons)
    for (const exercise of lesson.exercises)
      for (const id of [...exercise.unknown, ...exercise.variantUnknown]) out.add(id);
  return [...out].sort();
}
