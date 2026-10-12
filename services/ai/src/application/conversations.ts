// P8-AI-003 Roleplay / Video Call conversations over the scripted provider (FR-AI-001).
// start: entitlement-gated (projected plan from entitlement.changed.v1), receipt-backed.
// turns: learner text (POST /v1/tutor with scenarioId) or a scripted TURN speech turn advance the
//   active conversation's script; progress lives on the a_conversations row (draft feedbackJson).
// complete: once; server-computed stars/words/XP/feedback and ai.practice.completed.v1 staged in
//   a_outbox in the same transaction (DATA_MODEL a_conversations).
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { effectivePlan, planAllows, type ConversationKind } from '../domain/plans.js';
import {
  onTopic,
  scenarioById,
  usedTargetWords,
  type Scenario,
  type ScenarioStep,
} from '../domain/scenarios.js';
import { scoreConversation } from '../domain/scoring.js';
import { ids } from '../persistence/ids.js';
import type { AiTransaction, Row } from '../persistence/port.js';
import { iso, stamp, uuidFrom, type AiDeps } from './deps.js';
import { readProjection } from './events.js';
import { stageOutboxEvent, type AiEvent } from './outbox.js';

/** An ACTIVE conversation not completed within this window reads as EXPIRED. */
export const ACTIVE_TTL_MS = 30 * 60 * 1000;
/** Completed conversation metadata is kept one year (DATA_MODEL). */
export const HISTORY_TTL_MS = 365 * 24 * 60 * 60 * 1000;
export const MAX_TURNS = 60;

interface Draft {
  stepIndex: number;
  onTopicTurns: number;
  usedWords: string[];
}

function draftOf(row: Row): Draft {
  try {
    const value = JSON.parse(String(row['feedbackJson'] ?? '')) as Partial<Draft> & {
      draft?: boolean;
    };
    if (value && value.draft) {
      return {
        stepIndex: Number(value.stepIndex ?? 0),
        onTopicTurns: Number(value.onTopicTurns ?? 0),
        usedWords: Array.isArray(value.usedWords) ? value.usedWords.map(String) : [],
      };
    }
  } catch {
    // fall through
  }
  return { stepIndex: 0, onTopicTurns: 0, usedWords: [] };
}

function isExpired(row: Row, nowMs: number): boolean {
  return row['status'] === 'ACTIVE' && Date.parse(String(row['expiresAt'])) <= nowMs;
}

export function toConversation(row: Row, nowMs: number) {
  const status = isExpired(row, nowMs) ? 'EXPIRED' : String(row['status']);
  let feedback: unknown = null;
  if (status === 'COMPLETED' && row['feedbackJson']) {
    try {
      feedback = JSON.parse(String(row['feedbackJson']));
    } catch {
      feedback = null;
    }
  }
  return {
    conversationId: String(row['conversationId']),
    kind: String(row['kind']),
    courseId: String(row['courseId']),
    scenarioId: String(row['scenarioId']),
    voiceSessionId: (row['voiceSessionId'] as string | null) ?? null,
    status,
    startedAt: String(row['startedAt']),
    completedAt: (row['completedAt'] as string | null) ?? null,
    turnCount: Number(row['turnCount'] ?? 0),
    wordsUsed: Number(row['wordsUsed'] ?? 0),
    stars: Number(row['stars'] ?? 0),
    xpAwarded: Number(row['xpAwarded'] ?? 0),
    feedback,
    expiresAt: String(row['expiresAt']),
  };
}

export interface StartInput {
  kind: ConversationKind;
  courseId: string;
  scenarioId: string;
  voiceSessionId: string | null;
}

