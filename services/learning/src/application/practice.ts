// P6-REVIEW-002: Practice Hub mistakes and words; P7-PRACTICE-001 read side (activity library).
// Mistakes are captured in the completion transaction (<=10 per session), resolved by a correct
// first attempt in a REVIEW/MASTERY session, and capped at 100 unresolved per course (oldest evicted).
import { ServiceError } from '../../../shared/src/errors.js';
import type { CourseManifest, Exercise, LessonBundle } from '../content/types.js';
import type { AttemptRecord } from '../domain/session-queue.js';
import { rowId } from '../persistence/ids.js';
import type { LearningTransaction } from '../persistence/port.js';
import { decodeCursor, encodeCursor, iso, type LearningDeps } from './deps.js';

export const MAX_MISTAKES_PER_SESSION = 10;
export const MAX_UNRESOLVED = 100;

export const mistakeId = (userId: string, courseId: string, exerciseId: string) =>
  rowId('mistake', userId, courseId, exerciseId);

export async function stageMistakes(
  deps: LearningDeps,
  tx: LearningTransaction,
  input: {
    userId: string;
    courseId: string;
    sessionId: string;
    mode: string;
    exercises: readonly Exercise[];
    attempts: readonly AttemptRecord[];
    lessonVersionOf: (exerciseId: string) => string;
    nowMs: number;
  },
): Promise<void> {
  const at = iso(input.nowMs);
  const firstOf = (id: string) =>
    input.attempts.find((a) => a.exerciseId === id && a.attemptOrdinal === 0);
  let created = 0;
  let captured = 0;
  for (const exercise of input.exercises) {
    const first = firstOf(exercise.id);
    if (!first) continue;
    const id = mistakeId(input.userId, input.courseId, exercise.id);
    if (!first.correct) {
      if (captured >= MAX_MISTAKES_PER_SESSION) continue;
      captured++;
      const previous = await tx.get('l_mistakes', id);
      if (!previous || previous['resolvedAt']) created++;
      tx.put('l_mistakes', id, {
        userId: input.userId,
        courseId: input.courseId,
        exerciseId: exercise.id,
        lessonVersion: input.lessonVersionOf(exercise.id),
        skillId: exercise.skillIds[0] ?? 'general',
        lastSessionId: input.sessionId,
        mistakeCount: Number(previous?.['mistakeCount'] ?? 0) + 1,
        lastMistakeAt: at,
        resolvedAt: null,
        revision: previous ? Number(previous['revision']) + 1 : 0,
        createdAt: previous ? String(previous['createdAt']) : at,
        updatedAt: at,
      });
    } else if ((input.mode === 'REVIEW' || input.mode === 'MASTERY') && !first.assisted) {
      const previous = await tx.get('l_mistakes', id);
      if (previous && !previous['resolvedAt']) {
        tx.put('l_mistakes', id, {
          ...previous,
          resolvedAt: at,
          revision: Number(previous['revision']) + 1,
          updatedAt: at,
        });
      }
    }
  }
  if (!created) return;
  const unresolved = await deps.persistence.list('l_mistakes', {
    equal: { userId: input.userId, courseId: input.courseId },
    isNull: ['resolvedAt'],
    orderAsc: 'lastMistakeAt',
    limit: MAX_MISTAKES_PER_SESSION,
  });
  const excess = unresolved.total + created - MAX_UNRESOLVED;
  for (const item of unresolved.items.slice(0, Math.max(0, excess)))
    tx.remove('l_mistakes', item.id);
}

function pageArgs(cursor: string | undefined) {
  const offset = decodeCursor(cursor);
  if (offset < 0) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
  return offset;
}

export async function listMistakes(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  includeResolved: boolean,
  cursor: string | undefined,
  limit: number,
) {
  const offset = pageArgs(cursor);
  const page = await deps.persistence.list('l_mistakes', {
    equal: { userId, courseId },
    ...(includeResolved ? {} : { isNull: ['resolvedAt'] }),
    orderDesc: 'lastMistakeAt',
    limit,
    offset,
  });
  return {
    items: page.items.map(({ row }) => ({
      courseId: String(row['courseId']),
      exerciseId: String(row['exerciseId']),
      lessonVersion: String(row['lessonVersion']),
      skillId: String(row['skillId']),
      mistakeCount: Number(row['mistakeCount']),
      lastMistakeAt: String(row['lastMistakeAt']),
      resolvedAt: row['resolvedAt'] ? String(row['resolvedAt']) : null,
    })),
    nextCursor:
      offset + page.items.length < page.total ? encodeCursor(offset + page.items.length) : null,
    asOf: iso(deps.nowMs()),
  };
}

/** Unresolved mistakes, most recent first (feeds the review bundle). */
export async function unresolvedMistakeIds(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  max: number,
): Promise<string[]> {
  const page = await deps.persistence.list('l_mistakes', {
    equal: { userId, courseId },
    isNull: ['resolvedAt'],
    orderDesc: 'lastMistakeAt',
    limit: max,
  });
  return page.items.map(({ row }) => String(row['exerciseId']));
}

/**
 * Lexicon from published content. Convention of the course generator: a matchPairs exercise whose
 * vocabularyIds has one entry per pair lists them in pair order (left = English term, right =
 * Vietnamese translation). Unmapped IDs fall back to the ID's last segment and a null translation.
 */
const lexicons = new WeakMap<
  CourseManifest,
  Map<string, { term: string; translation: string | null }>
>();
const lexiconBuilds = new WeakMap<
  CourseManifest,
  Promise<Map<string, { term: string; translation: string | null }>>
