// Composition contract for Learning use cases, plus small row helpers shared by them.
import type { ContentRepository } from '../content/repository.js';
import type { LearningPersistence, Row } from '../persistence/port.js';
import type { Deliver } from './outbox.js';

export interface EventRelay {
  /** Best-effort immediate delivery of committed outbox rows; the dispatcher is the backstop. */
  afterCommit(eventIds: readonly string[]): Promise<void>;
}

export interface LearningDeps {
  persistence: LearningPersistence;
  content: ContentRepository;
  nowMs: () => number;
  newId: () => string;
  /** Appwrite user IDs allowed to publish content (FR-ADMIN-001); empty -> nobody. */
  maintainers: ReadonlySet<string>;
  relay?: EventRelay | undefined;
  /** Course energyMode configuration (FR-GAME-005); absent means UNLIMITED. */
  energyMode?: 'LIMITED' | 'UNLIMITED' | undefined;
  /** Signed delivery used by the scheduled outbox dispatch tick; absent fails closed. */
  deliver?: Deliver | undefined;
}

export const SESSION_TTL_MS = 24 * 60 * 60 * 1000;

export function iso(ms: number): string {
  return new Date(ms).toISOString();
}

/** New mutable row fields (DATA_MODEL: revision, createdAt, updatedAt on every mutable row). */
export function created(nowMs: number): { revision: number; createdAt: string; updatedAt: string } {
  const at = iso(nowMs);
  return { revision: 0, createdAt: at, updatedAt: at };
}
export function bumped(previous: Row, nowMs: number): { revision: number; updatedAt: string } {
  return { revision: Number(previous['revision'] ?? 0) + 1, updatedAt: iso(nowMs) };
}

export function jsonArray(value: unknown): string[] {
  if (typeof value !== 'string' || !value) return [];
  const parsed: unknown = JSON.parse(value);
  return Array.isArray(parsed) ? parsed.map(String) : [];
}
export function jsonObject<T = Record<string, unknown>>(value: unknown): T | null {
  if (typeof value !== 'string' || !value) return null;
  const parsed: unknown = JSON.parse(value);
  return parsed && typeof parsed === 'object' ? (parsed as T) : null;
}

/** Opaque offset cursor for list endpoints. */
export function encodeCursor(offset: number): string {
  return Buffer.from(`o:${offset}`).toString('base64url');
}
export function decodeCursor(cursor: string | undefined): number {
  if (!cursor) return 0;
  const match = /^o:(\d{1,6})$/.exec(Buffer.from(cursor, 'base64url').toString('utf8'));
  if (!match) return -1;
  return Number(match[1]);
}