export async function startConversation(
  deps: AiDeps,
  userId: string,
  input: StartInput,
  idempotencyKey: string,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  if (!scenarioById(input.scenarioId)) {
    throw new ServiceError('NOT_FOUND', { details: { field: 'scenarioId' } });
  }
  const plan = effectivePlan(await readProjection(deps, userId), deps.nowMs());
  if (!planAllows(plan, deps.gates[input.kind])) {
    throw new ServiceError('ENTITLEMENT_REQUIRED', {
      details: { feature: input.kind, required: deps.gates[input.kind] },
    });
  }
  const previous = await deps.persistence.list('a_conversations', {
    equal: { userId, scenarioId: input.scenarioId, status: 'ACTIVE' },
    limit: 20,
  });
  const conversationId = ids.conversation(userId, idempotencyKey);
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'startConversation', key: idempotencyKey },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      if (input.voiceSessionId) {
        const voice = await tx.get('a_voice_sessions', ids.voiceSession(input.voiceSessionId));
        if (!voice || voice['userId'] !== userId || voice['mode'] !== 'TURN') {
          throw new ServiceError('NOT_FOUND', { details: { field: 'voiceSessionId' } });
        }
        if (voice['status'] !== 'ACTIVE' || Date.parse(String(voice['expiresAt'])) <= now) {
          throw new ServiceError('VOICE_SESSION_EXPIRED');
        }
      }
      // One active run per scenario: an older ACTIVE run of the same scenario is abandoned.
      for (const item of previous.items) {
        if (item.id === conversationId) continue;
        const old = await tx.get('a_conversations', item.id);
        if (old && old['status'] === 'ACTIVE') {
          tx.put('a_conversations', item.id, stamp(old, { ...old, status: 'ABANDONED' }, now));
        }
      }
      const row = stamp(
        null,
        {
          conversationId,
          userId,
          kind: input.kind,
          courseId: input.courseId,
          scenarioId: input.scenarioId,
          voiceSessionId: input.voiceSessionId,
          status: 'ACTIVE',
          startedAt: iso(now),
          completedAt: null,
          turnCount: 0,
          wordsUsed: 0,
          stars: 0,
          xpAwarded: 0,
          feedbackJson: JSON.stringify({
            draft: true,
            stepIndex: 0,
            onTopicTurns: 0,
            usedWords: [],
          }),
          transcriptFileId: null,
          expiresAt: iso(now + ACTIVE_TTL_MS),
        },
        now,
      );
      tx.put('a_conversations', conversationId, row);
      return { statusCode: 200, response: toConversation(row, now) };
    },
  );
}

export interface ListInput {
  kind?: ConversationKind;
  scenarioId?: string;
  cursor?: string;
  limit: number;
}

export async function listConversations(deps: AiDeps, userId: string, input: ListInput) {
  let offset = 0;
  if (input.cursor) {
    const match = /^o([0-9]{1,6})$/.exec(input.cursor);
    if (!match) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
    offset = Number(match[1]);
  }
  const equal: Record<string, string> = { userId };
  if (input.kind) equal['kind'] = input.kind;
  if (input.scenarioId) equal['scenarioId'] = input.scenarioId;
  const page = await deps.persistence.list('a_conversations', {
    equal,
    orderDesc: 'startedAt',
    limit: input.limit + 1,
    offset,
  });
  const now = deps.nowMs();
  const items = page.items.slice(0, input.limit).map((item) => toConversation(item.row, now));
  return {
    items,
    nextCursor: page.items.length > input.limit ? `o${offset + input.limit}` : null,
    asOf: iso(now),
  };
}

/** Find the user's newest ACTIVE conversation for a scenario or a voice session (read in tx). */
export async function activeConversation(
  deps: AiDeps,
  tx: AiTransaction,
  userId: string,
  by: { scenarioId: string } | { voiceSessionId: string },
): Promise<{ id: string; row: Row } | null> {
  const page = await deps.persistence.list('a_conversations', {
    equal: { userId, status: 'ACTIVE', ...by },
    orderDesc: 'startedAt',
    limit: 1,
  });
  const first = page.items[0];
  if (!first) return null;
  const row = await tx.get('a_conversations', first.id);
  if (!row || row['status'] !== 'ACTIVE' || isExpired(row, deps.nowMs())) return null;
  return { id: first.id, row };
}

export interface TurnOutcome {
  scenario: Scenario;
  step: ScenarioStep;
  onTopic: boolean;
  /** Next partner line (or the closing line when the script is finished). */
  reply: string;
  finished: boolean;
}

/** Advance the script with one learner turn and stage the updated conversation row. */
export function applyTurn(
  tx: AiTransaction,
  conversation: { id: string; row: Row },
  learnerText: string,
  nowMs: number,
): TurnOutcome {
  const scenario = scenarioById(String(conversation.row['scenarioId']));
  if (!scenario) throw new ServiceError('NOT_FOUND', { details: { field: 'scenarioId' } });
  const turnCount = Number(conversation.row['turnCount'] ?? 0);
  if (turnCount >= MAX_TURNS)
    throw new ServiceError('SESSION_CONFLICT', { details: { reason: 'MAX_TURNS' } });
  const draft = draftOf(conversation.row);
  const finishedBefore = draft.stepIndex >= scenario.steps.length;
  const step = scenario.steps[Math.min(draft.stepIndex, scenario.steps.length - 1)] as ScenarioStep;
  const hit = !finishedBefore && onTopic(step, learnerText);
  const used = [...new Set([...draft.usedWords, ...usedTargetWords(scenario, learnerText)])];
  const next: Draft = {
    stepIndex: hit ? draft.stepIndex + 1 : draft.stepIndex,
    onTopicTurns: draft.onTopicTurns + (hit ? 1 : 0),
    usedWords: used,
  };
  const finished = next.stepIndex >= scenario.steps.length;
  tx.put(
    'a_conversations',
    conversation.id,
    stamp(
      conversation.row,
      {
        ...conversation.row,
        turnCount: turnCount + 1,
        wordsUsed: used.length,
        feedbackJson: JSON.stringify({ draft: true, ...next }),
      },
      nowMs,
    ),
  );
  const reply = finished
    ? scenario.closing
    : hit
      ? (scenario.steps[next.stepIndex] as ScenarioStep).partner
      : `Let's try again. ${step.partner}`;
  return { scenario, step, onTopic: hit, reply, finished };
}

