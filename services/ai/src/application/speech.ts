// Real speech providers (FR-SPEECH-002/003), server-side only. Keys come from secret function
// variables and are never logged or returned.
//   Azure Speech  — primary: short-audio REST recognition with Pronunciation Assessment
//                   (accuracy/fluency/completeness/prosody, per-word and per-phoneme scores).
//   AssemblyAI    — fallback transcription (async upload + transcript, bounded poll).
//   Deepgram      — second fallback transcription (synchronous prerecorded).
// Numerical pronunciation comes only from Azure (the dedicated scorer); fallbacks give transcripts.
// Quota: every Azure call reserves its audio seconds on a project-wide daily row (a_usage,
// userId SPEECH_GLOBAL_USER) so the F0 allowance is never overrun; a warm-instance LRU cache
// answers identical (audio, reference) pairs without a second provider call.
import { ids } from '../persistence/ids.js';
import type { AiPersistence } from '../persistence/port.js';
import { sha256Hex, stamp } from './deps.js';

export const SPEECH_GLOBAL_USER = 'system-speech-azure';
export const DEFAULT_AZURE_DAILY_SECONDS = 540;
export const AZURE_SCORER = 'azure-pronunciation-assessment';
export const AZURE_SCORE_VERSION = 'azure-rest-v1-hundredmark';
const MAX_WORDS = 100;
const MAX_PHONEMES = 100;

export type Fetch = (url: string, init?: RequestInit) => Promise<Response>;

export interface WordScore {
  word: string;
  accuracy: number | null;
  errorType: string | null;
  phonemes: { phoneme: string; accuracy: number | null }[];
}

export interface Scored {
  scoreState: 'VALID' | 'NULL_LOW_CONFIDENCE' | 'NULL_UNAVAILABLE' | 'FAILED';
  accuracy: number | null;
  fluency: number | null;
  completeness: number | null;
  prosody: number | null;
  words: WordScore[];
  reason: string | null;
}

export interface SpeechResult {
  /** Final transcript ('' when nothing was recognized). */
  transcript: string;
  confidence: number | null;
  provider: 'azure' | 'assemblyai' | 'deepgram' | null;
  /** Present only when a reference text was given; null metrics unless scoreState VALID. */
  assessment: Scored | null;
}

export interface RecognizeOptions {
  referenceText?: string | null;
  locale: 'en-US';
  seconds: number;
}

export interface SpeechEngine {
  readonly azure: boolean;
  readonly fallbacks: readonly string[];
  recognize(wav: Buffer, options: RecognizeOptions): Promise<SpeechResult>;
}

export interface SpeechConfig {
  azureKey?: string | undefined;
  azureRegion?: string | undefined;
  assemblyKey?: string | undefined;
  deepgramKey?: string | undefined;
  azureDailySeconds?: number;
  fetch?: Fetch;
  persistence?: AiPersistence;
  nowMs?: () => number;
  /** AssemblyAI poll interval (tests use 0). */
  pollMs?: number;
}

const finite = (v: unknown): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? Math.max(0, Math.min(100, v)) : null;

export function nullScore(scoreState: Scored['scoreState'], reason: string | null): Scored {
  return {
    scoreState,
    accuracy: null,
    fluency: null,
    completeness: null,
    prosody: null,
    words: [],
    reason,
  };
}

/** Normalize an Azure detailed+pronunciation response into the OpenAPI Assessment metrics. */
export function parseAzure(body: unknown, withReference: boolean): SpeechResult {
  const b = (body ?? {}) as Record<string, unknown>;
  const status = String(b['RecognitionStatus'] ?? '');
  const best = (Array.isArray(b['NBest']) ? b['NBest'][0] : undefined) as
    Record<string, unknown> | undefined;
  if (status !== 'Success' || !best) {
    return {
      transcript: '',
      confidence: null,
      provider: 'azure',
      assessment: withReference
        ? nullScore('NULL_LOW_CONFIDENCE', `AZURE_${status || 'EMPTY'}`)
        : null,
    };
  }
  const transcript = String(best['Display'] ?? b['DisplayText'] ?? '').slice(0, 2048);
  const confidence = typeof best['Confidence'] === 'number' ? (best['Confidence'] as number) : null;
  if (!withReference) return { transcript, confidence, provider: 'azure', assessment: null };
  const pa = (best['PronunciationAssessment'] ?? best) as Record<string, unknown>;
  const words: WordScore[] = (Array.isArray(best['Words']) ? best['Words'] : [])
    .slice(0, MAX_WORDS)
    .map((w: Record<string, unknown>) => {
      const wp = (w['PronunciationAssessment'] ?? w) as Record<string, unknown>;
      const phon = Array.isArray(w['Phonemes']) ? w['Phonemes'] : [];
      return {
        word: String(w['Word'] ?? '').slice(0, 128),
        accuracy: finite(wp['AccuracyScore']),
        errorType:
          typeof wp['ErrorType'] === 'string' ? String(wp['ErrorType']).slice(0, 64) : null,
        phonemes: phon.slice(0, MAX_PHONEMES).map((p: Record<string, unknown>) => {
          const pp = (p['PronunciationAssessment'] ?? p) as Record<string, unknown>;
          return {
            phoneme: String(p['Phoneme'] ?? '').slice(0, 32),
            accuracy: finite(pp['AccuracyScore']),
          };
        }),
      };
    });
  const accuracy = finite(pa['AccuracyScore']);
  const completeness = finite(pa['CompletenessScore']);
  const scored: Scored = {
    scoreState: 'VALID',
    accuracy,
    fluency: finite(pa['FluencyScore']),
    completeness,
    prosody: finite(pa['ProsodyScore']),
    words,
    reason: null,
  };
  // V1 quality gate (AI_ARCHITECTURE): nonempty transcript, finite accuracy+completeness,
  // documented 0..1 confidence >= 0.5 when returned. Otherwise every metric stays null.
  const lowConfidence = confidence !== null && confidence < 0.5;
  if (!transcript.trim() || accuracy === null || completeness === null || lowConfidence) {
    return {
      transcript,
      confidence,
      provider: 'azure',
      assessment: nullScore('NULL_LOW_CONFIDENCE', lowConfidence ? 'LOW_CONFIDENCE' : 'NO_SCORE'),
    };
  }
  return { transcript, confidence, provider: 'azure', assessment: scored };
}

