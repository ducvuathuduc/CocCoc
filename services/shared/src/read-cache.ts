// ADR-0018 derived read cache: selection, the disabled form, namespaced keys and cache-aside.
// Default: disabled (every read goes to the owner store). Redis is used only when
// COC_READ_CACHE=redis and COC_REDIS_URL is rediss:// (or redis:// with the explicit private
// Compose marker). A cache never authorizes, spends, grades or settles; private snapshots bypass
// it unless COC_CACHE_PRIVATE_SNAPSHOTS=admitted (TTL cap 15 s), public projections cap at 60 s.
import { createHash } from 'node:crypto';
import type { ReadCache, ServiceName } from './ports.js';

export const PUBLIC_TTL_CAP_SECONDS = 60;
export const PRIVATE_TTL_CAP_SECONDS = 15;
export const PLAINTEXT_CACHE_MARKER = 'private-compose-network';
const ENVIRONMENT = /^[a-z0-9-]{1,16}$/;

export type ReadCacheConfig =
  | { mode: 'disabled'; reason: string }
  | {
      mode: 'redis';
      url: string;
      environment: string;
      privateSnapshots: boolean;
      timeoutMs: number;
      maxValueBytes: number;
    };

function bounded(raw: string | undefined, fallback: number, min: number, max: number): number {
  const value = raw === undefined || raw === '' ? fallback : Number(raw);
  return Number.isSafeInteger(value) && value >= min && value <= max ? value : fallback;
}

export function readCacheConfigFromEnv(env: Record<string, string | undefined>): ReadCacheConfig {
  const mode = env['COC_READ_CACHE'] ?? 'disabled';
  if (mode === 'disabled' || mode === '') return { mode: 'disabled', reason: 'NOT_ENABLED' };
  if (mode !== 'redis') return { mode: 'disabled', reason: 'UNKNOWN_READ_CACHE' };
  const url = env['COC_REDIS_URL'];
  if (!url) return { mode: 'disabled', reason: 'REDIS_URL_MISSING' };
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { mode: 'disabled', reason: 'REDIS_URL_INVALID' };
  }
  if (parsed.protocol !== 'rediss:' && parsed.protocol !== 'redis:') {
    return { mode: 'disabled', reason: 'REDIS_URL_INVALID' };
  }
  if (parsed.protocol === 'redis:' && env['COC_REDIS_ALLOW_PLAINTEXT'] !== PLAINTEXT_CACHE_MARKER) {
    return { mode: 'disabled', reason: 'REDIS_TLS_REQUIRED' };
  }
  const environment = env['COC_CACHE_ENV'] ?? 'default';
  if (!ENVIRONMENT.test(environment)) return { mode: 'disabled', reason: 'CACHE_ENV_INVALID' };
  return {
    mode: 'redis',
    url,
    environment,
    privateSnapshots: env['COC_CACHE_PRIVATE_SNAPSHOTS'] === 'admitted',
    timeoutMs: bounded(env['COC_REDIS_TIMEOUT_MS'], 150, 20, 2000),
    maxValueBytes: bounded(env['COC_REDIS_MAX_VALUE_BYTES'], 262_144, 1024, 4_194_304),
  };
}

export function describeReadCache(config: ReadCacheConfig): Record<string, unknown> {
  return config.mode === 'redis'
    ? { mode: 'redis', environment: config.environment, privateSnapshots: config.privateSnapshots }
    : { mode: 'disabled', reason: config.reason };
}

export function createDisabledReadCache(reason: string): ReadCache {
  return {
    kind: 'disabled',
    get: async () => undefined,
    set: async () => undefined,
    invalidate: async () => undefined,
    health: () => ({ kind: 'disabled', connected: false, reason }),
    close: async () => undefined,
  };
}

const SEGMENT = /^[A-Za-z0-9_.:-]{1,128}$/;
function segment(value: string): string {
  // Opaque identifiers stay readable; anything else is hashed so it can never break the layout.
  return SEGMENT.test(value) && !value.includes(':')
    ? value
    : `h${createHash('sha256').update(value).digest('hex').slice(0, 32)}`;
}

export interface CacheScope {
  environment: string;
  owner: ServiceName;
  /** Bumped when the cached projection's shape changes; old entries simply stop matching. */
  schema: string;
  /** 'public' for owner-safe public projections, or the verified subject's user ID. */
  audience: 'public' | { userId: string };
}

/** Namespace prefix: coc:<env>:<owner>:<schema>:<pub|u.<user>>: */
export function cacheNamespace(scope: CacheScope): string {
  const audience = scope.audience === 'public' ? 'pub' : `u.${segment(scope.audience.userId)}`;
  return `coc:${segment(scope.environment)}:${scope.owner}:${segment(scope.schema)}:${audience}:`;
}

/** Full key: namespace + resource + owner revision (a new revision is a new key). */
export function cacheKey(scope: CacheScope, resource: string, revision: string | number): string {
  return `${cacheNamespace(scope)}${segment(resource)}:r${segment(String(revision))}`;
}

export interface CacheAsideOptions<T> {
  cache: ReadCache;
  key: string;
  ttlSeconds: number;
  /** Private (per-user) data: needs explicit admission, TTL capped at 15 s. */
  private?: boolean;
  privateAdmitted?: boolean;
  load: () => Promise<T>;
  /** Only cache values the owner says are safe and complete (e.g. never an error or empty miss). */
  cacheable?: (value: T) => boolean;
}

/**
 * Cache-aside read. Authorization must already have happened. A miss, a cache error or a
 * corrupt entry falls through to `load` (the owner's primary read); concurrent misses for the
 * same key in this process share one load (request coalescing).
 */
export function createCacheAside() {
  // A key is only meaningful within its cache instance. Coalescing across
  // instances can return a value loaded for a different backing store.
  const byCache = new WeakMap<ReadCache, Map<string, Promise<unknown>>>();
  return async function cacheAside<T>(options: CacheAsideOptions<T>): Promise<T> {
    const isPrivate = options.private === true;
    if (isPrivate && !options.privateAdmitted) return options.load();
    if (options.cache.kind === 'disabled') return options.load();
    const cap = isPrivate ? PRIVATE_TTL_CAP_SECONDS : PUBLIC_TTL_CAP_SECONDS;
    const ttl = Math.max(1, Math.min(Math.floor(options.ttlSeconds), cap));
    try {
      const hit = await options.cache.get(options.key);
      if (hit !== undefined) {
        const envelope: unknown = JSON.parse(hit);
        if (
          envelope !== null &&
          typeof envelope === 'object' &&
          !Array.isArray(envelope) &&
          Object.hasOwn(envelope, 'v')
        ) {
          return (envelope as { v: T }).v;
        }
      }
    } catch {
      // A cache failure or malformed entry is a miss, not an owner-read failure.
    }
    let inflight = byCache.get(options.cache);
    if (!inflight) {
      inflight = new Map<string, Promise<unknown>>();
      byCache.set(options.cache, inflight);
    }
    const pending = inflight.get(options.key) as Promise<T> | undefined;
    if (pending) return pending;
    const loading = (async () => {
      const value = await options.load();
      if (!options.cacheable || options.cacheable(value)) {
        try {
          await options.cache.set(options.key, JSON.stringify({ v: value }), ttl);
        } catch {
          // The owner read is authoritative even if the cache write fails.
        }
      }
      return value;
    })();
    inflight.set(options.key, loading);
    try {
      return await loading;
    } finally {
      inflight.delete(options.key);
    }
  };
}
