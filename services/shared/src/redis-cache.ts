// ADR-0018 disposable Redis read cache. Cache failures always fall through to owner reads.
import { createClient, type RedisClientOptions } from '@redis/client';
import type { ReadCache } from './ports.js';
import { PUBLIC_TTL_CAP_SECONDS, type ReadCacheConfig } from './read-cache.js';

const MAX_SCAN_PAGES = 32;
const SCAN_COUNT = 100;
const MAX_INVALIDATION_KEYS = MAX_SCAN_PAGES * SCAN_COUNT;
const MAX_KEY_BYTES = 1024;
const ENVIRONMENT = /^[a-z0-9-]{1,16}$/;
const OWNER = '(?:learning|progress|ai)';
const GLOB_META = /[?*\[\]\\]/;

type RedisConfig = Extract<ReadCacheConfig, { mode: 'redis' }>;

interface RedisClient {
  on(event: 'ready' | 'end' | 'error', listener: () => void): RedisClient;
  connect(): Promise<unknown>;
  get(key: string): Promise<unknown>;
  set(key: string, value: string, options: { EX: number }): Promise<unknown>;
  scan(
    cursor: string,
    options: { MATCH: string; COUNT: number },
  ): Promise<{ cursor: string; keys: string[] }>;
  unlink(keys: string[]): Promise<unknown>;
  destroy(): void;
}

export type RedisClientFactory = (options: RedisClientOptions) => RedisClient;

class CacheFailure extends Error {
  constructor(readonly reason: 'CLOSED' | 'TIMEOUT' | 'UNAVAILABLE') {
    super(reason);
  }
}

function destroy(client: RedisClient | undefined): void {
  try {
    client?.destroy();
  } catch {
    // Destruction is best effort. The adapter remains failed open and drops this client.
  }
}

