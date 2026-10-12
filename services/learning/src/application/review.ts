// P6-REVIEW-001: review scheduling state, due list and the private dynamic review bundle
// (SRS review heuristic; FR-PRACTICE-001/002). REVIEW sessions use lessonId=review_dynamic and a
// private snapshot (5-20 items, <=64KB) stored on the session row, never a public bundle.
import { createHash } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import { canonicalJson } from '../content/integrity.js';
import type { CourseManifest, Exercise, LessonBundle } from '../content/types.js';
import type { EnrollmentView } from '../domain/path.js';
import { applyEvidence, masteryOf, orderDue, type ReviewState } from '../domain/review.js';
import type { AttemptRecord } from '../domain/session-queue.js';
import { ids } from '../persistence/ids.js';
import type { LearningTransaction, Row } from '../persistence/port.js';
import { unresolvedMistakeIds } from './practice.js';
import { decodeCursor, encodeCursor, iso, jsonArray, type LearningDeps } from './deps.js';

export const REVIEW_LESSON_ID = 'review_dynamic';
export const REVIEW_MIN = 5;
export const REVIEW_MAX = 20;
const SNAPSHOT_LIMIT = 65536;
const MAX_VOCAB_UPDATES = 30;

function stateFromRow(row: Row | null): ReviewState | null {
  if (!row) return null;
  return {
    stage: Number(row['stage']),
    dueAt: String(row['dueAt']),
    window: (JSON.parse(String(row['firstAttemptWindowJson'] || '[]')) as unknown[]).map(Boolean),
    correctCount: Number(row['correctCount']),
    incorrectCount: Number(row['incorrectCount']),
    halfLifeHours: Number(row['halfLifeHours']),
    lastReviewedAt: String(row['lastReviewedAt']),
    firstSeenAt: String(row['firstSeenAt']),
  };
}

/**
 * Stage review updates for a finished session. Evidence per vocabulary item comes only from first
 * attempts (ordinal 0): correct iff every first attempt touching it was correct; assisted if any was.
 */
export async function stageReviewUpdates(
  tx: LearningTransaction,
  input: {
    userId: string;
    courseId: string;
    exercises: readonly Exercise[];
    attempts: readonly AttemptRecord[];
    advance: boolean;
    nowMs: number;
  },
): Promise<number> {
  const evidence = new Map<string, { correct: boolean; assisted: boolean; skillId: string }>();
  for (const exercise of input.exercises) {
    const first = input.attempts.find(
      (a) => a.exerciseId === exercise.id && a.attemptOrdinal === 0,
    );
    if (!first) continue;
    for (const vocabularyId of exercise.vocabularyIds) {
      const prev = evidence.get(vocabularyId);
      evidence.set(vocabularyId, {
        correct: (prev?.correct ?? true) && first.correct,
        assisted: (prev?.assisted ?? false) || first.assisted,
        skillId: prev?.skillId ?? exercise.skillIds[0] ?? 'general',
      });
    }
  }
  let staged = 0;
  for (const [vocabularyId, item] of [...evidence].slice(0, MAX_VOCAB_UPDATES)) {
    const rowId = ids.review(input.userId, input.courseId, vocabularyId);
    const previousRow = await tx.get('l_review_items', rowId);
    const next = applyEvidence(stateFromRow(previousRow), item, input.nowMs, input.advance);
    const at = iso(input.nowMs);
    tx.put('l_review_items', rowId, {
      userId: input.userId,
      courseId: input.courseId,
      vocabularyId,
      skillId: previousRow ? String(previousRow['skillId']) : item.skillId,
      stage: next.stage,
      dueAt: next.dueAt,
      firstAttemptWindowJson: JSON.stringify(next.window),
      lastReviewedAt: next.lastReviewedAt,
      firstSeenAt: next.firstSeenAt,
      correctCount: next.correctCount,
      incorrectCount: next.incorrectCount,
      halfLifeHours: next.halfLifeHours,
      revision: previousRow ? Number(previousRow['revision']) + 1 : 0,
      createdAt: previousRow ? String(previousRow['createdAt']) : at,
      updatedAt: at,
    });
    staged++;
  }
  return staged;
}

export async function dueItems(
  deps: LearningDeps,
  userId: string,
  courseId: string | undefined,
  max: number,
) {
  const result = await deps.persistence.list('l_review_items', {
    equal: { userId, ...(courseId ? { courseId } : {}) },
    lessThanEqual: { dueAt: iso(deps.nowMs()) },
    orderAsc: 'dueAt',
    limit: 100,
  });
  const candidates = result.items.map(({ row }) => ({
    vocabularyId: String(row['vocabularyId']),
    skillId: String(row['skillId']),
    dueAt: String(row['dueAt']),
    stage: Number(row['stage']),
    lastMistakeAt: Number(row['incorrectCount']) > 0 ? String(row['lastReviewedAt']) : null,
    mastery: masteryOf(
      (JSON.parse(String(row['firstAttemptWindowJson'] || '[]')) as unknown[]).map(Boolean),
    ),
  }));
  return orderDue(candidates, max);
}

export async function getReview(
  deps: LearningDeps,
  userId: string,
  courseId: string | undefined,
  cursor: string | undefined,
  limit: number,
) {
  const offset = decodeCursor(cursor);
  if (offset < 0) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
  const ordered = await dueItems(deps, userId, courseId, 100);
  const page = ordered.slice(offset, offset + limit);
  return {
    items: page.map((item) => ({
      vocabularyId: item.vocabularyId,
      skillId: item.skillId,
      dueAt: item.dueAt,
      stage: item.stage,
      mastery: item.mastery,
    })),
    nextCursor: offset + page.length < ordered.length ? encodeCursor(offset + page.length) : null,
    asOf: iso(deps.nowMs()),
  };
}

