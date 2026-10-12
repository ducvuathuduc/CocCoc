// Dependencies shared by the AI use cases (composition roots: src/index.ts, src/dev.ts, testkit).
import { createHash } from 'node:crypto';
import type { FeatureGates } from '../domain/plans.js';
import type { AiPersistence, Row } from '../persistence/port.js';
import type { Deliver } from './outbox.js';

/**
 * Provider configuration. Only the deterministic scripted provider exists in this build:
 * COC_AI_PROVIDER=disabled (and any other value) serves authored roleplay scripts, a scripted
 * TURN transcript and a null-score assessment. No model, STT or scorer is called.
 */
export interface ProviderConfig {
  kind: 'scripted';
  configVersion: string;
  /** Azure pronunciation scorer; always false here, so assessment metrics stay null. */
  azureEnabled: false;
}
export const SCRIPTED_PROVIDER: ProviderConfig = {
  kind: 'scripted',
  configVersion: 'scripted-v1',
  azureEnabled: false,
};

export interface EventRelay {
  afterCommit(eventIds: readonly string[]): Promise<void>;
}

export interface AiDeps {
  persistence: AiPersistence;
  nowMs: () => number;
  newId: () => string;
  gates: FeatureGates;
  provider: ProviderConfig;
  /** Signed delivery to Progress /internal/events (absent: rows wait in a_outbox). */
  deliver?: Deliver;
  relay?: EventRelay;
}

export const iso = (ms: number) => new Date(ms).toISOString();

/** Deterministic RFC 4122-shaped UUID (version 5 layout) from a seed: stable across retries. */
export function uuidFrom(seed: string): string {
  const h = createHash('sha256').update(seed).digest('hex');
  const variant = ((parseInt(h[16] ?? '0', 16) & 3) | 8).toString(16);
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-${variant}${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

export const sha256Hex = (value: string | Buffer) =>
  createHash('sha256').update(value).digest('hex');

/** Stamp a mutable row: revision+1 and updatedAt on update, revision 0 and createdAt on create. */
export function stamp(
  previous: Row | null,
  data: Record<string, unknown>,
  nowMs: number,
): Record<string, unknown> {
  const now = iso(nowMs);
  return {
    ...data,
    revision: previous ? Number(previous['revision'] ?? 0) + 1 : 0,
    createdAt: previous ? String(previous['createdAt'] ?? now) : now,
    updatedAt: now,
  };
}
