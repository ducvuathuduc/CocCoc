// Publication media integrity gate. A published pointer may flip only when every media file the
// bundles declare (`bundle.assets`) is in the target Storage bucket, complete, the declared size,
// readable by Mobile (file-level read(Role.any()), the policy LessonAudioStore/LessonImageStore rely
// on), and its bytes hash to the declared sha256. Anything else fails closed and writes nothing, so
// immutable versions are never touched by a rejected publish.
//
// Cost control (a real course references 14,888 assets, 1,760 unique, 14.5 MB):
//   - assets are de-duplicated by fileId first (conflicting declarations are rejected offline);
//   - existence/size/permission come from BATCHED metadata calls (MEDIA_STAT_BATCH ids per call),
//     never one request per asset;
//   - sha256 needs the bytes (Storage only keeps an MD5), so bytes are downloaded once per stored
//     object and remembered by (fileId, sha256, object version) for the life of the process;
//   - every phase runs with bounded concurrency, a per-call timeout, one bounded retry for transient
//     failures, and a wall-clock deadline. An exhausted deadline fails closed and keeps its progress
//     in the cache, so the retry resumes instead of starting over;
//   - `confirm()` re-reads metadata only (no bytes) right before the pointer flips.
import { createHash } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import type { Asset, LessonBundle } from './types.js';

/** Metadata Storage keeps for one file; never includes the body. */
export interface MediaStat {
  /** Stored original size in bytes. */
  bytes: number;
  /** Opaque token that changes whenever the stored object changes (e.g. MD5 + updatedAt). */
  version: string;
  /** False while a chunked upload is unfinished. */
  complete: boolean;
  /** True when anonymous clients can read the file (read(Role.any())). */
  publicRead: boolean;
}

export interface MediaStore {
  /**
   * Metadata for at most MEDIA_STAT_BATCH ids in a single round trip. Ids that do not exist are
   * absent from the map. Throws ServiceError('STORAGE_UNAVAILABLE', {details:{reason}}) on failure.
   */
  stat(fileIds: readonly string[]): Promise<Map<string, MediaStat>>;
  /** Raw bytes, or null when the file does not exist. Same error contract as `stat`. */
  readBytes(fileId: string): Promise<Uint8Array | null>;
}

/** Ids per metadata call. Appwrite caps one query at 4096 characters; 50 ids of <= 36 chars fit. */
export const MEDIA_STAT_BATCH = 50;

export const MEDIA_REASONS = {
  permissionDenied: 'MEDIA_PERMISSION_DENIED',
  unavailable: 'MEDIA_STORAGE_UNAVAILABLE',
  timeout: 'MEDIA_TIMEOUT',
  deadline: 'MEDIA_VERIFICATION_DEADLINE',
  notConfigured: 'MEDIA_VERIFICATION_UNAVAILABLE',
  changed: 'MEDIA_CHANGED_DURING_PUBLISH',
} as const;

export interface MediaPolicy {
  /** Parallel Storage calls in flight (metadata batches and downloads). */
  concurrency: number;
  /** Per Storage call. */
  callTimeoutMs: number;
  /** Wall clock for one `verify()`; keep it under the hosting function timeout (60 s). */
  deadlineMs: number;
  /** Extra attempts for a timed-out or unavailable call. Permission errors are never retried. */
  retries: number;
  retryDelayMs: number;
  maxAssets: number;
  maxTotalBytes: number;
  /** Mobile refuses larger downloads: LessonAudioStore.maxBytes, LessonImageStore.maxBytes. */
  maxAudioBytes: number;
  maxImageBytes: number;
  /** Stop scheduling work after this many content problems. */
  maxProblems: number;
}

export const DEFAULT_MEDIA_POLICY: MediaPolicy = {
  concurrency: 8,
  callTimeoutMs: 10_000,
  deadlineMs: 35_000,
  retries: 1,
  retryDelayMs: 250,
  maxAssets: 5_000,
  maxTotalBytes: 256 * 1024 * 1024,
  maxAudioBytes: 2 * 1024 * 1024,
  maxImageBytes: 5 * 1024 * 1024,
  maxProblems: 20,
};