>();
const LEXICON_BATCH_SIZE = 8;
export async function lexiconOf(deps: LearningDeps, manifest: CourseManifest) {
  const cached = lexicons.get(manifest);
  if (cached) return cached;
  const pending = lexiconBuilds.get(manifest);
  if (pending) return pending;
  const building = buildLexicon(deps, manifest);
  lexiconBuilds.set(manifest, building);
  try {
    const result = await building;
    lexicons.set(manifest, result);
    return result;
  } finally {
    if (lexiconBuilds.get(manifest) === building) lexiconBuilds.delete(manifest);
  }
}

async function buildLexicon(deps: LearningDeps, manifest: CourseManifest) {
  const map = new Map<string, { term: string; translation: string | null }>();
  for (let offset = 0; offset < manifest.bundles.length; offset += LEXICON_BATCH_SIZE) {
    const indexes = manifest.bundles.slice(offset, offset + LEXICON_BATCH_SIZE);
    // Settle the whole batch before propagating a failure so a subsequent
    // retry cannot overlap outstanding reads from the failed attempt.
    const results = await Promise.allSettled(
      indexes.map(async (index) => (await deps.content.bundle(manifest, index.lessonId)).bundle),
    );
    for (const result of results) if (result.status === 'rejected') throw result.reason;
    // Retain manifest order even if I/O completes out of order: first mapping wins.
    for (const result of results) {
      if (result.status !== 'fulfilled') continue;
      const bundle: LessonBundle = result.value;
      for (const exercise of bundle.exercises) {
        const pairs = (
          exercise.content as { pairs?: { left: { text: string }; right: { text: string } }[] }
        ).pairs;
        if (
          exercise.type !== 'matchPairs' ||
          !pairs ||
          pairs.length !== exercise.vocabularyIds.length
        )
          continue;
        exercise.vocabularyIds.forEach((vocabularyId, k) => {
          const pair = pairs[k];
          if (pair && !map.has(vocabularyId))
            map.set(vocabularyId, {
              term: pair.left.text.slice(0, 120),
              translation: pair.right.text.slice(0, 160),
            });
        });
      }
    }
  }
  return map;
}

/** Half-life strength 0..4: 4 x 2^(-elapsed/halfLife), rounded (HLR-style recall estimate). */
export function strengthOf(
  halfLifeHours: number,
  lastReviewedAt: string | null,
  nowMs: number,
): number {
  if (!lastReviewedAt || halfLifeHours <= 0) return 0;
  const elapsedHours = Math.max(0, (nowMs - Date.parse(lastReviewedAt)) / 3_600_000);
  return Math.max(0, Math.min(4, Math.round(4 * 2 ** (-elapsedHours / halfLifeHours))));
}

export async function listWords(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  sort: 'RECENT' | 'ALPHABETICAL',
  cursor: string | undefined,
  limit: number,
) {
  const offset = pageArgs(cursor);
  const { manifest } = await deps.content.published(courseId);
  const lexicon = await lexiconOf(deps, manifest);
  const all = await deps.persistence.list('l_review_items', {
    equal: { userId, courseId },
    orderDesc: 'lastReviewedAt',
    limit: 2000,
  });
  const now = deps.nowMs();
  const words = all.items.map(({ row }) => {
    const vocabularyId = String(row['vocabularyId']);
    const entry = lexicon.get(vocabularyId);
    const lastReviewedAt = row['lastReviewedAt'] ? String(row['lastReviewedAt']) : null;
    return {
      courseId,
      vocabularyId,
      skillId: String(row['skillId']),
      term: entry?.term ?? vocabularyId.split('.').at(-1) ?? vocabularyId,
      translation: entry?.translation ?? null,
      stage: Number(row['stage']),
      strength: strengthOf(Number(row['halfLifeHours']), lastReviewedAt, now),
      halfLifeHours: Number(row['halfLifeHours']),
      correctCount: Number(row['correctCount']),
      incorrectCount: Number(row['incorrectCount']),
      firstSeenAt: String(row['firstSeenAt']),
      lastReviewedAt,
      dueAt: String(row['dueAt']),
    };
  });
  if (sort === 'ALPHABETICAL')
    words.sort(
      (a, b) => a.term.localeCompare(b.term, 'en') || a.vocabularyId.localeCompare(b.vocabularyId),
    );
  const page = words.slice(offset, offset + limit);
  return {
    items: page,
    nextCursor: offset + page.length < words.length ? encodeCursor(offset + page.length) : null,
    asOf: iso(now),
  };
}

export async function listActivityProgress(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  kind: string | undefined,
  cursor: string | undefined,
  limit: number,
) {
  const offset = pageArgs(cursor);
  const page = await deps.persistence.list('l_activity_progress', {
    equal: { userId, courseId, ...(kind ? { kind } : {}) },
    orderAsc: 'activityId',
    limit,
    offset,
  });
  return {
    items: page.items.map(({ row }) => ({
      courseId: String(row['courseId']),
      kind: String(row['kind']),
      activityId: String(row['activityId']),
      completions: Number(row['completions']),
      bestScore: Number(row['bestScore']),
      stars: Number(row['stars']),
      firstCompletedAt: row['firstCompletedAt'] ? String(row['firstCompletedAt']) : null,
      lastCompletedAt: row['lastCompletedAt'] ? String(row['lastCompletedAt']) : null,
    })),
    nextCursor:
      offset + page.items.length < page.total ? encodeCursor(offset + page.items.length) : null,
    asOf: iso(deps.nowMs()),
  };
}
