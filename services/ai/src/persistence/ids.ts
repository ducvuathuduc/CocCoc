// Deterministic row IDs (DATA_MODEL: first 32 hex chars of SHA-256(namespace|stableParts)).
// Valid Appwrite row IDs and stable across retries, so a duplicate create collides on the
// primary key instead of producing a second row.
import { createHash } from 'node:crypto';

export function rowId(namespace: string, ...parts: readonly string[]): string {
  return createHash('sha256')
    .update([namespace, ...parts].join('|'))
    .digest('hex')
    .slice(0, 32);
}

export const ids = {
  receipt: (userId: string, operation: string, key: string) =>
    rowId('receipt', userId, operation, key),
  conversation: (userId: string, idempotencyKey: string) =>
    rowId('conversation', userId, idempotencyKey),
  voiceSession: (sessionId: string) => rowId('voice', sessionId),
  slot: (userId: string) => rowId('slot', userId),
  usage: (userId: string, utcDay: string) => rowId('usage', userId, utcDay),
  /** Entitlement projection row (a_usage with the ENTITLEMENT_DAY sentinel, see domain/plans). */
  entitlement: (userId: string) => rowId('entitlement', userId),
  job: (userId: string, jobId: string) => rowId('job', userId, jobId),
  inbox: (eventId: string) => rowId('inbox', eventId),
  outbox: (eventId: string) => rowId('outbox', eventId),
};