/** Creates an opt-in Redis cache. Runtime selection remains disabled unless explicitly wired. */
export function createRedisReadCache(
  config: RedisConfig,
  clientFactory: RedisClientFactory = (options) => createClient(options) as RedisClient,
): ReadCache {
  const namespace = ENVIRONMENT.test(config.environment)
    ? new RegExp(`^coc:${config.environment}:${OWNER}:`)
    : undefined;
  let client: RedisClient | undefined;
  let connecting: Promise<RedisClient> | undefined;
  let closed = false;
  let connected = false;
  let reason: string | undefined = 'CONNECTING';
  let closeSignalResolve: (() => void) | undefined;
  const closeSignal = new Promise<void>((resolve) => {
    closeSignalResolve = resolve;
  });

  const valid = (value: string): boolean =>
    namespace !== undefined &&
    Buffer.byteLength(value) <= MAX_KEY_BYTES &&
    !GLOB_META.test(value) &&
    namespace.test(value);

  const discard = (target: RedisClient | undefined): void => {
    if (client === target) client = undefined;
    connecting = undefined;
    connected = false;
    destroy(target);
  };

  const fail = (
    failureReason: 'CLOSED' | 'TIMEOUT' | 'UNAVAILABLE',
    target: RedisClient | undefined,
  ): CacheFailure => {
    discard(target);
    reason = failureReason;
    return new CacheFailure(failureReason);
  };

  const deadline = async <T>(operation: Promise<T>, target: RedisClient): Promise<T> => {
    let timer: NodeJS.Timeout | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(fail('TIMEOUT', target)), config.timeoutMs);
    });
    const closing = closeSignal.then(() => {
      throw new CacheFailure('CLOSED');
    });
    try {
      return await Promise.race([operation, timeout, closing]);
    } finally {
      if (timer) clearTimeout(timer);
    }
  };

  const getClient = async (): Promise<RedisClient> => {
    if (closed) throw new CacheFailure('CLOSED');
    if (client && connected) return client;
    if (!client) {
      const next = clientFactory({
        url: config.url,
        socket: { connectTimeout: config.timeoutMs, reconnectStrategy: false },
        disableOfflineQueue: true,
        commandsQueueMaxLength: SCAN_COUNT,
      });
      client = next;
      next.on('error', () => {
        if (client === next && !closed) reason = 'UNAVAILABLE';
      });
      next.on('ready', () => {
        if (client === next && !closed) {
          connected = true;
          reason = undefined;
        }
      });
      next.on('end', () => {
        if (client === next && !closed) {
          client = undefined;
          connecting = undefined;
          connected = false;
          reason = 'DISCONNECTED';
        }
      });
      connecting = deadline(
        Promise.resolve(next.connect()).then(() => next),
        next,
      );
    }
    try {
      return await connecting!;
    } catch (error) {
      if (error instanceof CacheFailure) throw error;
      throw fail('UNAVAILABLE', client);
    } finally {
      connecting = undefined;
    }
  };

  const run = async <T>(operation: (active: RedisClient) => Promise<T>): Promise<T> => {
    const active = await getClient();
    try {
      const result = await deadline(operation(active), active);
      if (!closed) {
        connected = true;
        reason = undefined;
      }
      return result;
    } catch (error) {
      if (closed || error instanceof CacheFailure) throw error;
      throw fail('UNAVAILABLE', active);
    }
  };

  return {
    kind: 'redis',
    async get(key) {
      if (!valid(key) || closed) return undefined;
      try {
        const value = await run((active) => active.get(key));
        if (value === null) return undefined;
        if (typeof value !== 'string') {
          reason = 'CORRUPT_RESPONSE';
          return undefined;
        }
        return value;
      } catch {
        return undefined;
      }
    },
    async set(key, value, ttlSeconds) {
      if (
        !valid(key) ||
        closed ||
        Buffer.byteLength(value) > config.maxValueBytes ||
        !Number.isFinite(ttlSeconds) ||
        ttlSeconds <= 0
      ) {
        return;
      }
      const ttl = Math.min(Math.floor(ttlSeconds), PUBLIC_TTL_CAP_SECONDS);
      if (ttl < 1) return;
      try {
        await run((active) => active.set(key, value, { EX: ttl }));
      } catch {
        // Cache write failure never fails the owner request.
      }
    },
    async invalidate(prefix) {
      if (!valid(prefix) || closed) return;
      try {
        let cursor = '0';
        let removed = 0;
        for (let page = 0; page < MAX_SCAN_PAGES; page++) {
          const result = await run((active) =>
            active.scan(cursor, { MATCH: `${prefix}*`, COUNT: SCAN_COUNT }),
          );
          const keys = Array.isArray(result.keys)
            ? result.keys
                .filter((key): key is string => typeof key === 'string' && valid(key))
                .filter((key) => key.startsWith(prefix))
            : [];
          // COUNT is a hint: Redis may return more than SCAN_COUNT keys in one
          // page. Do not silently drop the tail; bound each command and the
          // total work, with remaining entries expiring through their TTL.
          const remaining = MAX_INVALIDATION_KEYS - removed;
          const selected = keys.slice(0, remaining);
          for (let offset = 0; offset < selected.length; offset += SCAN_COUNT) {
            await run((active) => active.unlink(selected.slice(offset, offset + SCAN_COUNT)));
          }
          removed += selected.length;
          cursor = typeof result.cursor === 'string' ? result.cursor : '0';
          if (
            selected.length < keys.length ||
            (removed === MAX_INVALIDATION_KEYS && cursor !== '0')
          ) {
            reason = 'INVALIDATION_LIMIT';
            break;
          }
          if (cursor === '0') break;
          if (page === MAX_SCAN_PAGES - 1) reason = 'INVALIDATION_LIMIT';
        }
      } catch {
        // Invalidation failure expires naturally through bounded TTLs.
      }
    },
    health() {
      return reason === undefined
        ? { kind: 'redis', connected }
        : { kind: 'redis', connected, reason };
    },
    async close() {
      if (closed) return;
      closed = true;
      reason = 'CLOSED';
      connected = false;
      closeSignalResolve?.();
      discard(client);
      reason = 'CLOSED';
    },
  };
}
