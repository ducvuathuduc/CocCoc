// Voice sessions (FR-SPEECH-002). Native LIVE stays off (NATIVE_LIVE_DISABLED) until its account
// and device gates pass. TURN mode runs on the scripted provider: one active slot per user
// (a_active_slots), receipt-backed creation, advisory heartbeat, idempotent close, and recorded
// turns that are validated (WAV, SHA-256, <= 15 s), counted, never stored, never scored.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { ids } from '../persistence/ids.js';
import type { Row } from '../persistence/port.js';
import { validateWav } from './audio.js';
import { activeConversation, applyTurn, scriptedTranscript } from './conversations.js';
import { iso, stamp, type AiDeps } from './deps.js';
import { countUsage } from './usage.js';

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
  const seconds = validateWav(input.wavBase64, input.audioSha256);
  await ownedSession(deps, userId, sessionId);
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
        transcript = scriptedTranscript(conversation.row);
        const turn = applyTurn(tx, conversation, transcript, now);
        tutor = {
          requestId: input.turnId,
          tutorText: turn.reply,
          correction: null,
          explanation: turn.step.hintVi,
          source: 'authored' as const,
          assessedPronunciation: false as const,
        };
      } else {
        tutor = {
          requestId: input.turnId,
          tutorText: 'I am listening. Start a roleplay to practice a conversation with me.',
          correction: null,
          explanation: 'Hãy bắt đầu một bài hội thoại để luyện nói.',
          source: 'fallback' as const,
          assessedPronunciation: false as const,
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
          score: null,
          mode: 'TURN',
        },
      };
    },
  );
}
