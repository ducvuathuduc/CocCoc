import { randomUUID } from 'node:crypto';
import type { components } from '../../../packages/api_contracts/generated.js';

type CompletionEvent = Extract<
  components['schemas']['BusinessEvent'],
  { type: 'lesson.completed.v1' }
>;
interface FixtureSession {
  id: string;
  userId: string;
  revision: number;
  attempted: number;
  required: number;
  originalCorrect: number;
  assisted: boolean;
  completed: boolean;
}
interface Command {
  userId: string;
  sessionId: string;
  key: string;
  expectedRevision: number;
}
interface MockReceipt {
  completionId: string;
  rewardState: 'PENDING';
  eventId: string;
}

// Local acceptance fixture only. No cloud entrypoint imports this module.
export class MockCompletionStore {
  failNextCommit = false;
  private readonly sessions = new Map<string, FixtureSession>();
  private readonly receipts = new Map<string, { hash: string; receipt: MockReceipt }>();
  private readonly completions = new Map<string, MockReceipt>();
  private readonly outbox = new Map<string, CompletionEvent>();
  constructor(sessions: FixtureSession[]) {
    for (const session of sessions) this.sessions.set(session.id, { ...session });
  }
  async complete(command: Command): Promise<MockReceipt> {
    const session = this.sessions.get(command.sessionId);
    if (!session || session.userId !== command.userId) throw new Error('FORBIDDEN');
    const key = JSON.stringify([command.userId, 'completeSession', command.key]);
    const hash = JSON.stringify([command.sessionId, command.expectedRevision]);
    const previous = this.receipts.get(key);
    if (previous) {
      if (previous.hash !== hash) throw new Error('IDEMPOTENCY_CONFLICT');
      return { ...previous.receipt };
    }
    const completed = this.completions.get(command.sessionId);
    if (completed) {
      this.receipts.set(key, { hash, receipt: completed });
      return { ...completed };
    }
    if (session.revision !== command.expectedRevision) throw new Error('REVISION_CONFLICT');
    if (session.attempted !== session.required) throw new Error('INCOMPLETE_SESSION');
    if (this.failNextCommit) {
      this.failNextCommit = false;
      throw new Error('TRANSACTION_FAILED');
    }
    const completionId = randomUUID();
    const eventId = randomUUID();
    const receipt: MockReceipt = { completionId, eventId, rewardState: 'PENDING' };
    const event: CompletionEvent = {
      eventId,
      type: 'lesson.completed.v1',
      schemaVersion: 1,
      producer: 'learning',
      aggregateId: completionId,
      occurredAt: new Date().toISOString(),
      requestId: randomUUID(),
      payload: {
        completionId,
        userId: session.userId,
        courseId: 'vi_en',
        lessonVersion: 'fixture-v1',
        rewardIdentity: 'fixture-lesson',
        source: 'ONLINE',
        mode: 'LESSON',
        originalCount: session.required,
        originalCorrect: session.originalCorrect,
        assisted: session.assisted,
      },
    };
    // A synchronous commit section simulates atomicity in a single JS process.
    // Durable TablesDB transactions and crash recovery remain an integration gate.
    this.sessions.set(session.id, { ...session, completed: true, revision: session.revision + 1 });
    this.completions.set(session.id, receipt);
    this.receipts.set(key, { hash, receipt });
    this.outbox.set(eventId, event);
    return { ...receipt };
  }
  pendingEvents(): CompletionEvent[] {
    return structuredClone([...this.outbox.values()]);
  }
  acknowledge(eventId: string): void {
    this.outbox.delete(eventId);
  }
  session(id: string): FixtureSession | undefined {
    const value = this.sessions.get(id);
    return value ? { ...value } : undefined;
  }
}
