// Voice sessions (FR-SPEECH-002). Native LIVE stays off (NATIVE_LIVE_DISABLED) until its account
// and device gates pass. TURN mode runs on the scripted provider: one active slot per user
// (a_active_slots), receipt-backed creation, advisory heartbeat, idempotent close, and recorded
// turns that are validated (WAV, SHA-256, <= 15 s), counted and never stored. With the speech
// provider the turn audio is transcribed for real (Azure, fallbacks AssemblyAI/Deepgram) and, when
// the scenario step has an expected learner line, scored by Azure Pronunciation Assessment against
// it (TurnResult.score); the scripted provider keeps the scripted transcript and a null score.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { ids } from '../persistence/ids.js';
import type { Row } from '../persistence/port.js';
import { validateWav } from './audio.js';
import {
  activeConversation,
  applyTurn,
  expectedLine,
  scriptedTranscript,
} from './conversations.js';
import { iso, stamp, turnSpeechAvailable, type AiDeps } from './deps.js';
import { AZURE_SCORER, type SpeechResult } from './speech.js';
import { countUsage, DAILY_RECORDED_SECONDS } from './usage.js';

export const TURN_SESSION_TTL_MS = 15 * 60 * 1000;
export const SCRIPTED_MODEL = 'scripted-roleplay-v1';

export interface VoiceInput {
  sessionId: string;
  scenarioId: string;
  mode: 'LIVE' | 'TURN';
  level: 'A1' | 'A2';
}

function voiceState(row: Row, nowMs: number) {
  const expired = row['status'] !== 'CLOSED' && Date.parse(String(row['expiresAt'])) <= nowMs;
  return {
    sessionId: String(row['sessionId']),
    status: expired ? 'EXPIRED' : String(row['status']),
    epoch: Number(row['epoch'] ?? 0),
    accountedSeconds: Number(row['consumedSeconds'] ?? 0),
  };
}

export async function createVoiceSession(
  deps: AiDeps,
  userId: string,
  input: VoiceInput,
  idempotencyKey: string,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  if (input.mode === 'LIVE') throw new ServiceError('NATIVE_LIVE_DISABLED');
  if (!turnSpeechAvailable(deps.provider)) throw new ServiceError('AI_PROVIDER_UNAVAILABLE');
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'createVoiceSession', key: idempotencyKey },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const id = ids.voiceSession(input.sessionId);
      if (await tx.get('a_voice_sessions', id)) {
        throw new ServiceError('VOICE_RESERVATION_CONFLICT', { details: { field: 'sessionId' } });
      }
      const slotId = ids.slot(userId);
      const slot = await tx.get('a_active_slots', slotId);
      if (slot && Date.parse(String(slot['expiresAt'])) > now) {
        const holder = await tx.get(
          'a_voice_sessions',
          ids.voiceSession(String(slot['sessionId'])),
        );
        if (holder && holder['status'] === 'ACTIVE') throw new ServiceError('ACTIVE_VOICE_SESSION');
      }
      const expiresAt = iso(now + TURN_SESSION_TTL_MS);
      tx.put(
        'a_voice_sessions',
        id,
        stamp(
          null,
          {
            userId,
            sessionId: input.sessionId,
            providerAlias: deps.provider.kind,
            mode: 'TURN',
            status: 'ACTIVE',
            expiresAt,
            lastHeartbeatAt: iso(now),
            epoch: 0,
            consumedSeconds: 0,
            configVersion: deps.provider.configVersion,
          },
          now,
        ),
      );
      tx.put(
        'a_active_slots',
        slotId,
        stamp(slot, { userId, sessionId: input.sessionId, expiresAt, epoch: 0 }, now),
      );
      return {
        statusCode: 200,
        response: {
          sessionId: input.sessionId,
          mode: 'TURN',
          providerAlias: deps.provider.kind,
          model: SCRIPTED_MODEL,
          ephemeralToken: null,
          connectExpiresAt: null,
          sessionExpiresAt: expiresAt,
          epoch: 0,
          inputSampleRate: 16000,
          outputSampleRate: 24000,
          configVersion: deps.provider.configVersion,
        },
      };
    },
  );
}

async function ownedSession(deps: AiDeps, userId: string, sessionId: string) {
  const row = await deps.persistence.read('a_voice_sessions', ids.voiceSession(sessionId));
  if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
  return row;
}

export async function heartbeatVoiceSession(
  deps: AiDeps,
  userId: string,
  sessionId: string,
  input: { epoch: number; elapsedSeconds: number; turnCount: number },
) {
  await ownedSession(deps, userId, sessionId);
  return deps.persistence.transact(async (tx) => {
    const now = deps.nowMs();
    const id = ids.voiceSession(sessionId);
    const row = await tx.get('a_voice_sessions', id);
    if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
    if (Number(row['epoch']) !== input.epoch) throw new ServiceError('VOICE_EPOCH_CONFLICT');
    if (row['status'] !== 'ACTIVE' || Date.parse(String(row['expiresAt'])) <= now) {
      return voiceState(row, now);
    }
    const next = stamp(
      row,
      {
        ...row,
        lastHeartbeatAt: iso(now),
        consumedSeconds: Math.min(
          180,
          Math.max(Number(row['consumedSeconds'] ?? 0), input.elapsedSeconds),
        ),
      },
      now,
    );
    tx.put('a_voice_sessions', id, next);
    return voiceState(next, now);
  });
}

