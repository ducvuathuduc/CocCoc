// createReport (FR-LESSON-005): queue a content/answer/audio report; never blocks the lesson.
import { ids } from '../persistence/ids.js';
import { created, type LearningDeps } from './deps.js';

export interface ReportBody {
  exerciseId: string;
  lessonVersion: string;
  category: 'CONTENT' | 'ANSWER' | 'AUDIO' | 'OTHER';
  note?: string;
}

export function createReport(
  deps: LearningDeps,
  userId: string,
  body: ReportBody,
  key: string,
  bodyHash: string,
  requestId: string,
) {
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'createReport', key },
    bodyHash,
    async (tx) => {
      tx.put('l_reports', ids.report(userId, key), {
        userId,
        exerciseId: body.exerciseId,
        lessonVersion: body.lessonVersion,
        category: body.category,
        note: (body.note ?? '').slice(0, 512),
        status: 'OPEN',
        ...created(deps.nowMs()),
      });
      return { statusCode: 202, response: { operationId: key, status: 'accepted', requestId } };
    },
  );
}
