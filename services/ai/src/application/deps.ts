// Dependencies shared by the AI use cases (composition roots: src/index.ts, src/dev.ts, testkit).
import { createHash } from 'node:crypto';
import type { FeatureGates } from '../domain/plans.js';
import type { AiPersistence, Row } from '../persistence/port.js';
import type { Deliver } from './outbox.js';
import type { SpeechEngine } from './speech.js';

/**
 * Provider configuration. The conversation script is always the deterministic authored one.
 * Speech: with COC_AI_PROVIDER=speech and provider keys (secret function variables), recorded
 * audio is transcribed for real (Azure, fallbacks AssemblyAI/Deepgram) and scored by Azure
 * Pronunciation Assessment. Hosted defaults to disabled recorded speech; explicit dev/test
 * scripted TURN fixtures keep every assessment metric null.
 */
export interface ProviderConfig {
  kind: 'disabled' | 'scripted' | 'speech';
  configVersion: string;
  /** Azure pronunciation scorer configured; false keeps assessment metrics null. */
  azureEnabled: boolean;
  speech?: SpeechEngine | null;
}
export const SCRIPTED_PROVIDER: ProviderConfig = {
  kind: 'scripted',
  configVersion: 'scripted-v1',
  azureEnabled: false,
};
/** Hosted default: no synthetic transcript may stand in for actual microphone audio. */
export const DISABLED_PROVIDER: ProviderConfig = {
  kind: 'disabled',
  configVersion: 'disabled-v1',
  azureEnabled: false,
};

export function turnSpeechAvailable(provider: ProviderConfig): boolean {
  return provider.kind === 'scripted' || (provider.kind === 'speech' && Boolean(provider.speech));
}
export function speechProvider(speech: SpeechEngine): ProviderConfig {
  return {
    kind: 'speech',
    configVersion: speech.azure ? 'speech-azure-v1' : 'speech-stt-v1',
    azureEnabled: speech.azure,
    speech,
  };
}

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
