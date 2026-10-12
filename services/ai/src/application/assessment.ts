// Recorded pronunciation assessment (FR-SPEECH-003). With the speech provider and an Azure key the
// WAV is scored synchronously by Azure Pronunciation Assessment against the exercise reference
// text (accuracy/fluency/completeness/prosody, per-word + per-phoneme) and stored as a SUCCEEDED
// job; otherwise the job completes with a null-score result (NULL_UNAVAILABLE): numerical
// pronunciation comes only from a dedicated valid scorer, never from a mock number. The WAV is
// validated and hashed, never stored. The provider call happens before the receipt transaction
// (never inside a retried closure); a replayed job id or receipt never calls the provider again.
// Owner-only reads.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { ids } from '../persistence/ids.js';
import { validateWav } from './audio.js';
import { iso, sha256Hex, stamp, type AiDeps } from './deps.js';
import { AZURE_SCORE_VERSION, AZURE_SCORER, nullScore, type Scored } from './speech.js';
import { countUsage, DAILY_RECORDED_SECONDS } from './usage.js';

export const ASSESSMENT_TTL_MS = 24 * 60 * 60 * 1000;

export interface AssessmentInput {
  jobId: string;
  referenceExerciseId: string;
  lessonVersion: string;
  locale: 'en-US';
  wavBase64: string;
  audioSha256: string;
  /** Exercise reference sentence (the text the learner reads); required for a numeric score. */
  referenceText?: string | null;
}

export async function createAssessment(
  deps: AiDeps,
  userId: string,
  input: AssessmentInput,
  idempotencyKey: string,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  const seconds = validateWav(input.wavBase64, input.audioSha256);
  const reference = input.referenceText?.trim() || null;
  const speech = deps.provider.speech;
  let scored: Scored = nullScore(
    'NULL_UNAVAILABLE',
    deps.provider.azureEnabled ? 'NO_REFERENCE_TEXT' : 'AZURE_DISABLED',
  );
  let transcript: string | null = null;
  let provider: string | null = null;
  const existing = await deps.persistence.read('a_jobs', ids.job(userId, input.jobId));
  if (speech && reference && !existing && (await underDailyQuota(deps, userId, seconds))) {
    const result = await speech.recognize(Buffer.from(input.wavBase64, 'base64'), {
      referenceText: reference,
      locale: input.locale,
      seconds,
    });
    transcript = result.transcript || null;
    provider = result.provider;
    scored = result.assessment ?? nullScore('NULL_UNAVAILABLE', 'NO_SCORE');
  }
  const valid = scored.scoreState === 'VALID';
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
        transcript,
        accuracy: valid ? scored.accuracy : null,
        fluency: valid ? scored.fluency : null,
        completeness: valid ? scored.completeness : null,
        prosody: valid ? scored.prosody : null,
        words: valid ? scored.words : [],
        scorer: valid ? AZURE_SCORER : null,
        scoreVersion: valid ? AZURE_SCORE_VERSION : null,
        unavailableReason: valid ? null : scored.reason,
        expiresAt,
        scoreState: scored.scoreState,
        locale: input.locale,
        referenceHash: sha256Hex(
          `${input.referenceExerciseId}|${input.lessonVersion}${reference ? `|${reference}` : ''}`,
        ),
        provider: provider,
        modelVersion: valid ? AZURE_SCORE_VERSION : null,
        miscues: valid
          ? scored.words
              .map((w) => ({ word: w.word, kind: String(w.errorType ?? '').toLowerCase() }))
              .filter((m) => ['omission', 'insertion', 'mispronunciation'].includes(m.kind))
              .slice(0, 100)
          : [],
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

/** Pre-check (outside the transaction) so an over-quota user never reaches the paid/F0 provider. */
async function underDailyQuota(deps: AiDeps, userId: string, seconds: number): Promise<boolean> {
  const utcDay = new Date(deps.nowMs()).toISOString().slice(0, 10);
  const row = await deps.persistence.read('a_usage', ids.usage(userId, utcDay));
  return Number(row?.['recordedSpeechSeconds'] ?? 0) + seconds <= DAILY_RECORDED_SECONDS;
}
