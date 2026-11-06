'use client';

import {
  startTransition,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  ViewTransition,
} from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { saveUnitDraft } from '@/server/actions/unit';
import { lintUnit } from '@/cms/lint';
import { fold } from '@/cms/search';
import { placementMarks, type PlacementRowMark } from '@/cms/placement';
import { slug } from '@/cms/tables';
import { renderUnitFile } from '@/cms/render';
import { blankVocabRow } from '@/cms/blank';
import type {
  Cefr,
  DialogueRow,
  SentenceRow,
  StoryQuestionRow,
  UnitDraft,
  VocabRow,
} from '@/cms/types';
import { BackToCourse } from '@/components/course-tools';
import { PageTransition } from '@/components/page-transition';
import { TechDetails } from '@/components/tech-details';
import { badge, button, card, code, compact, field, ghost, hint, link, log, primary, td, th } from '@/lib/ui';
import { whereIs } from '@/lib/words';
import { cn } from '@/lib/utils';

/* Content first, like the app itself. Naming the lesson and the machine file are the exceptions. */
const TABS = [
  ['vocab', 'Từ vựng'],
  ['sentences', 'Câu'],
  ['dialogues', 'Hội thoại'],
  ['story', 'Truyện đọc'],
  ['media', 'Ảnh & âm thanh'],
  ['preview', 'Xem trước'],
  ['basics', 'Thông tin bài'],
  ['file', 'File kỹ thuật'],
] as const;

type TabKey = (typeof TABS)[number][0];

/** Search results deep-link `?tab=story`; anything unknown, or a tab that does not exist, is vocab. */
const tabKey = (want: string | undefined): TabKey =>
  TABS.some(([key]) => key === want) ? (want as TabKey) : 'vocab';

/** The file the build script writes is only interesting to whoever runs the build script. */
const TECHNICAL_TABS: TabKey[] = ['file'];

/**
 * One lesson carries 20 words and 34 sentences, and a table that long is where a first-time editor
 * stops reading and starts guessing. Ten rows fit one screen; the rest stay behind a button that
 * says how many there are.
 */
const ROW_WINDOW = 10;

type ListKey = 'vocab' | 'sentences' | 'dialogues' | 'story';

/** How lint names the first row of each list, e.g. `vocab[3].en` or `story.questions[0].q`. */
const ROW_PATH: Record<ListKey, string> = {
  vocab: 'vocab[',
  sentences: 'sentences[',
  dialogues: 'dialogues[',
  story: 'story.questions[',
};

const LIST_KEYS = Object.keys(ROW_PATH) as ListKey[];

