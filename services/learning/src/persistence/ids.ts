// Deterministic row IDs (DATA_MODEL: first 32 hex chars of SHA-256(namespace|stableParts)).
// Valid Appwrite row IDs (<=36 chars, [a-z0-9]) and stable across retries, so a duplicate create
// collides on the primary key instead of producing a second row.
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
  course: (courseId: string) => rowId('course', courseId),
  contentVersion: (courseId: string, versionId: string) =>
    rowId('content-version', courseId, versionId),
  enrollment: (userId: string, courseId: string) => rowId('enrollment', userId, courseId),
  slot: (userId: string, courseId: string) => rowId('slot', userId, courseId),
  session: (userId: string, key: string) => rowId('session', userId, key),
  answer: (sessionId: string, exerciseId: string, ordinal: number) =>
    rowId('answer', sessionId, exerciseId, String(ordinal)),
  review: (userId: string, courseId: string, vocabularyId: string) =>
    rowId('review', userId, courseId, vocabularyId),
  report: (userId: string, key: string) => rowId('report', userId, key),
  outbox: (eventId: string) => rowId('outbox', eventId),
  energy: (userId: string) => rowId('energy', userId),
};
