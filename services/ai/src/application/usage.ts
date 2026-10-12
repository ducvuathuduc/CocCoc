// Per-user daily AI usage (a_usage, unique(userId, utcDay)) with bounded daily quotas for the
// scripted provider. Counted inside the caller's transaction, so a replayed receipt never counts twice.
import { ServiceError } from '../../../shared/src/errors.js';
import { ids } from '../persistence/ids.js';
import type { AiTransaction } from '../persistence/port.js';
import { stamp } from './deps.js';

export const DAILY_TEXT_REQUESTS = 100;
export const DAILY_RECORDED_SECONDS = 600;

export async function countUsage(
  tx: AiTransaction,
  userId: string,
  nowMs: number,
  delta: { textRequests?: number; recordedSpeechSeconds?: number },
): Promise<void> {
  const utcDay = new Date(nowMs).toISOString().slice(0, 10);
  const id = ids.usage(userId, utcDay);
  const current = await tx.get('a_usage', id);
  const text = Number(current?.['textRequests'] ?? 0) + (delta.textRequests ?? 0);
  const speech =
    Number(current?.['recordedSpeechSeconds'] ?? 0) + (delta.recordedSpeechSeconds ?? 0);
  if (text > DAILY_TEXT_REQUESTS || speech > DAILY_RECORDED_SECONDS) {
    throw new ServiceError('QUOTA_EXHAUSTED', { details: { utcDay } });
  }
  tx.put(
    'a_usage',
    id,
    stamp(
      current,
      {
        userId,
        utcDay,
        liveReservedSeconds: Number(current?.['liveReservedSeconds'] ?? 0),
        liveUsedSeconds: Number(current?.['liveUsedSeconds'] ?? 0),
        liveGrants: Number(current?.['liveGrants'] ?? 0),
        textRequests: text,
        recordedSpeechSeconds: speech,
        recordedReservedSeconds: Number(current?.['recordedReservedSeconds'] ?? 0),
        reservationIdsJson: String(current?.['reservationIdsJson'] ?? '[]'),
      },
      nowMs,
    ),
  );
}
