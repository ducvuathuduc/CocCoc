// Recorded pronunciation assessment (FR-SPEECH-003). Azure is disabled in this build, so the job
// completes immediately with a null-score result (scoreState NULL_UNAVAILABLE): numerical
// pronunciation comes only from a dedicated valid scorer, never from a mock number. The WAV is
// validated and hashed, never stored. Owner-only reads.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { ids } from '../persistence/ids.js';
import { validateWav } from './audio.js';
import { iso, sha256Hex, stamp, type AiDeps } from './deps.js';
import { countUsage } from './usage.js';

export const ASSESSMENT_TTL_MS = 24 * 60 * 60 * 1000;

export interface AssessmentInput {
  jobId: string;
  referenceExerciseId: string;
  lessonVersion: string;
  locale: 'en-US';
  wavBase64: string;
  audioSha256: string;
}

export async function createAssessment(
  deps: AiDeps,
  userId: string,
  input: AssessmentInput,
  idempotencyKey: string,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  const seconds = validateWav(input.wavBase64, input.audioSha256);
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'createAssessment', key: idempotencyKey },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const id = ids.job(userId, input.jobId);
      if (await tx.get('a_jobs', id)) {
        throw new ServiceError('IDEMPOTENCY_CONFLICT', { details: { field: 'jobId' } });
      }
      await countUsage(tx, userId, now, { recordedSpeechSeconds: seconds });
      const expiresAt = iso(now + ASSESSMENT_TTL_MS);
      const result = {
        jobId: input.jobId,
        status: 'SUCCEEDED',
        transcript: null,
        accuracy: null,
        fluency: null,
        completeness: null,
        prosody: null,
        words: [],
        scorer: null,
        scoreVersion: null,
        unavailableReason: deps.provider.azureEnabled ? null : 'AZURE_DISABLED',
        expiresAt,
        scoreState: 'NULL_UNAVAILABLE',
        locale: input.locale,
        referenceHash: sha256Hex(`${input.referenceExerciseId}|${input.lessonVersion}`),
        provider: null,
        modelVersion: null,
        miscues: [],
      };
      tx.put(
        'a_jobs',
        id,
        stamp(
          null,
          {
            userId,
            jobId: input.jobId,
            kind: 'ASSESSMENT',
            status: 'SUCCEEDED',
            referenceId: input.referenceExerciseId,
            locale: input.locale,
            inputHash: input.audioSha256,
            audioFileId: null,
            leaseUntil: null,
            attempt: 1,
            dispatchState: 'NOT_SENT',
            reservedSeconds: 0,
            chargedSeconds: 0,
            resultJson: JSON.stringify(result),
            expiresAt,
          },
          now,
        ),
      );
      return { statusCode: 202, response: result };
    },
  );
}

export async function getAssessment(deps: AiDeps, userId: string, jobId: string) {
  const row = await deps.persistence.read('a_jobs', ids.job(userId, jobId));
  if (!row || row['userId'] !== userId || row['kind'] !== 'ASSESSMENT') {
    throw new ServiceError('NOT_FOUND');
  }
  const result = JSON.parse(String(row['resultJson'])) as Record<string, unknown>;
  if (Date.parse(String(row['expiresAt'])) <= deps.nowMs()) {
    return { ...result, status: 'EXPIRED' };
  }
  return result;
}