export async function closeVoiceSession(deps: AiDeps, userId: string, sessionId: string) {
  await ownedSession(deps, userId, sessionId);
  return deps.persistence.transact(async (tx) => {
    const now = deps.nowMs();
    const id = ids.voiceSession(sessionId);
    const row = await tx.get('a_voice_sessions', id);
    if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
    if (row['status'] === 'CLOSED') return voiceState(row, now);
    const next = stamp(row, { ...row, status: 'CLOSED' }, now);
    tx.put('a_voice_sessions', id, next);
    const slot = await tx.get('a_active_slots', ids.slot(userId));
    if (slot && slot['sessionId'] === sessionId) tx.remove('a_active_slots', ids.slot(userId));
    return voiceState(next, now);
  });
}

export interface TurnInput {
  turnId: string;
  epoch: number;
  wavBase64: string;
  audioSha256: string;
}

export async function submitVoiceTurn(
  deps: AiDeps,
  userId: string,
  sessionId: string,
  input: TurnInput,
  idempotencyKey: string,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  if (!turnSpeechAvailable(deps.provider)) throw new ServiceError('AI_PROVIDER_UNAVAILABLE');
  const seconds = validateWav(input.wavBase64, input.audioSha256);
  const session = await ownedSession(deps, userId, sessionId);
  let heard: SpeechResult | null = null;
  let reference: string | null = null;
  const speech = deps.provider.speech;
  if (speech && session['status'] === 'ACTIVE') {
    const receipt = await deps.persistence.read(
      'a_receipts',
      ids.receipt(userId, 'submitVoiceTurn', idempotencyKey),
    );
    const utcDay = new Date(deps.nowMs()).toISOString().slice(0, 10);
    const usage = await deps.persistence.read('a_usage', ids.usage(userId, utcDay));
    const quotaOk =
      Number(usage?.['recordedSpeechSeconds'] ?? 0) + seconds <= DAILY_RECORDED_SECONDS;
    if (!receipt && quotaOk) {
      reference = await peekExpectedLine(deps, userId, sessionId);
      heard = await speech.recognize(Buffer.from(input.wavBase64, 'base64'), {
        referenceText: reference,
        locale: 'en-US',
        seconds,
      });
    }
  }
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'submitVoiceTurn', key: idempotencyKey },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const id = ids.voiceSession(sessionId);
      const row = await tx.get('a_voice_sessions', id);
      if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
      if (row['status'] !== 'ACTIVE' || Date.parse(String(row['expiresAt'])) <= now) {
        throw new ServiceError('VOICE_SESSION_EXPIRED');
      }
      if (Number(row['epoch']) !== input.epoch) throw new ServiceError('VOICE_EPOCH_CONFLICT');
      await countUsage(tx, userId, now, { recordedSpeechSeconds: seconds });
      tx.put(
        'a_voice_sessions',
        id,
        stamp(
          row,
          {
            ...row,
            lastHeartbeatAt: iso(now),
            consumedSeconds: Math.min(180, Number(row['consumedSeconds'] ?? 0) + seconds),
          },
          now,
        ),
      );
      const conversation = await activeConversation(deps, tx, userId, {
        voiceSessionId: sessionId,
      });
      let transcript = '';
      let tutor;
      if (conversation) {
        transcript = heard ? heard.transcript : scriptedTranscript(conversation.row);
        const turn = applyTurn(tx, conversation, transcript, now);
        tutor = {
          requestId: input.turnId,
          tutorText: turn.reply,
          correction: null,
          explanation: turn.step.hintVi,
          source: 'authored' as const,
          assessedPronunciation: heard?.assessment?.scoreState === 'VALID',
        };
      } else {
        if (heard) transcript = heard.transcript;
        tutor = {
          requestId: input.turnId,
          tutorText: 'I am listening. Start a roleplay to practice a conversation with me.',
          correction: null,
          explanation: 'Hãy bắt đầu một bài hội thoại để luyện nói.',
          source: 'fallback' as const,
          assessedPronunciation: false,
        };
      }
      return {
        statusCode: 200,
        response: {
          turnId: input.turnId,
          epoch: input.epoch,
          transcript,
          tutor,
          audioAssetId: null,
          score: turnScore(heard, reference),
          mode: 'TURN',
        },
      };
    },
  );
}

/** The expected learner line of the session's active conversation step (read outside the tx). */
async function peekExpectedLine(deps: AiDeps, userId: string, sessionId: string) {
  const page = await deps.persistence.list('a_conversations', {
    equal: { userId, status: 'ACTIVE', voiceSessionId: sessionId },
    orderDesc: 'startedAt',
    limit: 1,
  });
  const first = page.items[0];
  return first ? expectedLine(first.row) : null;
}

/** OpenAPI TurnScore: Azure metrics only when VALID; null when no speech/score was attempted. */
function turnScore(heard: SpeechResult | null, reference: string | null) {
  if (!heard || !reference || !heard.assessment) return null;
  const a = heard.assessment;
  const valid = a.scoreState === 'VALID';
  return {
    scoreState: a.scoreState,
    referenceText: reference.slice(0, 300),
    accuracy: valid ? a.accuracy : null,
    fluency: valid ? a.fluency : null,
    completeness: valid ? a.completeness : null,
    prosody: valid ? a.prosody : null,
    words: valid ? a.words : [],
    scorer: valid ? AZURE_SCORER : null,
    transcriptProvider: heard.provider,
    unavailableReason: valid ? null : a.reason,
  };
}