/**
 * Build the private review bundle: due vocabulary first (one authored exercise each, from lessons
 * the learner has completed), padded with recent completed-lesson exercises up to 5; at most 20.
 */
export async function buildReviewBundle(
  deps: LearningDeps,
  input: {
    userId: string;
    courseId: string;
    manifest: CourseManifest;
    enrollment: EnrollmentView;
    sessionKey: string;
  },
): Promise<{ bundle: LessonBundle; text: string; hash: string }> {
  const { manifest, enrollment } = input;
  const completedLessons = manifest.nodes
    .filter(
      (node) =>
        node.order < enrollment.frontierNodeOrder ||
        node.lessonIds.some((id) => enrollment.completedLessonIds.includes(id)),
    )
    .flatMap((node) =>
      node.lessonIds.filter(
        (id) =>
          node.order < enrollment.frontierNodeOrder || enrollment.completedLessonIds.includes(id),
      ),
    );
  if (!completedLessons.length)
    throw new ServiceError('NOT_FOUND', { details: { reason: 'REVIEW_POOL_EMPTY' } });
  const sources: LessonBundle[] = [];
  for (const lessonId of completedLessons)
    sources.push((await deps.content.bundle(manifest, lessonId)).bundle);
  const due = await dueItems(deps, input.userId, input.courseId, REVIEW_MAX);
  const picked = new Map<string, { exercise: Exercise; source: LessonBundle }>();
  // Unresolved mistakes first (P6-REVIEW-002), then due vocabulary, then recent padding.
  for (const exerciseId of await unresolvedMistakeIds(deps, input.userId, input.courseId, 10)) {
    for (const source of sources) {
      const match = source.exercises.find((e) => e.id === exerciseId);
      if (match) {
        picked.set(match.id, { exercise: match, source });
        break;
      }
    }
  }
  for (const item of due) {
    for (const source of sources) {
      const match = source.exercises.find(
        (e) => e.vocabularyIds.includes(item.vocabularyId) && !picked.has(e.id),
      );
      if (match) {
        picked.set(match.id, { exercise: match, source });
        break;
      }
    }
  }
  for (const source of [...sources].reverse()) {
    if (picked.size >= REVIEW_MIN) break;
    for (const exercise of source.exercises) {
      if (picked.size >= REVIEW_MIN) break;
      if (!picked.has(exercise.id)) picked.set(exercise.id, { exercise, source });
    }
  }
  let chosen = [...picked.values()].slice(0, REVIEW_MAX);
  if (chosen.length < REVIEW_MIN)
    throw new ServiceError('NOT_FOUND', { details: { reason: 'REVIEW_POOL_EMPTY' } });
  const first = chosen[0]!.source;
  const make = (items: typeof chosen): LessonBundle => {
    const exercises = items.map((c) => c.exercise);
    const assetIds = new Set(
      exercises.flatMap((e) => [
        e.prompt.audioAssetId,
        ...((e.content as { choices?: { imageAssetId?: string | null }[] }).choices ?? []).map(
          (c) => c.imageAssetId,
        ),
      ]),
    );
    const assets = [
      ...new Map(
        items
          .flatMap((c) => c.source.assets)
          .filter((a) => assetIds.has(a.fileId))
          .map((a) => [a.fileId, a]),
      ).values(),
    ];
    // Slow-speed variants travel with their normal-speed audio.
    for (const source of items.map((c) => c.source)) {
      for (const asset of source.assets) {
        if (
          asset.fileId.endsWith('.s') &&
          assetIds.has(`${asset.fileId.slice(0, -2)}.n`) &&
          !assets.some((a) => a.fileId === asset.fileId)
        ) {
          assets.push(asset);
        }
      }
    }
    const unsigned = {
      schemaVersion: 1 as const,
      courseId: input.courseId,
      courseVersion: manifest.courseVersion,
      sectionId: first.sectionId,
      unitId: first.unitId,
      nodeId: first.nodeId,
      order: 0,
      lessonId: REVIEW_LESSON_ID,
      lessonVersion: `review.${createHash('sha256').update(input.sessionKey).digest('hex').slice(0, 20)}`,
      rewardIdentity: REVIEW_LESSON_ID,
      title: 'Ôn tập',
      skillIds: [...new Set(exercises.flatMap((e) => e.skillIds))].slice(0, 20),
      exercises,
      assets: assets.slice(0, 100),
      gradingRulesVersion: first.gradingRulesVersion,
      manifestHash: manifest.manifestHash,
    };
    // Server-generated private snapshot: no author key exists for it. The "signature" is a
    // SHA-512 integrity digest (base64url, 86 chars) under the explicit key ID below.
    const signature = createHash('sha512').update(canonicalJson(unsigned)).digest('base64url');
    return { ...unsigned, signatureKeyId: 'server-snapshot-sha512', signature };
  };
  let bundle = make(chosen);
  let text = canonicalJson(bundle);
  while (text.length > SNAPSHOT_LIMIT && chosen.length > REVIEW_MIN) {
    chosen = chosen.slice(0, -1);
    bundle = make(chosen);
    text = canonicalJson(bundle);
  }
  if (text.length > SNAPSHOT_LIMIT)
    throw new ServiceError('INTERNAL_ERROR', { details: { reason: 'REVIEW_SNAPSHOT_TOO_LARGE' } });
  return { bundle, text, hash: createHash('sha256').update(text).digest('hex') };
}

export function completedLessonIdsOf(row: Row): string[] {
  return jsonArray(row['completedLessonsJson']);
}
