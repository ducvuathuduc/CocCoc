// P4-LEARN-002: enrollCourse / placement result / getPath (FR-COURSE-002, FR-PATH-001).
import { ServiceError } from '../../../shared/src/errors.js';
import { nodeState, placementFrontier, sortedNodes, type EnrollmentView } from '../domain/path.js';
import { PLACEMENT_PASS } from '../domain/session-queue.js';
import { ids } from '../persistence/ids.js';
import type { LearningTransaction, Row } from '../persistence/port.js';
import {
  bumped,
  created,
  decodeCursor,
  encodeCursor,
  iso,
  jsonArray,
  jsonObject,
  type LearningDeps,
} from './deps.js';

export interface EnrollBody {
  courseId: string;
  startPoint: 'beginner' | 'placement';
  placementSessionId?: string | null;
}

export function enrollmentView(
  row: Row,
): EnrollmentView & { courseId: string; courseVersion: string; revision: number } {
  return {
    courseId: String(row['courseId']),
    courseVersion: String(row['courseVersion']),
    frontierNodeOrder: Number(row['frontierNodeOrder']),
    completedLessonIds: jsonArray(row['completedLessonsJson']),
    masteredNodeIds: jsonArray(row['masteredNodesJson']),
    revision: Number(row['revision']),
  };
}

export function enrollmentDto(row: Row) {
  const view = enrollmentView(row);
  return {
    courseId: view.courseId,
    courseVersion: view.courseVersion,
    frontierNodeOrder: view.frontierNodeOrder,
    completedLessonIds: view.completedLessonIds.slice(-1200),
    masteredNodeIds: view.masteredNodeIds.slice(0, 600),
    revision: view.revision,
  };
}

/** Active, non-removed enrollment row (or null). */
export function activeEnrollment(row: Row | null): Row | null {
  return row && !row['removedAt'] ? row : null;
}

export async function enrollCourse(
  deps: LearningDeps,
  userId: string,
  body: EnrollBody,
  key: string,
  bodyHash: string,
) {
  const { manifest } = await deps.content.published(body.courseId);
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'enrollCourse', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const rowId = ids.enrollment(userId, body.courseId);
      const existing = activeEnrollment(await tx.get('l_enrollments', rowId));
      if (existing) {
        // Re-enrolling never regresses or re-runs placement: return the current frontier.
        return { statusCode: 200, response: enrollmentDto(existing) };
      }
      let frontier = placementFrontier(manifest, false);
      if (body.startPoint === 'placement') {
        if (!body.placementSessionId) {
          throw new ServiceError('VALIDATION_ERROR', { details: { field: 'placementSessionId' } });
        }
        const session = await tx.get('l_sessions', body.placementSessionId);
        if (!session || session['userId'] !== userId)
          throw new ServiceError('NOT_FOUND', { details: { field: 'placementSessionId' } });
        if (
          session['mode'] !== 'PLACEMENT' ||
          session['courseId'] !== body.courseId ||
          session['status'] !== 'COMPLETED'
        ) {
          throw new ServiceError('VALIDATION_ERROR', {
            details: { field: 'placementSessionId', reason: 'NOT_A_COMPLETED_PLACEMENT' },
          });
        }
        const result = jsonObject<{ completion?: { originalCorrect?: number } }>(
          session['resultJson'],
        );
        frontier = placementFrontier(
          manifest,
          (result?.completion?.originalCorrect ?? 0) >= PLACEMENT_PASS,
        );
      }
      // Exactly one active enrollment per user: switching course deactivates the others.
      const others = await deps.persistence.list('l_enrollments', {
        equal: { userId, active: true },
        limit: 20,
      });
      for (const other of others.items) {
        if (other.id === rowId) continue;
        const fresh = await tx.get('l_enrollments', other.id);
        if (fresh?.['active'])
          tx.put('l_enrollments', other.id, { ...fresh, active: false, ...bumped(fresh, now) });
      }
      const previous = await tx.get('l_enrollments', rowId); // a removed enrollment is revived in place
      const row = {
        userId,
        courseId: body.courseId,
        courseVersion: manifest.courseVersion,
        frontierNodeOrder: frontier,
        completedLessonsJson: '[]',
        masteredNodesJson: '[]',
        legendaryNodesJson: '[]',
        placementUsed: body.startPoint === 'placement',
        active: true,
        proficiencyScore: 0,
        lastPracticedAt: null,
        removedAt: null,
        ...(previous
          ? { createdAt: previous['createdAt'], ...bumped(previous, now) }
          : created(now)),
      };
      tx.put('l_enrollments', rowId, row);
      return { statusCode: 200, response: enrollmentDto(row) };
    },
  );
}