class Lru<V> {
  private map = new Map<string, V>();
  constructor(private readonly max: number) {}
  get(key: string): V | undefined {
    const v = this.map.get(key);
    if (v !== undefined) {
      this.map.delete(key);
      this.map.set(key, v);
    }
    return v;
  }
  set(key: string, v: V) {
    this.map.delete(key);
    this.map.set(key, v);
    if (this.map.size > this.max) this.map.delete(this.map.keys().next().value as string);
  }
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function createSpeechEngine(config: SpeechConfig): SpeechEngine {
  const http: Fetch = config.fetch ?? ((url, init) => fetch(url, init));
  const now = config.nowMs ?? Date.now;
  const region =
    config.azureRegion && /^[a-z0-9]+$/.test(config.azureRegion) ? config.azureRegion : '';
  const azure = Boolean(config.azureKey && region);
  const dailyCap = config.azureDailySeconds ?? DEFAULT_AZURE_DAILY_SECONDS;
  const cache = new Lru<SpeechResult>(200);
  const fallbacks = [
    ...(config.assemblyKey ? ['assemblyai'] : []),
    ...(config.deepgramKey ? ['deepgram'] : []),
  ];

  /** Reserve Azure seconds on the project-wide daily row; false when the cap would be passed. */
  async function reserveAzure(seconds: number): Promise<boolean> {
    if (!config.persistence || config.persistence.kind === 'disabled') return true;
    const t = now();
    const utcDay = new Date(t).toISOString().slice(0, 10);
    const id = ids.usage(SPEECH_GLOBAL_USER, utcDay);
    try {
      return await config.persistence.transact(async (tx) => {
        const row = await tx.get('a_usage', id);
        const used = Number(row?.['recordedSpeechSeconds'] ?? 0);
        if (used + seconds > dailyCap) return false;
        tx.put(
          'a_usage',
          id,
          stamp(
            row,
            {
              userId: SPEECH_GLOBAL_USER,
              utcDay,
              liveReservedSeconds: 0,
              liveUsedSeconds: 0,
              liveGrants: 0,
              textRequests: Number(row?.['textRequests'] ?? 0) + 1,
              recordedSpeechSeconds: used + seconds,
              recordedReservedSeconds: 0,
              reservationIdsJson: '[]',
            },
            t,
          ),
        );
        return true;
      });
    } catch {
      return false;
    }
  }

  async function callAzure(wav: Buffer, reference: string | null): Promise<SpeechResult | null> {
    const params = new URLSearchParams({ language: 'en-US', format: 'detailed' });
    const headers: Record<string, string> = {
      'Ocp-Apim-Subscription-Key': String(config.azureKey),
      'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      Accept: 'application/json',
    };
    if (reference) {
      headers['Pronunciation-Assessment'] = Buffer.from(
        JSON.stringify({
          ReferenceText: reference,
          GradingSystem: 'HundredMark',
          Granularity: 'Phoneme',
          Dimension: 'Comprehensive',
          EnableMiscue: true,
          EnableProsodyAssessment: true,
        }),
      ).toString('base64');
    }
    const res = await http(
      `https://${region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?${params}`,
      { method: 'POST', headers, body: new Uint8Array(wav), signal: AbortSignal.timeout(20_000) },
    );
    if (!res.ok) return null;
    return parseAzure(await res.json(), Boolean(reference));
  }

  async function callAssembly(wav: Buffer): Promise<SpeechResult | null> {
    const auth = { authorization: String(config.assemblyKey) };
    const up = await http('https://api.assemblyai.com/v2/upload', {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/octet-stream' },
      body: new Uint8Array(wav),
      signal: AbortSignal.timeout(15_000),
    });
    if (!up.ok) return null;
    const { upload_url } = (await up.json()) as { upload_url?: string };
    if (!upload_url) return null;
    const created = await http('https://api.assemblyai.com/v2/transcript', {
      method: 'POST',
      headers: { ...auth, 'content-type': 'application/json' },
      body: JSON.stringify({ audio_url: upload_url, language_code: 'en_us', punctuate: true }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!created.ok) return null;
    const { id } = (await created.json()) as { id?: string };
    if (!id || !/^[A-Za-z0-9-]+$/.test(id)) return null;
    const deadline = now() + 25_000;
    while (now() < deadline) {
      const r = await http(`https://api.assemblyai.com/v2/transcript/${id}`, {
        headers: auth,
        signal: AbortSignal.timeout(10_000),
      });
      if (!r.ok) return null;
      const body = (await r.json()) as { status?: string; text?: string; confidence?: number };
      if (body.status === 'completed') {
        return {
          transcript: String(body.text ?? '').slice(0, 2048),
          confidence: typeof body.confidence === 'number' ? body.confidence : null,
          provider: 'assemblyai',
          assessment: null,
        };
      }
      if (body.status === 'error') return null;
      await sleep(config.pollMs ?? 700);
    }
    return null;
  }

  async function callDeepgram(wav: Buffer): Promise<SpeechResult | null> {
    const res = await http(
      'https://api.deepgram.com/v1/listen?model=nova-3&language=en&smart_format=true',
      {
        method: 'POST',
        headers: { authorization: `Token ${config.deepgramKey}`, 'content-type': 'audio/wav' },
        body: new Uint8Array(wav),
        signal: AbortSignal.timeout(20_000),
      },
    );
    if (!res.ok) return null;
    const body = (await res.json()) as {
      results?: { channels?: { alternatives?: { transcript?: string; confidence?: number }[] }[] };
    };
    const alt = body.results?.channels?.[0]?.alternatives?.[0];
    if (!alt) return null;
    return {
      transcript: String(alt.transcript ?? '').slice(0, 2048),
      confidence: typeof alt.confidence === 'number' ? alt.confidence : null,
      provider: 'deepgram',
      assessment: null,
    };
  }

  async function safe(fn: () => Promise<SpeechResult | null>): Promise<SpeechResult | null> {
    try {
      return await fn();
    } catch {
      return null;
    }
  }

  return {
    azure,
    fallbacks,
    async recognize(wav, options) {
      const reference = options.referenceText?.trim() ? options.referenceText.trim() : null;
      const key = sha256Hex(`${sha256Hex(wav)}|${reference ?? ''}|${options.locale}`);
      const hit = cache.get(key);
      if (hit) return hit;
      let unavailable = azure ? null : 'AZURE_DISABLED';
      if (azure) {
        if (await reserveAzure(options.seconds)) {
          const r = await safe(() => callAzure(wav, reference));
          if (r) {
            cache.set(key, r);
            return r;
          }
          unavailable = 'AZURE_FAILED';
        } else {
          unavailable = 'DAILY_CAP';
        }
      }
      for (const name of fallbacks) {
        const r = await safe(() => (name === 'assemblyai' ? callAssembly(wav) : callDeepgram(wav)));
        if (r) {
          const out = {
            ...r,
            assessment: reference ? nullScore('NULL_UNAVAILABLE', unavailable) : null,
          };
          cache.set(key, out);
          return out;
        }
      }
      return {
        transcript: '',
        confidence: null,
        provider: null,
        assessment: reference
          ? nullScore(
              unavailable === 'AZURE_FAILED' ? 'FAILED' : 'NULL_UNAVAILABLE',
              unavailable ?? 'STT_UNAVAILABLE',
            )
          : null,
      };
    },
  };
}

/** Engine from function env (null when no speech provider key is configured). */
export function speechFromEnv(
  env: Record<string, string | undefined>,
  persistence: AiPersistence,
): SpeechEngine | null {
  if (env['COC_AI_PROVIDER'] !== 'speech') return null;
  const cap = Number(env['COC_SPEECH_DAILY_SECONDS']);
  const engine = createSpeechEngine({
    azureKey: env['COC_AZURE_SPEECH_KEY'] || undefined,
    azureRegion: env['COC_AZURE_SPEECH_REGION'] || undefined,
    assemblyKey: env['COC_ASSEMBLYAI_API_KEY'] || undefined,
    deepgramKey: env['COC_DEEPGRAM_API_KEY'] || undefined,
    azureDailySeconds: Number.isInteger(cap) && cap > 0 ? cap : DEFAULT_AZURE_DAILY_SECONDS,
    persistence,
  });
  return engine.azure || engine.fallbacks.length ? engine : null;
}