/** The scripted "speech recognizer": the model answer for the conversation's current step. */
export function scriptedTranscript(row: Row): string {
  const scenario = scenarioById(String(row['scenarioId']));
  if (!scenario) return '';
  const draft = draftOf(row);
  if (draft.stepIndex >= scenario.steps.length) return 'Thank you. Goodbye!';
  return (scenario.steps[draft.stepIndex] as ScenarioStep).expect;
}

export async function completeConversation(
  deps: AiDeps,
  userId: string,
  conversationId: string,
  endReason: 'COMPLETED' | 'USER_EXIT',
  idempotencyKey: string,
  bodyHash: string,
): Promise<{ outcome: ReceiptOutcome; eventIds: string[] }> {
  const eventIds: string[] = [];
  const outcome = await deps.persistence.commitWithReceipt(
    { userId, operation: 'completeConversation', key: idempotencyKey },
    bodyHash,
    async (tx) => {
      eventIds.length = 0;
      const now = deps.nowMs();
      const row = await tx.get('a_conversations', conversationId);
      if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
      // Complete once: a finished conversation answers its stored result, no second event.
      if (row['status'] !== 'ACTIVE')
        return { statusCode: 200, response: toConversation(row, now) };
      const scenario = scenarioById(String(row['scenarioId']));
      if (!scenario) throw new ServiceError('NOT_FOUND', { details: { field: 'scenarioId' } });
      const releaseVoice = async () => {
        const voiceId = row['voiceSessionId'];
        if (typeof voiceId !== 'string') return;
        const voice = await tx.get('a_voice_sessions', ids.voiceSession(voiceId));
        if (voice && voice['status'] !== 'CLOSED' && voice['userId'] === userId) {
          tx.put(
            'a_voice_sessions',
            ids.voiceSession(voiceId),
            stamp(voice, { ...voice, status: 'CLOSED' }, now),
          );
          const slot = await tx.get('a_active_slots', ids.slot(userId));
          if (slot && slot['sessionId'] === voiceId) tx.remove('a_active_slots', ids.slot(userId));
        }
      };
      if (isExpired(row, now) || endReason === 'USER_EXIT') {
        const finished = stamp(
          row,
          {
            ...row,
            status: isExpired(row, now) ? 'EXPIRED' : 'ABANDONED',
            completedAt: iso(now),
            feedbackJson: null,
            expiresAt: iso(now + HISTORY_TTL_MS),
          },
          now,
        );
        tx.put('a_conversations', conversationId, finished);
        await releaseVoice();
        return { statusCode: 200, response: toConversation(finished, now) };
      }
      const draft = draftOf(row);
      if (draft.stepIndex < scenario.steps.length) {
        throw new ServiceError('SESSION_INCOMPLETE', {
          details: { completedSteps: draft.stepIndex, requiredSteps: scenario.steps.length },
        });
      }
      const result = scoreConversation(scenario, {
        turnCount: Number(row['turnCount'] ?? 0),
        onTopicTurns: draft.onTopicTurns,
        usedWords: draft.usedWords,
      });
      const completed = stamp(
        row,
        {
          ...row,
          status: 'COMPLETED',
          completedAt: iso(now),
          wordsUsed: result.wordsUsed,
          stars: result.stars,
          xpAwarded: result.xp,
          feedbackJson: JSON.stringify(result.feedback),
          expiresAt: iso(now + HISTORY_TTL_MS),
        },
        now,
      );
      tx.put('a_conversations', conversationId, completed);
      await releaseVoice();
      const event: AiEvent = {
        eventId: uuidFrom(`ai.practice.completed.v1|${conversationId}`),
        type: 'ai.practice.completed.v1',
        schemaVersion: 1,
        producer: 'ai',
        aggregateId: userId,
        occurredAt: iso(now),
        requestId: uuidFrom(`ai.practice.completed.v1|${conversationId}`),
        payload: {
          completionId: conversationId,
          userId,
          kind: String(row['kind']),
          courseId: String(row['courseId']),
          scenarioId: String(row['scenarioId']),
          xp: result.xp,
          wordsUsed: result.wordsUsed,
          stars: result.stars,
        },
      };
      stageOutboxEvent(tx, event, now);
      eventIds.push(event.eventId);
      return { statusCode: 200, response: toConversation(completed, now) };
    },
  );
  return { outcome, eventIds: outcome.status === 'created' ? eventIds : [] };
}