/** `vocab[3] (hello)` and `story.questions[0]` both say which panel owns the problem. */
const lintTab = (path: string): TabKey | null => {
  const root = path.split(/[[.\s]/)[0];
  if (['title', 'cefr', 'theme', 'levels', 'guide'].includes(root)) return 'basics';
  return TABS.some(([key]) => key === root) ? (root as TabKey) : null;
};

const ADVANCED_KEY = 'coc.cms.advanced';
const readAdvanced = () => localStorage.getItem(ADVANCED_KEY) === '1';
const subscribeAdvanced = (onChanged: () => void) => {
  window.addEventListener('storage', onChanged);
  return () => window.removeEventListener('storage', onChanged);
};

const split = (text: string, sep: string): string[] => text.split(sep);
const join = (items: string[], sep: string): string => items.join(sep);

const replace = <T,>(rows: T[], index: number, value: T): T[] =>
  rows.map((row, i) => (i === index ? value : row));
const removeAt = <T,>(rows: T[], index: number): T[] => rows.filter((_, i) => i !== index);
const moveAt = <T,>(rows: T[], index: number, delta: number): T[] => {
  const target = index + delta;
  if (target < 0 || target >= rows.length) return rows;
  const out = [...rows];
  [out[index], out[target]] = [out[target], out[index]];
  return out;
};

/** Empty alternative slots are a typing artefact, never content. */
function normalize(draft: UnitDraft): UnitDraft {
  const list = (items: string[]) => items.map((x) => x.trim()).filter(Boolean);
  return {
    ...draft,
    title: draft.title.trim(),
    theme: draft.theme.trim(),
    levels: draft.levels.map((l) => l.trim()),
    guide: draft.guide.trim(),
    vocab: draft.vocab.map((v) => ({
      ...v,
      en: v.en.trim(),
      vi: v.vi.trim(),
      id: v.id.trim() || slug(v.en),
      enAlts: list(v.enAlts),
      viAlts: list(v.viAlts),
      forms: list(v.forms),
    })),
    sentences: draft.sentences.map((s) => ({
      ...s,
      en: s.en.trim(),
      vi: s.vi.trim(),
      enAlts: list(s.enAlts),
      viAlts: list(s.viAlts),
    })),
    dialogues: draft.dialogues.map((d) => ({
      ...d,
      line: d.line.trim(),
      reply: d.reply.trim(),
      vi: d.vi.trim(),
      replyAlts: list(d.replyAlts),
    })),
    story: {
      ...draft.story,
      title: draft.story.title.trim(),
      questions: draft.story.questions.map((q) => ({
        ...q,
        q: q.q.trim(),
        correct: q.correct.trim(),
        wrongs: list(q.wrongs),
      })),
    },
  };
}

const placementMark =
  'shrink-0 rounded border border-line bg-elevated px-1 py-0.5 text-[10px] font-medium tabular-nums text-fg-3';

/**
 * Sentences are read, not edited, most of the time: one line each, the form only for the row you
 * picked. The grid is shared by the sticky column header and every summary row so they line up.
 */
const SENT_GRID =
  'grid flex-1 items-center gap-3 text-left grid-cols-[1.75rem_minmax(0,1fr)] sm:grid-cols-[1.75rem_minmax(0,1.1fr)_minmax(0,1fr)]';
const SENT_USE = 'w-44 shrink-0 truncate text-xs sm:w-48';
const SENT_ROW_WRAP = 'flex items-center gap-2 px-3';

/**
 * Focus has to land after the click's own re-render, or the row it asks for is not in the DOM yet.
 * One frame is enough and keeps the effect-free rule the linter enforces here.
 */
const focusNextFrame = (sel: string) =>
  requestAnimationFrame(() => document.querySelector<HTMLElement>(sel)?.focus());
const focusSentenceRow = (index: number) => focusNextFrame(`[data-sentence-row="${index}"]`);
const focusEnglishBox = () => focusNextFrame('[data-sentence-input="en"]');

/** `#10·ảnh 2` is the build's shorthand; an author needs to know which question will change. */
function usedIn(mark: PlacementRowMark): string {
  const detail = usedDetail(mark);
  return `Dùng trong câu ${mark.item}${detail} của bài kiểm tra trình độ`;
}

/** The badge sits in a narrow row cell, so it names the test and the question without the sentence. */
function usedBrief(mark: PlacementRowMark): string {
  return `Bài kiểm tra: câu ${mark.item}${usedDetail(mark)}`;
}

function usedDetail(mark: PlacementRowMark): string {
  const tail = mark.badge.split('·')[1];
  return tail ? ` (${tail.replace(/^(ảnh|cặp) /, '$1 thứ ')})` : '';
}

function RowTools({
  index,
  size,
  marks,
  inline = false,
  lessonHref,
  onMove,
  onRemove,
}: {
  index: number;
  size: number;
  marks?: PlacementRowMark[];
  inline?: boolean;
  lessonHref?: string;
  onMove: (delta: number) => void;
  onRemove: () => void;
}) {
  return (
    <div className={inline ? 'flex items-center gap-1' : 'flex flex-col items-end gap-1'}>
      {marks && marks.length > 0 && (
        <div className="flex flex-wrap justify-end gap-1">
          {marks.map((mark) => {
            const key = `${mark.item}${mark.isPairRange ? 'p' : ''}${mark.byPictureOrder ? 'i' : ''}`;
            const text = usedBrief(mark);
            return lessonHref ? (
              <Link
                key={key}
                href={lessonHref}
                className={cn(placementMark, 'hover:underline')}
                title={`${usedIn(mark)} — xem app sẽ hỏi gì`}
              >
                {text}
              </Link>
            ) : (
              <span key={key} className={placementMark} title={usedIn(mark)}>
                {text}
              </span>
            );
          })}
        </div>
      )}
      <div className="flex items-center gap-1">
        <button
          type="button"
          className={ghost}
          onClick={() => onMove(-1)}
          disabled={index === 0}
          aria-label="Dời dòng này lên"
          title="Dời lên"
        >
          ↑
        </button>
        <button
          type="button"
          className={ghost}
          onClick={() => onMove(1)}
          disabled={index >= size - 1}
          aria-label="Dời dòng này xuống"
          title="Dời xuống"
        >
          ↓
        </button>
        <button type="button" className={ghost} onClick={onRemove} title="Xóa dòng này">
          Xóa
        </button>
      </div>
    </div>
  );
}

function AddRow({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button type="button" className={`${button} mt-3`} onClick={onClick}>
      {label}
    </button>
  );
}

/** The rows are not gone, so say how many are waiting rather than leaving an unexplained cut. */
function ShowMore({ total, shown, onMore }: { total: number; shown: number; onMore: () => void }) {
  const hidden = total - shown;
  if (hidden <= 0) return null;
  return (
    <button type="button" className={cn(button, 'mt-3 w-full')} onClick={onMore}>
      Hiện thêm {Math.min(ROW_WINDOW, hidden)} dòng · còn {hidden} dòng chưa hiện
    </button>
  );
}

/**
 * Field that keeps raw text while typing and only writes to the draft on blur, so separators are
 * not eaten mid-word. Rows are keyed by index, so the value must re-sync whenever the list changes
 * under the field — an uncontrolled `defaultValue` would keep showing the previous row's text.
 */
function CommitField({
  value,
  onCommit,
  placeholder,
  className = compact,
  rows,
}: {
  value: string;
  onCommit: (text: string) => void;
  placeholder?: string;
  className?: string;
  rows?: number;
}) {
  const [text, setText] = useState(value);
  // Re-sync when the draft changes underneath (row deleted, moved, saved). Adjusting during
  // render is React's own pattern for prop-derived editable state; an effect would paint stale
  // text for one frame first.
  const [synced, setSynced] = useState(value);
  if (synced !== value) {
    setSynced(value);
    setText(value);
  }
  const props = {
    className,
    value: text,
    placeholder,
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
      setText(e.target.value),
    onBlur: () => onCommit(text),
  };
  return rows ? <textarea rows={rows} {...props} /> : <input {...props} />;
}

/** Same idea for a list packed into one input (`enAlts`, `forms`, …). */
function AltField({
  items,
  joinSep,
  splitSep,
  onCommit,
  placeholder,
  className = compact,
  rows,
}: {
  items: string[];
  joinSep: string;
  splitSep: string;
  onCommit: (items: string[]) => void;
  placeholder?: string;
  className?: string;
  rows?: number;
}) {
  return (
    <CommitField
      value={join(items, joinSep)}
      placeholder={placeholder}
      className={className}
      rows={rows}
      onCommit={(text) => onCommit(split(text, splitSep))}
    />
  );
}

const PREVIEW_SCOPES = [
  ['item', 'Câu đang mở'],
  ['section', 'Mục này'],
  ['lesson', 'Cả bài'],
] as const;

type PreviewScope = (typeof PREVIEW_SCOPES)[number][0];

/**
 * The app's own lesson view, built from the draft on screen. The old tab showed the file the
 * build script would write, which answered a question only an operator has; this one answers the
 * question the author has: “what will the learner see?” — and it shows only the part you asked about,
 * because "how does this sentence read" should not cost a scroll through the whole lesson.
 */
function DraftPreview({
  draft,
  dirty,
  scope,
  onScope,
  section,
  row,
}: {
  draft: UnitDraft;
  dirty: boolean;
  scope: PreviewScope;
  onScope: (scope: PreviewScope) => void;
  section: ListKey;
  row: number | null;
}) {
  const unit = normalize(draft);
  const hasContent =
    unit.vocab.length > 0 ||
    unit.sentences.length > 0 ||
    unit.dialogues.length > 0 ||
    Boolean(unit.story.passage);
  const scopes = row === null ? PREVIEW_SCOPES.filter(([key]) => key !== 'item') : PREVIEW_SCOPES;
  /** "Câu đang mở" only means something while a row is open; arriving from another tab falls back. */
  const scoped: PreviewScope = scope === 'item' && row === null ? 'section' : scope;
  const only = (key: ListKey) => scoped === 'lesson' || section === key;
  const clip = <T,>(rows: T[]): T[] =>
    scoped === 'item' && row !== null ? rows.slice(row, row + 1) : rows;
  /** A sliced list still has to print the number the author sees in the editor, not 1. */
  const offset = scoped === 'item' && row !== null ? row : 0;
  const vocab = only('vocab') ? clip(unit.vocab) : [];
  const sentences = only('sentences') ? clip(unit.sentences) : [];
  const dialogues = only('dialogues') ? clip(unit.dialogues) : [];
  const questions = only('story') ? clip(unit.story.questions) : [];
  const storyShown =
    only('story') && Boolean(unit.story.title || unit.story.passage || unit.story.questions.length);
  const empty = !vocab.length && !sentences.length && !dialogues.length && !storyShown;
  /** A heading that says 34 while the panel holds one row would be the same lie the old status chips told. */
  const tally = (shown: number, total: number) =>
    shown === total ? String(total) : `${shown}/${total}`;

  return (
    <section className={cn(card, 'overflow-hidden')} aria-label="Xem trước bài học">
      <div className="border-b border-line bg-elevated px-5 py-4">
        <div className="flex flex-wrap items-center gap-2">
          <span className={badge}>{unit.cefr}</span>
          <h2 className="text-lg font-semibold tracking-tight">
            {unit.title || 'Bài chưa đặt tên'}
          </h2>
          <span className={cn(hint, 'ml-auto')}>
            {dirty ? 'Xem trước thay đổi chưa lưu' : 'Xem trước bài đã lưu'}
          </span>
        </div>
        <div
          className="mt-3 flex flex-wrap items-center gap-1"
          role="group"
          aria-label="Phạm vi xem trước"
        >
          {scopes.map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => onScope(key)}
              aria-pressed={scoped === key}
              className={cn(
                'rounded-full px-2.5 py-1 text-xs transition-colors',
                scoped === key
                  ? 'bg-primary text-white'
                  : 'bg-card text-fg-3 hover:text-fg',
              )}
            >
              {key === 'item' && row !== null ? `Câu ${row + 1}` : label}
            </button>
          ))}
        </div>
      </div>

      {!hasContent ? (
        <p className="px-5 py-10 text-center text-sm text-fg-3">
          Chưa có nội dung để xem trước. Thêm từ vựng hoặc câu ở các mục phía trên.
        </p>
      ) : empty ? (
        <p className="px-5 py-10 text-center text-sm text-fg-3">
          Mục này chưa có gì để xem. Mở một câu hoặc chọn “Cả bài”.
        </p>
      ) : (
        <div className="space-y-6 p-5">
          {unit.guide && scoped === 'lesson' && (
            <p className="max-w-2xl text-sm leading-relaxed whitespace-pre-line text-fg-2">
              {unit.guide}
            </p>
          )}
          {vocab.length > 0 && (
            <section>
              <h3 className="text-sm font-medium">
                Từ vựng{' '}
                <span className="ml-1 text-xs font-normal text-fg-4">
                  {tally(vocab.length, unit.vocab.length)}
                </span>
              </h3>
              <ul className="mt-2 divide-y divide-line rounded-lg border border-line">
                {vocab.map((word, i) => (
                  <li key={i} className="flex flex-wrap items-baseline gap-x-3 gap-y-1 px-3 py-2">
                    <span className="w-4 shrink-0 text-xs tabular-nums text-fg-4">{word.level}</span>
                    <span className="text-sm font-medium text-fg">{word.en || '—'}</span>
                    <span className="text-sm text-fg-3">{word.vi || 'Chưa có nghĩa'}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {sentences.length > 0 && (
            <section>
              <h3 className="text-sm font-medium">
                Câu{' '}
                <span className="ml-1 text-xs font-normal text-fg-4">
                  {tally(sentences.length, unit.sentences.length)}
                </span>
              </h3>
              <ul className="mt-2 divide-y divide-line rounded-lg border border-line">
                {sentences.map((sent, i) => (
                  <li key={i} className="px-3 py-2">
                    <p className="text-sm font-medium text-fg">{sent.en || '—'}</p>
                    <p className="text-sm text-fg-3">{sent.vi || 'Chưa có nghĩa'}</p>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {dialogues.length > 0 && (
            <section>
              <h3 className="text-sm font-medium">Hội thoại</h3>
              <ul className="mt-2 space-y-2">
                {dialogues.map((rowItem, i) => (
                  <li key={i} className="rounded-lg border border-line px-3 py-2">
                    <p className="text-sm text-fg-3">{rowItem.line || '—'}</p>
                    <p className="mt-1 text-sm font-medium text-fg">{rowItem.reply || '—'}</p>
                    <p className="text-xs text-fg-4">{rowItem.vi}</p>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {storyShown && (
            <section>
              <h3 className="text-sm font-medium">Truyện đọc</h3>
              <div className="mt-2 rounded-lg border border-line p-3">
                {unit.story.title && (
                  <p className="text-sm font-medium text-fg">{unit.story.title}</p>
                )}
                {unit.story.passage && (
                  <p className="mt-1 whitespace-pre-line text-sm leading-relaxed text-fg-2">
                    {unit.story.passage}
                  </p>
                )}
                {questions.length > 0 && (
                  <ol className="mt-3 space-y-2 border-t border-line pt-3">
                    {questions.map((question, i) => (
                      <li key={offset + i} className="text-sm">
                        <p className="font-medium text-fg">
                          {offset + i + 1}. {question.q || '(câu hỏi trống)'}
                        </p>
                        <p className="text-xs text-ok-fg">Đúng: {question.correct || '—'}</p>
                        {question.wrongs
                          .filter(Boolean)
                          .map((wrong, j) => (
                            <p key={j} className="text-xs text-fg-4">
                              Sai: {wrong}
                            </p>
                          ))}
                      </li>
                    ))}
                  </ol>
                )}
              </div>
            </section>
          )}
        </div>
      )}
    </section>
  );
}

export function UnitEditor({
  courseId,
  unitId,
  order,
  revision,
  initial,
  initialTab,
  initialRow,
  mediaPanel,
}: {
  courseId: string;
  unitId: string;
  order: number;
  revision: number;
  initial: UnitDraft;
  initialTab?: string;
  /** Row zero-based row a search hit pointed at; the list opens far enough to show it. */
  initialRow?: number;
  /** The media panel the server worked out; it is a tab now instead of a second page half. */
  mediaPanel?: React.ReactNode;
}) {
  const router = useRouter();
  const [draft, setDraft] = useState<UnitDraft>(initial);
  const [saved, setSaved] = useState<{ draft: UnitDraft; revision: number }>({
    draft: initial,
    revision,
  });
  const [tab, setTab] = useState<TabKey>(tabKey(initialTab));
  /** Which section the preview shows when you ask for "this section" — the last content tab you were on. */
  const [contentTab, setContentTab] = useState<ListKey>(
    LIST_KEYS.includes(tabKey(initialTab) as ListKey) ? (tabKey(initialTab) as ListKey) : 'vocab',
  );
  const [previewScope, setPreviewScope] = useState<PreviewScope>('section');
  const [busy, setBusy] = useState(false);
  const [blocking, setBlocking] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [advancedChoice, setAdvancedChoice] = useState<boolean | null>(null);
  const [rowWindow, setRowWindow] = useState<Partial<Record<ListKey, number>>>({});
  // The row a search hit or a lint item asked for; `tab` guards it so a hit in `Câu` cannot
  // highlight `dòng 4` of Từ vựng.
  const [jumpRow, setJumpRow] = useState<number | undefined>(initialRow);
  const linkedRow = LIST_KEYS.includes(tab as ListKey) ? jumpRow : undefined;
  const lintPanel = useRef<HTMLElement | null>(null);
  /** The one sentence whose form is open; the other 33 stay single-line summaries. */
  const [openRow, setOpenRow] = useState<number | null>(
    tabKey(initialTab) === 'sentences' ? (initialRow ?? null) : null,
  );
  const [sentenceQuery, setSentenceQuery] = useState('');

  // The server paints the plain view; whatever this browser remembered is applied after hydration,
  // so a returning author keeps the extra columns without a second render.
  const remembered = useSyncExternalStore(subscribeAdvanced, readAdvanced, () => false);
  const advanced = advancedChoice ?? (remembered || TECHNICAL_TABS.includes(tab));

  const dirty = JSON.stringify(draft) !== JSON.stringify(saved.draft);
  const issues = useMemo(() => lintUnit(normalize(draft)), [draft]);
  const errors = issues.filter((i) => i.level === 'error');
  const warnings = issues.filter((i) => i.level === 'warning');
  // A tab badge is only useful if it says "this panel still has work in it", not "here is a number".
  const issuesByTab = useMemo(() => {
    const out: Partial<Record<TabKey, { error: number; warning: number }>> = {};
    for (const issue of issues) {
      const key = lintTab(issue.path);
      if (!key) continue;
      const cell = out[key] ?? { error: 0, warning: 0 };
      out[key] = { ...cell, [issue.level]: cell[issue.level] + 1 };
    }
    return out;
  }, [issues]);
  const countOf = (key: TabKey): number =>
    key === 'vocab'
      ? draft.vocab.length
      : key === 'sentences'
        ? draft.sentences.length
        : key === 'dialogues'
          ? draft.dialogues.length
          : key === 'story'
            ? draft.story.questions.length
            : 0;
  // `build-course.mjs:1005-1028` harvests the placement test from the first unit by position, so only
  // that unit's rows carry consequences the author cannot see anywhere else.
  const placement = useMemo(() => (order === 0 ? placementMarks(draft) : null), [draft, order]);
  const lessonHref = `/courses/${courseId}/units/${unitId}/lesson`;

  /** How many rows of each list must be on screen: the first dozen, plus every row still in trouble. */
  const showing = useMemo(() => {
    const rows = (list: ListKey): number => {
      let need = ROW_WINDOW;
      for (const issue of issues) {
        if (issue.level !== 'error') continue;
        const path = ROW_PATH[list];
        if (!issue.path.startsWith(path)) continue;
        const row = Number(/^\d+/.exec(issue.path.slice(path.length))?.[0]);
        if (row >= 0) need = Math.max(need, row + 1);
      }
      for (const key of placement?.marks.keys() ?? []) {
        const [markedList, rawRow] = key.split(':');
        if (markedList !== list) continue;
        const row = Number(rawRow);
        if (row >= 0) need = Math.max(need, row + 1);
      }
      return need;
    };
    return {
      vocab: rows('vocab'),
      sentences: rows('sentences'),
      dialogues: rows('dialogues'),
      story: rows('story'),
    };
  }, [issues, placement]);

  useEffect(() => {
    if (blocking) lintPanel.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [blocking]);

  // Arriving from the search box means the author already knows which row they want; the list opens
  // far enough to show it and the browser walks down to it.
  useEffect(() => {
    if (linkedRow === undefined) return;
    document.querySelector('[data-linked="1"]')?.scrollIntoView({ block: 'center' });
  }, [linkedRow, tab]);

  const shownRows = (list: ListKey, total: number) => {
    const wanted = Math.max(showing[list], rowWindow[list] ?? 0);
    if (list === tab && linkedRow !== undefined) return Math.max(wanted, linkedRow + 1);
    return Math.min(total, wanted);
  };
  const revealRows = (list: ListKey, count: number) =>
    setRowWindow((w) => ({ ...w, [list]: count }));
  const showMore = (list: ListKey, shown: number) => revealRows(list, shown + ROW_WINDOW);

  const sentenceMatches = useMemo(() => {
    const needle = fold(sentenceQuery).keys.trim();
    return (row: SentenceRow) =>
      needle === '' || fold(row.en).keys.includes(needle) || fold(row.vi).keys.includes(needle);
  }, [sentenceQuery]);

  function addSentence() {
    setSentenceQuery('');
    setOpenRow(draft.sentences.length);
    set('sentences', [
      ...draft.sentences,
      { en: '', enAlts: [], vi: '', viAlts: [] } satisfies SentenceRow,
    ]);
    focusEnglishBox();
  }

  /**
   * Down/up walks the summaries, Shift+Down opens the row under the cursor, Alt+Down moves it — so
   * reordering a lesson never needs the mouse, and Escape hands focus back to the line you left.
   */
  function sentenceKeys(e: React.KeyboardEvent<HTMLUListElement>) {
    if (e.key === 'Escape' && openRow !== null) {
      setOpenRow(null);
      focusSentenceRow(openRow);
      return;
    }
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    const raw = (document.activeElement as HTMLElement | null)?.getAttribute('data-sentence-row');
    if (raw === null || raw === undefined) return;
    const at = Number(raw);
    const delta = e.key === 'ArrowDown' ? 1 : -1;
    const next = Math.min(draft.sentences.length - 1, Math.max(0, at + delta));
    e.preventDefault();
    if (e.altKey) {
      set('sentences', moveAt(draft.sentences, at, delta));
      if (openRow === at) setOpenRow(next);
      focusSentenceRow(next);
      return;
    }
    if (e.shiftKey) {
      setOpenRow(at);
      focusEnglishBox();
      return;
    }
    focusSentenceRow(next);
  }

  /** A lint item is a place in the lesson: open its tab and put the row on screen. */
  const rowOfIssue = (path: string): { list: ListKey; row: number } | null => {
    for (const list of LIST_KEYS) {
      const prefix = ROW_PATH[list];
      if (!path.startsWith(prefix)) continue;
      const row = Number(/^\d+/.exec(path.slice(prefix.length))?.[0]);
      if (Number.isFinite(row)) return { list, row };
    }
    return null;
  };

  /**
   * Changing tab also remembers the content section, so pressing "Xem trước" from `Câu` previews
   * the sentences instead of dropping you back into a whole-lesson wall of text.
   */
  function goTab(key: TabKey) {
    if (LIST_KEYS.includes(key as ListKey)) setContentTab(key as ListKey);
    startTransition(() => setTab(key));
  }

  function openIssue(path: string) {
    const target = lintTab(path);
    if (!target) return;
    const hit = rowOfIssue(path);
    if (hit) {
      setJumpRow(hit.row);
      revealRows(hit.list, Math.max(showing[hit.list], hit.row + 1));
      if (hit.list === 'sentences') {
        setSentenceQuery('');
        setOpenRow(hit.row);
      }
    } else {
      setJumpRow(undefined);
    }
    goTab(target);
  }

  async function save() {
    setBusy(true);
    const next = normalize(draft);
    let result: Awaited<ReturnType<typeof saveUnitDraft>>;
    try {
      result = await saveUnitDraft({
        courseId,
        unitId,
        order,
        expectedRevision: saved.revision,
        draft: next,
      });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không lưu được bản soạn.');
      return;
    } finally {
      setBusy(false);
    }
    if (result.ok) {
      // Keep the working copy identical to what the store holds, otherwise `dirty` compares the
      // raw draft against the normalized one and the editor claims "chưa lưu" forever.
      setDraft(next);
      setSaved({ draft: next, revision: result.revision ?? saved.revision + 1 });
      setBlocking(null);
      setSavedAt(new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }));
      toast.success('Đã lưu bài học.');
      if (result.warning) toast.warning(result.warning);
      router.refresh();
      return;
    }
    if (result.issues?.length) {
      setBlocking(result.issues.map((i) => `${i.path}: ${i.message}`).join('\n'));
    }
    // The store can also refuse a draft that never reached lint; the local list knows where the
    // problem is either way, so a failed save always lands the author on the panel that owns it.
    const blocker = result.issues?.[0] ?? errors[0];
    if (blocker) {
      const target = lintTab(blocker.path);
      if (target) goTab(target);
      toast.error(`Chưa lưu được: còn ${result.issues?.length ?? errors.length} chỗ cần sửa.`);
      return;
    }
    toast.error(result.message ?? 'Không lưu được.');
  }

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault();
        if (!busy) void save();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  // Closing the tab mid-lesson would throw away every row typed since the last save, silently.
  useEffect(() => {
    if (!dirty) return;
    function onBeforeUnload(event: BeforeUnloadEvent) {
      event.preventDefault();
      event.returnValue = '';
    }
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  }, [dirty]);

  const set = <K extends keyof UnitDraft>(key: K, value: UnitDraft[K]) =>
    setDraft((d) => ({ ...d, [key]: value }));

  return (
    <PageTransition>
      <div className="space-y-5">
        <header className="sticky top-0 z-20 -mx-4 mb-5 border-b border-line bg-background/90 px-4 pb-2 pt-3 backdrop-blur sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex min-w-0 items-center gap-3">
              <BackToCourse courseId={courseId} />
              <div className="min-w-0">
                <h1 className="truncate text-lg font-semibold tracking-tight">
                  {draft.title || 'Bài chưa đặt tên'}
                </h1>
                <p
                  className={cn(
                    'flex items-center gap-1.5 text-xs',
                    busy ? 'text-fg-3' : dirty ? 'text-warn-fg' : 'text-ok-fg',
                  )}
                >
                  <span
                    className={cn(
                      'size-1.5 rounded-full',
                      busy ? 'bg-fg-4' : dirty ? 'animate-pulse bg-warn-fg' : 'bg-ok-fg',
                    )}
                  />
                  {busy
                    ? 'Đang lưu…'
                    : dirty
                      ? 'Có thay đổi chưa lưu'
                      : savedAt
                        ? `Đã lưu lúc ${savedAt}`
                        : 'Đã lưu'}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                className={button}
                disabled={busy || !dirty}
                onClick={() => {
                  setDraft(saved.draft);
                  setBlocking(null);
                }}
              >
                Hoàn tác
              </button>
              <button
                type="button"
                className={cn(primary, 'flex items-center gap-2')}
                disabled={busy || !dirty}
                onClick={save}
              >
                {busy && (
                  <span className="size-3.5 animate-spin rounded-full border-2 border-white/40 border-t-white" />
                )}
                {busy ? 'Đang lưu…' : 'Lưu'}
              </button>
            </div>
          </div>

          <nav className="mt-2 flex flex-wrap items-center gap-1 border-b border-line">
            {TABS.filter(([key]) => advanced || !TECHNICAL_TABS.includes(key)).map(
              ([key, label]) => {
                const count = countOf(key);
                const bad = issuesByTab[key]?.error ?? 0;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => goTab(key)}
                    aria-current={tab === key ? 'page' : undefined}
                    className={cn(
                      '-mb-px flex items-center gap-2 border-b-2 px-3 py-2 text-sm active:scale-[0.98]',
                      tab === key
                        ? 'border-primary font-medium text-fg'
                        : 'border-transparent text-fg-3 hover:border-line-strong hover:text-fg',
                    )}
                  >
                    {label}
                    {count > 0 && (
                      <span className="rounded-full bg-elevated px-1.5 py-0.5 text-[11px] tabular-nums text-fg-3">
                        {count}
                      </span>
                    )}
                    {bad > 0 && (
                      <span
                        className={cn(
                          'size-1.5 rounded-full bg-danger-fg',
                          tab === key && 'animate-pulse',
                        )}
                        title={`${bad} chỗ cần sửa trong phần này`}
                      />
                    )}
                  </button>
                );
              },
            )}
            <label className={cn(hint, 'ml-auto flex cursor-pointer items-center gap-2 pb-2')}>
              <input
                type="checkbox"
                className="size-4 accent-primary"
                checked={advanced}
                onChange={(e) => {
                  setAdvancedChoice(e.target.checked);
                  localStorage.setItem(ADVANCED_KEY, e.target.checked ? '1' : '0');
                  if (!e.target.checked && TECHNICAL_TABS.includes(tab)) goTab('vocab');
                }}
              />
              Hiện cột nâng cao
            </label>
          </nav>

          {tab === 'sentences' && (
            <>
              <div className="flex flex-wrap items-center gap-2 pt-2">
                <input
                  value={sentenceQuery}
                  onChange={(e) => setSentenceQuery(e.target.value)}
                  placeholder="Tìm trong câu…"
                  aria-label="Tìm trong danh sách câu"
                  className={cn(compact, 'w-40 sm:w-64')}
                />
                <span className={hint}>
                  {draft.sentences.filter(sentenceMatches).length}/{draft.sentences.length} câu
                </span>
                <button
                  type="button"
                  className={cn(button, 'ml-auto')}
                  onClick={addSentence}
                  title="Thêm một câu mới vào cuối bài và mở ô soạn"
                >
                  Thêm câu
                </button>
              </div>
              <div className={cn(SENT_ROW_WRAP, 'mt-1 border-t border-line pt-1')}>
                <div
                  className={cn(
                    SENT_GRID,
                    'text-[11px] uppercase tracking-wide text-fg-4 normal-case',
                  )}
                >
                  <span className="text-center">#</span>
                  <span>Câu tiếng Anh</span>
                  <span className="hidden sm:block">Nghĩa tiếng Việt</span>
                </div>
                <span className="hidden text-[11px] uppercase tracking-wide text-fg-4 sm:block w-44">
                  Dùng trong
                </span>
                <span className="w-[4.5rem] shrink-0 text-right text-[11px] uppercase tracking-wide text-fg-4">
                  Trạng thái
                </span>
              </div>
            </>
          )}
        </header>

        {(blocking || errors.length > 0 || warnings.length > 0) && (
          <section
            ref={lintPanel}
            className={cn(
              card,
              'animate-fade-in scroll-mt-24 border-l-2 p-4',
              errors.length || blocking ? 'border-l-danger-fg' : 'border-l-warn-fg',
            )}
          >
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-sm font-medium">Cần xem lại</h2>
              <span
                className={cn(
                  'rounded-full px-2 py-0.5 text-xs font-medium',
                  errors.length ? 'bg-danger-bg text-danger-fg' : 'bg-ok-bg text-ok-fg',
                )}
              >
                {errors.length ? `${errors.length} lỗi` : 'Không có lỗi'}
              </span>
              {warnings.length > 0 && (
                <span className="rounded-full bg-warn-bg px-2 py-0.5 text-xs font-medium text-warn-fg">
                  {warnings.length} điều nên xem
                </span>
              )}
            </div>
            <p className={cn(hint, 'mt-1')}>Bấm vào một dòng để tới đúng chỗ cần sửa.</p>
            <ul className="rise mt-2 max-h-40 space-y-0.5 overflow-auto text-xs">
              {errors.map((i, n) => (
                <li key={`e${n}`}>
                  <button
                    type="button"
                    onClick={() => openIssue(i.path)}
                    className="flex w-full items-start gap-2 rounded px-1 py-1 text-left hover:bg-elevated"
                  >
                    <span className="shrink-0 font-medium text-danger-fg">{whereIs(i.path)}</span>
                    <span className="min-w-0 flex-1 text-fg-2">{i.message}</span>
                    <span aria-hidden className="shrink-0 text-fg-4">
                      →
                    </span>
                  </button>
                </li>
              ))}
              {warnings.map((i, n) => (
                <li key={`w${n}`}>
                  <button
                    type="button"
                    onClick={() => openIssue(i.path)}
                    className="flex w-full items-start gap-2 rounded px-1 py-1 text-left hover:bg-elevated"
                  >
                    <span className="shrink-0 font-medium text-warn-fg">{whereIs(i.path)}</span>
                    <span className="min-w-0 flex-1 text-fg-2">{i.message}</span>
                    <span aria-hidden className="shrink-0 text-fg-4">
                      →
                    </span>
                  </button>
                </li>
              ))}
            </ul>
            {blocking && (
              <>
                <p className="mt-2 text-xs font-medium text-danger-fg">
                  Lần bấm Lưu vừa rồi không được giữ. Sửa xong các chỗ trên rồi bấm Lưu lại lần nữa.
                </p>
                <TechDetails title="Đường dẫn máy dựng thấy" className="mt-2">
                  <pre className={cn(code, 'whitespace-pre-wrap')}>{blocking}</pre>
                </TechDetails>
              </>
            )}
          </section>
        )}

        {placement && placement.missing.length > 0 && (
          <p
            role="alert"
            className={cn(card, 'border-l-2 border-l-danger-fg px-4 py-2.5 text-xs text-fg-2')}
          >
            <span className="font-medium text-danger-fg">
              Bài kiểm tra trình độ đang thiếu câu {placement.missing.join(', ')}:
            </span>{' '}
            thêm hoặc sửa một dòng trong bài để câu đó có nội dung, nếu không lần dựng kế tiếp sẽ
            dừng ở bài này.
          </p>
        )}

        {/* Changing tabs keeps the same location, so the panel crossfades instead
          of sliding like a route change would. */}
        <ViewTransition key={tab} name="unit-tab" share="auto" enter="auto" default="none">
          {tab === 'vocab' && (
            <section className={`${card} overflow-x-auto p-4`}>
              <p className={cn(hint, 'mb-3')}>
                Một dòng là một từ mới. Chỉ cần Cấp, Tiếng Anh và Tiếng Việt.
                <span className="sm:hidden"> Kéo ngang bảng để xem đủ các cột.</span>
              </p>
              <table className="w-full min-w-[600px] text-sm">
                <thead>
                  <tr>
                    <th className={th}>Cấp</th>
                    <th className={th}>Tiếng Anh</th>
                    {advanced && <th className={th}>Cách nói khác</th>}
                    <th className={th}>Tiếng Việt</th>
                    {advanced && (
                      <>
                        <th className={th}>Nghĩa khác</th>
                        <th className={th}>Các dạng từ</th>
                      </>
                    )}
                    <th className={th}>Ảnh</th>
                    {advanced && <th className={th}>Mã từ</th>}
                    <th className={th} />
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {draft.vocab.slice(0, shownRows('vocab', draft.vocab.length)).map((row, i) => (
                    <tr
                      key={i}
                      data-linked={i === linkedRow ? '1' : undefined}
                      className={i === linkedRow ? 'bg-primary-soft' : undefined}
                    >
                      <td className={td}>
                        <select
                          className={cn(compact, 'w-14')}
                          value={row.level}
                          aria-label={`Cấp của từ dòng ${i + 1}`}
                          onChange={(e) =>
                            set(
                              'vocab',
                              replace(draft.vocab, i, {
                                ...row,
                                level: Number(e.target.value) as VocabRow['level'],
                              }),
                            )
                          }
                        >
                          {[1, 2, 3, 4, 5].map((l) => (
                            <option key={l} value={l}>
                              {l}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td className={td}>
                        <input
                          className={compact}
                          value={row.en}
                          placeholder="hello, hi"
                          aria-label={`Từ tiếng Anh ở dòng ${i + 1}`}
                          onChange={(e) =>
                            set('vocab', replace(draft.vocab, i, { ...row, en: e.target.value }))
                          }
                        />
                      </td>
                      {advanced && (
                        <td className={td}>
                          <AltField
                            items={row.enAlts}
                            joinSep=", "
                            splitSep=","
                            onCommit={(enAlts) =>
                              set('vocab', replace(draft.vocab, i, { ...row, enAlts }))
                            }
                          />
                        </td>
                      )}
                      <td className={td}>
                        <input
                          className={compact}
                          value={row.vi}
                          placeholder="xin chào / chào"
                          aria-label={`Nghĩa tiếng Việt của từ dòng ${i + 1}`}
                          onChange={(e) =>
                            set('vocab', replace(draft.vocab, i, { ...row, vi: e.target.value }))
                          }
                        />
                      </td>
                      {advanced && (
                        <>
                          <td className={td}>
                            <AltField
                              items={row.viAlts}
                              joinSep=" / "
                              splitSep="/"
                              onCommit={(viAlts) =>
                                set('vocab', replace(draft.vocab, i, { ...row, viAlts }))
                              }
                            />
                          </td>
                          <td className={td}>
                            <AltField
                              items={row.forms}
                              joinSep=", "
                              splitSep=","
                              placeholder="go, goes, going"
                              onCommit={(forms) =>
                                set('vocab', replace(draft.vocab, i, { ...row, forms }))
                              }
                            />
                          </td>
                        </>
                      )}
                      <td className={td}>
                        <input
                          type="checkbox"
                          className="mx-auto mt-1 block size-4 accent-primary"
                          checked={row.img}
                          aria-label={`Từ dòng ${i + 1} có ảnh minh họa`}
                          onChange={(e) =>
                            set('vocab', replace(draft.vocab, i, { ...row, img: e.target.checked }))
                          }
                        />
                      </td>
                      {advanced && (
                        <td className={td}>
                          <input
                            className={cn(compact, 'w-24')}
                            value={row.id}
                            placeholder="(auto)"
                            aria-label={`Mã từ ở dòng ${i + 1}`}
                            onChange={(e) =>
                              set('vocab', replace(draft.vocab, i, { ...row, id: e.target.value }))
                            }
                          />
                        </td>
                      )}
                      <td className={td}>
                        <RowTools
                          index={i}
                          size={draft.vocab.length}
                          marks={placement?.marks.get(`vocab:${i}`)}
                          lessonHref={lessonHref}
                          onMove={(d) => set('vocab', moveAt(draft.vocab, i, d))}
                          onRemove={() => set('vocab', removeAt(draft.vocab, i))}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <ShowMore
                total={draft.vocab.length}
                shown={shownRows('vocab', draft.vocab.length)}
                onMore={() => showMore('vocab', shownRows('vocab', draft.vocab.length))}
              />
              <AddRow
                label="Thêm từ"
                onClick={() => {
                  revealRows('vocab', draft.vocab.length + 1);
                  set('vocab', [...draft.vocab, blankVocabRow(draft.vocab[0]?.level ?? 1)]);
                }}
              />
              <p className={cn(hint, 'mt-2')}>
                Cấp 1–5 là thứ tự app giới thiệu từ trong bài.
                {advanced &&
                  ' Ô “Cách nói khác” và “Các dạng từ” ngăn các ý bằng dấu phẩy, “Nghĩa khác” bằng dấu gạch chéo — đúng như bảng tác giả.'}
              </p>
            </section>
          )}

          {tab === 'sentences' && (
            <section className={cn(card, 'overflow-hidden')} aria-label="Câu của bài học">
              <p className={cn(hint, 'border-b border-line px-3 py-2')}>
                Bấm vào một câu để sửa; những câu còn lại giữ một dòng gọn. Phím mũi tên đi giữa các
                câu, Shift + mũi tên mở ô soạn, Alt + mũi tên dời câu, Esc quay lại danh sách.
              </p>
              <ul onKeyDown={sentenceKeys}>
                {draft.sentences.map((row, i) => {
                  if (!sentenceMatches(row)) return null;
                  const marks = placement?.marks.get(`sentences:${i}`) ?? [];
                  const rowIssues = issues.filter((x) => x.path.startsWith(`sentences[${i}]`));
                  const rowErrors = rowIssues.filter((x) => x.level === 'error');
                  const rowWarnings = rowIssues.filter((x) => x.level !== 'error');
                  const unsaved =
                    JSON.stringify(row) !== JSON.stringify(saved.draft.sentences[i]) &&
                    rowErrors.length === 0 &&
                    rowWarnings.length === 0;
                  const open = openRow === i;
                  return (
                    <li
                      key={i}
                      data-linked={i === linkedRow ? '1' : undefined}
                      className={cn(
                        'border-b border-line/60 last:border-b-0',
                        open ? 'bg-primary-soft' : 'hover:bg-elevated',
                      )}
                    >
                      {open ? (
                        <div className="space-y-3 px-3 py-3">
                          <div className="flex flex-wrap items-center gap-2">
                            <h3 className="text-sm font-medium">Câu {i + 1}</h3>
                            {marks.map((mark) => (
                              <span
                                key={`${mark.item}${mark.byPictureOrder ? 'i' : ''}`}
                                className={cn(badge, 'max-w-full truncate text-[11px]')}
                                title={mark.title}
                              >
                                {usedIn(mark)}
                              </span>
                            ))}
                            <button
                              type="button"
                              className={cn(ghost, 'ml-auto')}
                              onClick={() => {
                                setOpenRow(null);
                                focusSentenceRow(i);
                              }}
                            >
                              Xong
                            </button>
                          </div>

                          <div className="grid gap-3 lg:grid-cols-2">
                            <label className="block text-xs text-fg-4">
                              Câu tiếng Anh
                              <textarea
                                rows={3}
                                data-sentence-input="en"
                                className={field}
                                value={row.en}
                                placeholder="How are you?"
                                aria-label={`Câu tiếng Anh ở dòng ${i + 1}`}
                                onChange={(e) =>
                                  set(
                                    'sentences',
                                    replace(draft.sentences, i, { ...row, en: e.target.value }),
                                  )
                                }
                              />
                              {advanced && (
                                <>
                                  <span className="mt-2 block">
                                    Cách nói khác (ngăn bằng ##)
                                  </span>
                                  <AltField
                                    items={row.enAlts}
                                    joinSep=" ## "
                                    splitSep="##"
                                    rows={2}
                                    onCommit={(enAlts) =>
                                      set('sentences', replace(draft.sentences, i, { ...row, enAlts }))
                                    }
                                  />
                                </>
                              )}
                            </label>
                            <label className="block text-xs text-fg-4">
                              Nghĩa tiếng Việt
                              <textarea
                                rows={3}
                                className={field}
                                value={row.vi}
                                placeholder="Bạn khỏe không?"
                                aria-label={`Nghĩa tiếng Việt của câu dòng ${i + 1}`}
                                onChange={(e) =>
                                  set(
                                    'sentences',
                                    replace(draft.sentences, i, { ...row, vi: e.target.value }),
                                  )
                                }
                              />
                              {advanced && (
                                <>
                                  <span className="mt-2 block">
                                    Nghĩa khác (ngăn bằng ##)
                                  </span>
                                  <AltField
                                    items={row.viAlts}
                                    joinSep=" ## "
                                    splitSep="##"
                                    rows={2}
                                    onCommit={(viAlts) =>
                                      set('sentences', replace(draft.sentences, i, { ...row, viAlts }))
                                    }
                                  />
                                </>
                              )}
                            </label>
                          </div>

                          <div className="rounded-lg border border-line bg-surface px-3 py-2">
                            <p className="text-[11px] uppercase tracking-wide text-fg-4">
                              Người học thấy
                            </p>
                            <p className="mt-1 text-sm font-medium text-fg">
                              {row.en || 'Chưa viết câu'}
                            </p>
                            <p className="text-sm text-fg-3">{row.vi || 'Chưa có nghĩa'}</p>
                            {row.enAlts.length > 0 && (
                              <p className="mt-1 text-xs text-fg-4">
                                App còn chấp nhận: {row.enAlts.join(' · ')}
                              </p>
                            )}
                          </div>

                          <div className="flex flex-wrap items-center justify-between gap-3">
                            {marks.length > 0 ? (
                              <Link
                                href={`/courses/${courseId}/units/${unitId}/lesson`}
                                transitionTypes={['nav-forward']}
                                className={cn(link, 'text-xs')}
                              >
                                Mở bài kiểm tra trình độ để xem câu hỏi này
                              </Link>
                            ) : (
                              <span className={hint}>
                                Câu này chưa được bài kiểm tra trình độ hỏi tới.
                              </span>
                            )}
                            <div className="flex items-center gap-3">
                              {rowErrors.length > 0 && (
                                <span className="text-xs font-medium text-danger-fg">
                                  {rowErrors.map((x) => x.message).join(' · ')}
                                </span>
                              )}
                              <RowTools
                                inline
                                index={i}
                                size={draft.sentences.length}
                                onMove={(d) => {
                                  set('sentences', moveAt(draft.sentences, i, d));
                                  setOpenRow(i + d);
                                }}
                                onRemove={() => {
                                  set('sentences', removeAt(draft.sentences, i));
                                  setOpenRow(null);
                                }}
                              />
                            </div>
                          </div>
                        </div>
                      ) : (
                        <button
                          type="button"
                          data-sentence-row={i}
                          onClick={() => {
                            setOpenRow(i);
                            focusEnglishBox();
                          }}
                          className={cn(SENT_ROW_WRAP, 'w-full py-1.5')}
                          aria-expanded="false"
                        >
                          <span className={SENT_GRID}>
                            <span className="text-center text-xs tabular-nums text-fg-4">
                              {i + 1}
                            </span>
                            <span className="min-w-0">
                              <span
                                className={cn(
                                  'block truncate text-sm',
                                  row.en ? 'text-fg' : 'text-fg-4 italic',
                                )}
                              >
                                {row.en || 'Chưa viết câu'}
                              </span>
                              <span className="block truncate text-xs text-fg-3 sm:hidden">
                                {row.vi || 'Chưa có nghĩa'}
                                {marks.length > 0 && (
                                  <span className="text-fg-4">
                                    {' · '}
                                    {marks.map((m) => `câu ${m.item}`).join(', ')} của bài kiểm tra
                                  </span>
                                )}
                              </span>
                            </span>
                            <span className="hidden min-w-0 truncate text-sm text-fg-3 sm:block">
                              {row.vi || 'Chưa có nghĩa'}
                            </span>
                          </span>
                          <span className={cn(SENT_USE, 'hidden text-fg-3 sm:block')}>
                            {marks.length > 0
                              ? marks.map((m) => usedIn(m).replace(' của bài kiểm tra trình độ', ''))
                                  .join(' · ')
                              : '—'}
                          </span>
                          <span className="w-[4.5rem] shrink-0 text-right">
                            {rowErrors.length > 0 ? (
                              <span
                                className="text-xs font-medium text-danger-fg"
                                title={rowErrors.map((x) => x.message).join('\n')}
                              >
                                {rowErrors.length} lỗi
                              </span>
                            ) : rowWarnings.length > 0 ? (
                              <span
                                className="text-xs text-warn-fg"
                                title={rowWarnings.map((x) => x.message).join('\n')}
                              >
                                nên xem
                              </span>
                            ) : unsaved ? (
                              <span className="text-xs text-warn-fg">chưa lưu</span>
                            ) : null}
                          </span>
                        </button>
                      )}
                    </li>
                  );
                })}
              </ul>
              {draft.sentences.filter(sentenceMatches).length === 0 && (
                <p className="px-3 py-6 text-center text-sm text-fg-3">
                  Không có câu nào khớp với “{sentenceQuery}”.
                </p>
              )}
            </section>
          )}

          {tab === 'dialogues' && (
            <section className={`${card} overflow-x-auto p-4`}>
              <p className={cn(hint, 'mb-3')}>
                Mỗi dòng là một lượt: người kia nói, rồi người học đáp.
                <span className="sm:hidden"> Kéo ngang bảng để xem đủ các cột.</span>
              </p>
              <table className="w-full min-w-[600px] text-sm">
                <thead>
                  <tr>
                    <th className={th}>Người kia nói</th>
                    <th className={th}>Người học đáp</th>
                    {advanced && <th className={th}>Cách đáp khác</th>}
                    <th className={th}>Nghĩa tiếng Việt của câu đáp</th>
                    <th className={th} />
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {draft.dialogues
                    .slice(0, shownRows('dialogues', draft.dialogues.length))
                    .map((row, i) => (
                      <tr
                        key={i}
                        data-linked={i === linkedRow ? '1' : undefined}
                        className={i === linkedRow ? 'bg-primary-soft' : undefined}
                      >
                        <td className={td}>
                          <textarea
                            rows={2}
                            className={compact}
                            value={row.line}
                            placeholder="Hello! How are you?"
                            aria-label={`Lời của người kia ở lượt ${i + 1}`}
                            onChange={(e) =>
                              set(
                                'dialogues',
                                replace(draft.dialogues, i, { ...row, line: e.target.value }),
                              )
                            }
                          />
                        </td>
                        <td className={td}>
                          <textarea
                            rows={2}
                            className={compact}
                            value={row.reply}
                            placeholder="I'm fine, thanks."
                            aria-label={`Câu trả lời ở lượt ${i + 1}`}
                            onChange={(e) =>
                              set(
                                'dialogues',
                                replace(draft.dialogues, i, { ...row, reply: e.target.value }),
                              )
                            }
                          />
                        </td>
                        {advanced && (
                          <td className={td}>
                            <AltField
                              items={row.replyAlts}
                              joinSep=" ## "
                              splitSep="##"
                              rows={2}
                              onCommit={(replyAlts) =>
                                set('dialogues', replace(draft.dialogues, i, { ...row, replyAlts }))
                              }
                            />
                          </td>
                        )}
                        <td className={td}>
                          <input
                            className={compact}
                            value={row.vi}
                            placeholder="Tớ ổn, cảm ơn cậu."
                            aria-label={`Nghĩa tiếng Việt của câu đáp ở lượt ${i + 1}`}
                            onChange={(e) =>
                              set(
                                'dialogues',
                                replace(draft.dialogues, i, { ...row, vi: e.target.value }),
                              )
                            }
                          />
                        </td>
                        <td className={td}>
                          <RowTools
                            index={i}
                            size={draft.dialogues.length}
                            onMove={(d) => set('dialogues', moveAt(draft.dialogues, i, d))}
                            onRemove={() => set('dialogues', removeAt(draft.dialogues, i))}
                          />
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
              <ShowMore
                total={draft.dialogues.length}
                shown={shownRows('dialogues', draft.dialogues.length)}
                onMore={() => showMore('dialogues', shownRows('dialogues', draft.dialogues.length))}
              />
              <AddRow
                label="Thêm lượt hội thoại"
                onClick={() => {
                  revealRows('dialogues', draft.dialogues.length + 1);
                  set('dialogues', [
                    ...draft.dialogues,
                    { line: '', reply: '', replyAlts: [], vi: '' } satisfies DialogueRow,
                  ]);
                }}
              />
            </section>
          )}

          {tab === 'story' && (
            <section className={`${card} space-y-4 p-4`}>
              <p className={hint}>
                Phần đọc hiểu của bài. Cần đúng 6 câu hỏi.
                <span className="sm:hidden"> Kéo ngang bảng để xem đủ các cột.</span>
              </p>
              <label className="block text-xs text-fg-4">
                Tên truyện
                <input
                  className={field}
                  value={draft.story.title}
                  placeholder="Chào buổi sáng ở Hà Nội"
                  onChange={(e) => set('story', { ...draft.story, title: e.target.value })}
                />
              </label>
              <label className="block text-xs text-fg-4">
                Đoạn truyện (tiếng Anh)
                <textarea
                  rows={10}
                  className={field}
                  value={draft.story.passage}
                  placeholder="Mai wakes up early..."
                  onChange={(e) => set('story', { ...draft.story, passage: e.target.value })}
                />
                <span className={cn(hint, 'mt-1 block tabular-nums')}>
                  {draft.story.passage.length} ký tự
                  {draft.story.passage.length > 4096 && (
                    <span className="ml-1 font-medium text-danger-fg">— dài quá mức app dùng</span>
                  )}
                </span>
              </label>
              <div className="overflow-x-auto">
                <table className="w-full min-w-[600px] text-sm">
                <thead>
                  <tr>
                    <th className={th}>Câu hỏi</th>
                    <th className={th}>Đáp án đúng</th>
                    <th className={th}>Phương án sai</th>
                    <th className={th}>Phương án sai</th>
                    <th className={th}>Phương án sai</th>
                    <th className={th} />
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {draft.story.questions
                    .slice(0, shownRows('story', draft.story.questions.length))
                    .map((row, i) => (
                      <tr
                        key={i}
                        data-linked={i === linkedRow ? '1' : undefined}
                        className={i === linkedRow ? 'bg-primary-soft' : undefined}
                      >
                        <td className={td}>
                          <input
                            className={compact}
                            value={row.q}
                            onChange={(e) =>
                              set('story', {
                                ...draft.story,
                                questions: replace(draft.story.questions, i, {
                                  ...row,
                                  q: e.target.value,
                                }),
                              })
                            }
                          />
                        </td>
                        <td className={td}>
                          <input
                            className={compact}
                            value={row.correct}
                            onChange={(e) =>
                              set('story', {
                                ...draft.story,
                                questions: replace(draft.story.questions, i, {
                                  ...row,
                                  correct: e.target.value,
                                }),
                              })
                            }
                          />
                        </td>
                        {[0, 1, 2].map((slot) => (
                          <td className={td} key={slot}>
                            <CommitField
                              value={row.wrongs[slot] ?? ''}
                              onCommit={(text) => {
                                const wrongs = [...row.wrongs];
                                wrongs[slot] = text;
                                set('story', {
                                  ...draft.story,
                                  questions: replace(draft.story.questions, i, { ...row, wrongs }),
                                });
                              }}
                            />
                          </td>
                        ))}
                        <td className={td}>
                          <RowTools
                            index={i}
                            size={draft.story.questions.length}
                            marks={placement?.marks.get(`story:${i}`)}
                            lessonHref={lessonHref}
                            onMove={(d) =>
                              set('story', {
                                ...draft.story,
                                questions: moveAt(draft.story.questions, i, d),
                              })
                            }
                            onRemove={() =>
                              set('story', {
                                ...draft.story,
                                questions: removeAt(draft.story.questions, i),
                              })
                            }
                          />
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
              </div>
              <ShowMore
                total={draft.story.questions.length}
                shown={shownRows('story', draft.story.questions.length)}
                onMore={() => showMore('story', shownRows('story', draft.story.questions.length))}
              />
              <AddRow
                label="Thêm câu hỏi đọc hiểu"
                onClick={() => {
                  revealRows('story', draft.story.questions.length + 1);
                  set('story', {
                    ...draft.story,
                    questions: [
                      ...draft.story.questions,
                      { q: '', correct: '', wrongs: ['', ''] } satisfies StoryQuestionRow,
                    ],
                  });
                }}
              />
            </section>
          )}

          {tab === 'basics' && (
            <section className={`${card} space-y-4 p-4`}>
              <p className={hint}>Những gì người học thấy đầu tiên khi mở bài.</p>
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="text-xs text-fg-4">
                  Tên bài học
                  <input
                    className={field}
                    value={draft.title}
                    placeholder="Chào hỏi"
                    onChange={(e) => set('title', e.target.value)}
                  />
                </label>
                <label className="text-xs text-fg-4">
                  Trình độ
                  <select
                    className={field}
                    value={draft.cefr}
                    onChange={(e) => set('cefr', e.target.value as Cefr)}
                  >
                    {['A1', 'A2', 'B1', 'B2'].map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              {advanced && (
                <label className="block text-xs text-fg-4">
                  Chủ đề của bài
                  <span className="block font-normal text-fg-4">
                    Dùng để xếp bài vào phần học. Đổi mã này thì bài rời khỏi phần đang chứa nó.
                  </span>
                  <input
                    className={field}
                    value={draft.theme}
                    placeholder="greetings"
                    onChange={(e) => set('theme', e.target.value)}
                  />
                </label>
              )}
              <label className="block text-xs text-fg-4">
                Mẹo học cho người học
                <textarea
                  rows={8}
                  className={field}
                  value={draft.guide}
                  placeholder="Người mới thường ngại chào trước…"
                  onChange={(e) => set('guide', e.target.value)}
                />
              </label>
              <div className="grid grid-cols-5 gap-3">
                {draft.levels.map((level, i) => (
                  <label className="text-xs text-fg-4" key={i}>
                    Tên mức {i + 1}
                    <input
                      className={field}
                      value={level}
                      onChange={(e) => set('levels', replace(draft.levels, i, e.target.value))}
                    />
                  </label>
                ))}
              </div>
            </section>
          )}

          {tab === 'media' && mediaPanel}

          {tab === 'preview' && (
            <DraftPreview
              draft={draft}
              dirty={dirty}
              scope={previewScope}
              onScope={setPreviewScope}
              section={contentTab}
              row={contentTab === 'sentences' ? openRow : null}
            />
          )}

          {tab === 'file' && (
            <section className={`${card} p-4`}>
              <p className={cn(hint, 'mb-3')}>
                Tệp máy dựng ghi ra từ bài này. Chỉ mở khi cần đối chiếu với app.
              </p>
              <p className="text-xs text-fg-4">
                <code className="text-fg">
                  {renderUnitFile(order, normalize(draft)).fileName}
                </code>
              </p>
              <pre
                className={cn(log, 'mt-3 max-h-[36rem] overflow-auto leading-relaxed text-fg-2')}
              >
                {renderUnitFile(order, normalize(draft)).source}
              </pre>
            </section>
          )}
        </ViewTransition>
      </div>
    </PageTransition>
  );
}