export async function getPath(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  cursor: string | undefined,
  limit: number,
) {
  const offset = decodeCursor(cursor);
  if (offset < 0) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
  const row = activeEnrollment(
    await deps.persistence.read('l_enrollments', ids.enrollment(userId, courseId)),
  );
  if (!row) throw new ServiceError('NOT_FOUND', { details: { courseId, reason: 'NOT_ENROLLED' } });
  const { manifest } = await deps.content.published(courseId);
  const view = enrollmentView(row);
  const nodes = sortedNodes(manifest);
  const page = nodes.slice(offset, offset + limit);
  return {
    enrollment: enrollmentDto(row),
    nodes: page.map((node) => ({
      nodeId: node.nodeId,
      unitId: node.unitId,
      sectionId: node.sectionId,
      order: node.order,
      title: node.title,
      kind: node.kind,
      state: nodeState(node, view),
      lessonIds: node.lessonIds,
    })),
    asOf: iso(deps.nowMs()),
    nextCursor: offset + page.length < nodes.length ? encodeCursor(offset + page.length) : null,
  };
}

// P4-LEARN-003: switchCourse / resetCourse / removeCourse. Commands carry the target enrollment's
// revision; reset/remove never touch Progress-owned XP or rewards.
type EnrollmentCommand = 'switchCourse' | 'resetCourse' | 'removeCourse';

/** Prevent a pre-reset session from later restoring progress or issuing rewards. */
async function abandonActiveSession(
  tx: LearningTransaction,
  userId: string,
  courseId: string,
  now: number,
): Promise<void> {
  const slotId = ids.slot(userId, courseId);
  const slot = await tx.get('l_active_slots', slotId);
  if (!slot) return;
  const sessionId = String(slot['sessionId']);
  const session = await tx.get('l_sessions', sessionId);
  if (
    session &&
    session['userId'] === userId &&
    session['courseId'] === courseId &&
    session['status'] === 'ACTIVE'
  ) {
    tx.put('l_sessions', sessionId, {
      ...session,
      status: Date.parse(String(session['expiresAt'])) <= now ? 'EXPIRED' : 'ABANDONED',
      ...bumped(session, now),
    });
  }
  tx.remove('l_active_slots', slotId);
}

export async function enrollmentCommand(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  command: EnrollmentCommand,
  expectedRevision: number | null,
  key: string,
  bodyHash: string,
  requestId: string,
) {
  const manifest =
    command === 'resetCourse' ? (await deps.content.published(courseId)).manifest : null;
  return deps.persistence.commitWithReceipt(
    { userId, operation: command, key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const rowId = ids.enrollment(userId, courseId);
      const row = activeEnrollment(await tx.get('l_enrollments', rowId));
      if (!row)
        throw new ServiceError('NOT_FOUND', { details: { courseId, reason: 'NOT_ENROLLED' } });
      if (expectedRevision !== null && Number(row['revision']) !== expectedRevision) {
        throw new ServiceError('REVISION_CONFLICT', {
          details: { currentRevision: Number(row['revision']) },
        });
      }
      if (command === 'removeCourse') {
        await abandonActiveSession(tx, userId, courseId, now);
        tx.put('l_enrollments', rowId, {
          ...row,
          active: false,
          removedAt: iso(now),
          ...bumped(row, now),
        });
        return { statusCode: 200, response: { operationId: key, status: 'accepted', requestId } };
      }
      if (command === 'switchCourse') {
        const others = await deps.persistence.list('l_enrollments', {
          equal: { userId, active: true },
          limit: 20,
        });
        for (const other of others.items) {
          if (other.id === rowId) continue;
          const fresh = await tx.get('l_enrollments', other.id);
          if (fresh?.['active'])
            tx.put('l_enrollments', other.id, { ...fresh, active: false, ...bumped(fresh, now) });
        }
        const next = { ...row, active: true, ...bumped(row, now) };
        tx.put('l_enrollments', rowId, next);
        return { statusCode: 200, response: enrollmentDto(next) };
      }
      await abandonActiveSession(tx, userId, courseId, now);
      const next = {
        ...row,
        courseVersion: manifest!.courseVersion,
        frontierNodeOrder: placementFrontier(manifest!, false),
        completedLessonsJson: '[]',
        masteredNodesJson: '[]',
        legendaryNodesJson: '[]',
        proficiencyScore: 0,
        ...bumped(row, now),
      };
      tx.put('l_enrollments', rowId, next);
      return { statusCode: 200, response: enrollmentDto(next) };
    },
  );
}
