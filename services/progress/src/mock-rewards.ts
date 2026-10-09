import { createHash } from 'node:crypto';
import type { components } from '../../../packages/api_contracts/generated.js';
type CompletionEvent = Extract<
  components['schemas']['BusinessEvent'],
  { type: 'lesson.completed.v1' }
>;

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
    const payload = event.payload;
    if (payload.mode !== 'LESSON' && payload.mode !== 'PLACEMENT')
      throw new Error('MODE_NOT_IMPLEMENTED');
    if (
      payload.originalCount !== 10 ||
      payload.originalCorrect < 0 ||
      payload.originalCorrect > payload.originalCount
    )
      throw new Error('INVALID_GRADED_RESULT');
    if (this.failNextCommit) {
      this.failNextCommit = false;
      throw new Error('TRANSACTION_FAILED');
    }
    const ledgerKey = JSON.stringify([payload.userId, payload.completionId]);
    if (!this.ledger.has(ledgerKey)) {
      const perfect =
        payload.source === 'ONLINE' && payload.originalCorrect === 10 && !payload.assisted;
      const xp =
        payload.mode === 'PLACEMENT' ? 0 : 10 + payload.originalCorrect + (perfect ? 5 : 0);
      this.ledger.set(ledgerKey, { userId: payload.userId, xp });
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
