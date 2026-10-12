import { createHash } from 'node:crypto';
import type { components } from '../../../../packages/api_contracts/generated.js';
import { firstCompletionXp } from '../domain/lesson-xp.js';
type CompletionEvent = Extract<
  components['schemas']['BusinessEvent'],
  { type: 'lesson.completed.v1' }
>;

// LOCAL TEST FIXTURE ONLY (never bundled into a hosted artifact). XP rule: domain/lesson-xp.ts.
// Fixture receiver; event authentication/schema validation precede this port in production.
export class MockRewardStore {
  private readonly inbox = new Map<string, string>();
  private readonly ledger = new Map<string, { userId: string; xp: number }>();
  failNextCommit = false;
  async consume(event: CompletionEvent): Promise<void> {
    if (event.type !== 'lesson.completed.v1' || event.producer !== 'learning')
      throw new Error('EVENT_NOT_ALLOWED');
    const bodyHash = createHash('sha256').update(JSON.stringify(event)).digest('hex');
    const previous = this.inbox.get(event.eventId);
    if (previous) {
      if (previous !== bodyHash) throw new Error('EVENT_PAYLOAD_CONFLICT');
      return;
    }
    const result = firstCompletionXp(event.payload);
    if (!result.ok) throw new Error(result.reason);
    if (this.failNextCommit) {
      this.failNextCommit = false;
      throw new Error('TRANSACTION_FAILED');
    }
    const payload = event.payload;
    const ledgerKey = JSON.stringify([payload.userId, payload.completionId]);
    if (!this.ledger.has(ledgerKey)) {
      this.ledger.set(ledgerKey, { userId: payload.userId, xp: result.studyXp });
    }
    this.inbox.set(event.eventId, bodyHash);
  }
  xp(userId: string): number {
    return [...this.ledger.values()]
      .filter((entry) => entry.userId === userId)
      .reduce((total, entry) => total + entry.xp, 0);
  }
  get appliedEvents(): number {
    return this.inbox.size;
  }
}
