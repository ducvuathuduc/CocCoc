// FR-AUTH-005 purge side: owners acknowledge with account.purged.v1; once Learning and AI both
// acknowledged, Progress purges its private rows in bounded transactions and marks the
// tombstone COMPLETED. The p_deletions row itself stays so the account cannot re-initialize.
import type { ProgressPersistence, ProgressTable, ProgressTx } from '../persistence/port.js';
import { editable, ids } from './records.js';

export const PURGE_OWNERS = ['learning', 'ai'] as const;
const BATCH = 80;

/** Tables holding a user's private rows, keyed by the column naming the user. */
export const PURGE_PLAN: ReadonlyArray<readonly [ProgressTable, string]> = [
  ['p_profiles', 'userId'],
  ['p_zone_history', 'userId'],
  ['p_rewards', 'userId'],
  ['p_reward_ledger', 'userId'],
  ['p_first_rewards', 'userId'],
  ['p_day_activity', 'userId'],
  ['p_freeze_ledger', 'userId'],
  ['p_quests', 'userId'],
  ['p_follows', 'fromUserId'],
  ['p_follows', 'toUserId'],
  ['p_blocks', 'blockerId'],
  ['p_blocks', 'blockedId'],
  ['p_league_members', 'userId'],
  ['p_league_profiles', 'userId'],
  ['p_activity', 'userId'],
  ['p_achievements', 'userId'],
  ['p_notifications', 'userId'],
  ['p_receipts', 'userId'],
  ['p_preferences', 'userId'],
  ['p_inventory', 'userId'],
  ['p_item_ledger', 'userId'],
  ['p_boosts', 'userId'],
  ['p_entitlements', 'userId'],
  ['p_ad_events', 'userId'],
  ['p_promo_redemptions', 'userId'],
  ['p_year_reviews', 'userId'],
  ['p_feedback', 'userId'],
  ['p_classroom_members', 'userId'],
];

export async function recordPurgeAck(
  tx: ProgressTx,
  payload: { userId: string; requestId: string; owner: string },
): Promise<void> {
  const id = ids.deletion(payload.userId);
  const deletion = await tx.get('p_deletions', id);
  if (!deletion || deletion['requestId'] !== payload.requestId) return; // stale/unknown request
  const acks = new Set<string>(JSON.parse(String(deletion['ownerAcksJson'] ?? '[]')) as string[]);
  acks.add(payload.owner);
  const all = PURGE_OWNERS.every((owner) => acks.has(owner));
  const status =
    deletion['status'] === 'COMPLETED' ? 'COMPLETED' : all ? 'PURGING' : deletion['status'];
  tx.put('p_deletions', id, {
    ...editable(deletion),
    ownerAcksJson: JSON.stringify([...acks].sort()),
    status,
  });
}

/** Purge step: deletes up to BATCH rows per transaction; returns true once COMPLETED. */
export async function purgeDeletedAccount(
  store: ProgressPersistence,
  userId: string,
  maxBatches = 50,
): Promise<boolean> {
  for (let batch = 0; batch < maxBatches; batch++) {
    const done = await store.transact(async (tx) => {
      const deletion = await tx.get('p_deletions', ids.deletion(userId));
      if (!deletion || deletion['status'] === 'COMPLETED') return true;
      if (deletion['status'] !== 'PURGING') return true;
      let budget = BATCH;
      for (const [table, column] of PURGE_PLAN) {
        if (budget <= 0) return false;
        const rows = await tx.list(table, { where: { [column]: userId }, limit: budget });
        for (const { id } of rows) tx.delete(table, id);
        budget -= rows.length;
      }
      if (budget <= 0) return false;
      tx.put('p_deletions', ids.deletion(userId), {
        ...editable(deletion),
        status: 'COMPLETED',
        completedAt: tx.nowIso,
      });
      return true;
    });
    if (done) {
      const final = await store.read('p_deletions', ids.deletion(userId));
      return final?.['status'] === 'COMPLETED';
    }
  }
  return false;
}