function boundedInt(raw: string | undefined, min: number, max: number): number | undefined {
  if (!raw || !/^\d{1,9}$/.test(raw)) return undefined;
  const value = Number(raw);
  return value >= min && value <= max ? value : undefined;
}

/** Hosted tuning knobs: COC_MEDIA_VERIFY_CONCURRENCY (1-16), COC_MEDIA_VERIFY_DEADLINE_MS (1 s-55 s). */
export function mediaPolicyFromEnv(env: Record<string, string | undefined>): Partial<MediaPolicy> {
  const concurrency = boundedInt(env['COC_MEDIA_VERIFY_CONCURRENCY'], 1, 16);
  const deadlineMs = boundedInt(env['COC_MEDIA_VERIFY_DEADLINE_MS'], 1_000, 55_000);
  return {
    ...(concurrency !== undefined ? { concurrency } : {}),
    ...(deadlineMs !== undefined ? { deadlineMs } : {}),
  };
}

export interface MediaProblem {
  where: string;
  problem: string;
}

/** What one successful verification looked at; `confirm()` replays the metadata half of it. */
export interface MediaEvidence {
  /** Unique files. */
  assets: number;
  /** Asset declarations across all bundles (before de-duplication). */
  references: number;
  bytes: number;
  statCalls: number;
  readCalls: number;
  /** Assets whose bytes were already verified in this process. */
  cacheHits: number;
  elapsedMs: number;
  /** fileId -> stored-object version at verification time. */
  identities: ReadonlyMap<string, string>;
}

export interface MediaVerifier {
  readonly policy: MediaPolicy;
  verify(bundles: readonly LessonBundle[]): Promise<MediaEvidence>;
  /** Metadata-only recheck, run right before the pointer flip. */
  confirm(evidence: MediaEvidence): Promise<void>;
}

interface Collected {
  assets: Map<string, Asset>;
  references: number;
  problems: MediaProblem[];
}

const sameDeclaration = (a: Asset, b: Asset) =>
  a.sha256 === b.sha256 && a.bytes === b.bytes && a.mime === b.mime;

function collect(bundles: readonly LessonBundle[], policy: MediaPolicy): Collected {
  const assets = new Map<string, Asset>();
  const problems: MediaProblem[] = [];
  let references = 0;
  let total = 0;
  const conflicted = new Set<string>();
  for (const bundle of bundles) {
    for (const asset of bundle.assets ?? []) {
      references += 1;
      const prior = assets.get(asset.fileId);
      if (!prior) {
        assets.set(asset.fileId, asset);
        total += asset.bytes;
        continue;
      }
      if (!sameDeclaration(prior, asset) && !conflicted.has(asset.fileId)) {
        conflicted.add(asset.fileId);
        problems.push({ where: asset.fileId, problem: 'MEDIA_METADATA_CONFLICT' });
      }
    }
  }
  for (const asset of assets.values()) {
    const cap = asset.mime.startsWith('audio/') ? policy.maxAudioBytes : policy.maxImageBytes;
    if (!Number.isInteger(asset.bytes) || asset.bytes <= 0 || asset.bytes > cap)
      problems.push({ where: asset.fileId, problem: 'MEDIA_SIZE_OUT_OF_POLICY' });
  }
  if (assets.size > policy.maxAssets || total > policy.maxTotalBytes)
    problems.push({ where: 'media', problem: 'MEDIA_BUDGET_EXCEEDED' });
  return { assets, references, problems };
}

const sha256Hex = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex');

function reasonOf(error: unknown): string {
  if (error instanceof ServiceError) {
    const reason = error.details['reason'];
    if (typeof reason === 'string' && reason.startsWith('MEDIA_')) return reason;
  }
  return MEDIA_REASONS.unavailable;
}

function withTimeout<T>(work: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(
      () =>
        reject(
          new ServiceError('STORAGE_UNAVAILABLE', { details: { reason: MEDIA_REASONS.timeout } }),
        ),
      ms,
    );
  });
  return Promise.race([work, timeout]).finally(() => clearTimeout(timer));
}

const chunks = <T>(items: readonly T[], size: number): T[][] => {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
};

export function createMediaVerifier(
  store: MediaStore | undefined,
  options: { policy?: Partial<MediaPolicy>; nowMs?: () => number } = {},
): MediaVerifier {
  const policy: MediaPolicy = { ...DEFAULT_MEDIA_POLICY, ...options.policy };
  const now = options.nowMs ?? Date.now;
  /** Stored objects whose bytes already hashed to the declared sha256 (bounded). */
  const verifiedBytes = new Set<string>();
  const VERIFIED_LIMIT = 20_000;

  interface Run {
    deadline: number;
    infra: Map<string, number>;
    problems: MediaProblem[];
    statCalls: number;
    readCalls: number;
    pending: number;
  }

  const stopped = (run: Run) =>
    run.infra.size > 0 || run.problems.length >= policy.maxProblems || now() >= run.deadline;

  async function pool<T>(run: Run, items: readonly T[], work: (item: T) => Promise<void>) {
    let next = 0;
    const worker = async () => {
      while (!stopped(run)) {
        const index = next++;
        if (index >= items.length) return;
        await work(items[index] as T);
      }
    };
    await Promise.all(Array.from({ length: Math.min(policy.concurrency, items.length) }, worker));
    run.pending += Math.max(0, items.length - next);
  }

  /** One Storage call: timeout, bounded retry for transient failures, failures recorded not thrown. */
  async function call<T>(run: Run, work: () => Promise<T>): Promise<T | undefined> {
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await withTimeout(work(), policy.callTimeoutMs);
      } catch (error) {
        const reason = reasonOf(error);
        const retry =
          reason !== MEDIA_REASONS.permissionDenied &&
          attempt < policy.retries &&
          now() + policy.retryDelayMs < run.deadline;
        if (!retry) {
          run.infra.set(reason, (run.infra.get(reason) ?? 0) + 1);
          return undefined;
        }
        await new Promise((resolve) => setTimeout(resolve, policy.retryDelayMs));
      }
    }
  }

  function newRun(): Run {
    return {
      deadline: now() + policy.deadlineMs,
      infra: new Map(),
      problems: [],
      statCalls: 0,
      readCalls: 0,
      pending: 0,
    };
  }

  function requireStore(): MediaStore {
    if (!store || typeof store.stat !== 'function' || typeof store.readBytes !== 'function') {
      throw new ServiceError('STORAGE_UNAVAILABLE', {
        details: { reason: MEDIA_REASONS.notConfigured },
      });
    }
    return store;
  }

  function throwIfFailed(run: Run): void {
    if (run.infra.size) {
      // A denied key is a configuration fault and outranks a flaky network, which outranks a timeout.
      const order = [
        MEDIA_REASONS.permissionDenied,
        MEDIA_REASONS.timeout,
        MEDIA_REASONS.unavailable,
      ];
      const reason = order.find((r) => run.infra.has(r)) ?? MEDIA_REASONS.unavailable;
      throw new ServiceError('STORAGE_UNAVAILABLE', {
        details: { reason, failedCalls: [...run.infra.values()].reduce((a, b) => a + b, 0) },
      });
    }
    if (run.problems.length) {
      throw new ServiceError('VALIDATION_ERROR', {
        details: {
          problems: run.problems.slice(0, policy.maxProblems),
          problemCount: run.problems.length,
        },
      });
    }
    if (run.pending > 0) {
      throw new ServiceError('STORAGE_UNAVAILABLE', {
        details: { reason: MEDIA_REASONS.deadline, unverified: run.pending },
      });
    }
  }

  /** Batched metadata for `ids`; the callback sees every id with its stat or null. */
  async function statAll(
    run: Run,
    ids: readonly string[],
    each: (id: string, stat: MediaStat | null) => void,
  ) {
    const media = requireStore();
    await pool(run, chunks(ids, MEDIA_STAT_BATCH), async (batch) => {
      run.statCalls += 1;
      const found = await call(run, () => media.stat(batch));
      if (!found) return;
      for (const id of batch) each(id, found.get(id) ?? null);
    });
  }

  return {
    policy,

    async verify(bundles) {
      const started = now();
      const { assets, references, problems } = collect(bundles, policy);
      if (problems.length) {
        throw new ServiceError('VALIDATION_ERROR', {
          details: {
            problems: problems.slice(0, policy.maxProblems),
            problemCount: problems.length,
          },
        });
      }
      const run = newRun();
      const identities = new Map<string, string>();
      const evidence = (cacheHits: number): MediaEvidence => ({
        assets: assets.size,
        references,
        bytes: [...assets.values()].reduce((sum, a) => sum + a.bytes, 0),
        statCalls: run.statCalls,
        readCalls: run.readCalls,
        cacheHits,
        elapsedMs: now() - started,
        identities,
      });
      if (!assets.size) return evidence(0);
      const media = requireStore();

      // 1. Existence, completeness, size and Mobile read permission, in batches.
      const sound: Asset[] = [];
      await statAll(run, [...assets.keys()], (id, stat) => {
        const asset = assets.get(id) as Asset;
        if (!stat) {
          run.problems.push({ where: id, problem: 'MEDIA_MISSING' });
          return;
        }
        identities.set(id, stat.version);
        if (!stat.complete) run.problems.push({ where: id, problem: 'MEDIA_INCOMPLETE' });
        else if (stat.bytes !== asset.bytes)
          run.problems.push({ where: id, problem: 'MEDIA_SIZE_MISMATCH' });
        else if (!stat.publicRead) run.problems.push({ where: id, problem: 'MEDIA_NOT_PUBLIC' });
        else sound.push(asset);
      });
      throwIfFailed(run);

      // 2. Bytes -> sha256, only for stored objects not already verified in this process.
      const keyOf = (asset: Asset) =>
        `${asset.fileId}\u0000${asset.sha256}\u0000${identities.get(asset.fileId) ?? ''}`;
      let cacheHits = 0;
      const todo: Asset[] = [];
      for (const asset of sound) {
        if (verifiedBytes.has(keyOf(asset))) cacheHits += 1;
        else todo.push(asset);
      }
      await pool(run, todo, async (asset) => {
        run.readCalls += 1;
        const bytes = await call(run, () => media.readBytes(asset.fileId));
        if (bytes === undefined) return;
        const fail = (problem: string) => run.problems.push({ where: asset.fileId, problem });
        if (bytes === null) fail('MEDIA_MISSING');
        else if (bytes.byteLength !== asset.bytes) fail('MEDIA_SIZE_MISMATCH');
        else if (sha256Hex(bytes) !== asset.sha256) fail('MEDIA_HASH_MISMATCH');
        else {
          if (verifiedBytes.size >= VERIFIED_LIMIT) verifiedBytes.clear();
          verifiedBytes.add(keyOf(asset));
        }
      });
      throwIfFailed(run);
      return evidence(cacheHits);
    },

    async confirm(evidence) {
      const run = newRun();
      await statAll(run, [...evidence.identities.keys()], (id, stat) => {
        if (!stat) run.problems.push({ where: id, problem: 'MEDIA_MISSING' });
        else if (!stat.complete) run.problems.push({ where: id, problem: 'MEDIA_INCOMPLETE' });
        else if (!stat.publicRead) run.problems.push({ where: id, problem: 'MEDIA_NOT_PUBLIC' });
        else if (stat.version !== evidence.identities.get(id))
          run.problems.push({ where: id, problem: MEDIA_REASONS.changed });
      });
      const onlyChanged =
        run.problems.length > 0 && run.problems.every((p) => p.problem === MEDIA_REASONS.changed);
      if (!run.infra.size && onlyChanged) {
        // The object was replaced between verification and commit: re-verify, do not guess.
        throw new ServiceError('REVISION_CONFLICT', {
          details: {
            reason: MEDIA_REASONS.changed,
            problems: run.problems.slice(0, policy.maxProblems),
          },
        });
      }
      throwIfFailed(run);
    },
  };
}
