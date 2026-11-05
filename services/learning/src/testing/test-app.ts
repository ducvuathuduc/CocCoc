// TEST ONLY: the real Learning router + use cases over the memory adapter and committed content,
// with a fake auth port (`Bearer user-<id>`) and an injectable clock / event delivery.
import { randomUUID } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import type { Keyring } from '../../../shared/src/service-hmac.js';
import { createRouter } from '../../../shared/src/transport.js';
import { publishContent } from '../application/content.js';
import type { LearningDeps } from '../application/deps.js';
import { createImmediateRelay } from '../application/relay.js';
import type { Deliver } from '../application/outbox.js';
import { createContentRepository, type ContentFileStore } from '../content/repository.js';
import { learningHandler, learningWiring } from '../http/wiring.js';
import { createMemoryLearningPersistence } from '../persistence/memory.js';
import type { LearningPersistence } from '../persistence/port.js';
import { devContentKeyring } from './dev-content-key.js';
import { loadLocalContent } from './local-content.js';

export interface CallOptions {
  user?: string;
  body?: unknown;
  key?: string;
  query?: string;
  headers?: Record<string, string>;
}
export interface CallResult {
  status: number;
  body: unknown;
  headers: Record<string, string>;
}

export async function createTestApp(
  options: {
    root?: string;
    nowMs?: () => number;
    deliver?: Deliver;
    keyring?: Keyring;
    persistence?: LearningPersistence;
    files?: ContentFileStore;
    seed?: boolean;
    energyMode?: 'LIMITED' | 'UNLIMITED';
  } = {},
) {
  const persistence = options.persistence ?? createMemoryLearningPersistence(options.nowMs);
  const local = loadLocalContent(options.root ?? process.cwd());
  const deps: LearningDeps = {
    persistence,
    content: createContentRepository({
      persistence,
      files: options.files ?? local.files,
      keyring: devContentKeyring(),
    }),
    nowMs: options.nowMs ?? Date.now,
    newId: randomUUID,
    maintainers: new Set(['maintainer-1']),
  };
  if (options.energyMode) deps.energyMode = options.energyMode;
  if (options.deliver) {
    deps.deliver = options.deliver;
    deps.relay = createImmediateRelay(() => deps, options.deliver);
  }
  if (options.seed !== false) {
    for (const p of local.publications) {
      await publishContent(
        deps,
        'system',
        { ...p, expectedPublishedVersion: null },
        randomUUID(),
        'seed',
        'seed',
        { system: true },
      );
    }
  }
  const router = createRouter({
    service: 'learning',
    persistence,
    mode: 'local-test',
    auth: {
      async verify(jwt) {
        const match = /^user-([A-Za-z0-9][A-Za-z0-9_.-]{0,35})$/.exec(jwt);
        if (!match?.[1]) throw new ServiceError('AUTH_REQUIRED');
        return { userId: match[1] };
      },
    },
    ...(options.keyring ? { keyring: options.keyring } : {}),
    ...(options.nowMs ? { nowMs: options.nowMs } : {}),
    ...learningWiring(deps),
  });
  const handler = learningHandler(router, deps);
  async function call(method: string, path: string, opts: CallOptions = {}): Promise<CallResult> {
    let out: CallResult = { status: 0, body: null, headers: {} };
    const headers: Record<string, string> = { ...(opts.headers ?? {}) };
    if (opts.user) headers['authorization'] = `Bearer user-${opts.user}`;
    if (opts.key) headers['idempotency-key'] = opts.key;
    await handler({
      req: {
        method,
        path,
        headers,
        ...(opts.body !== undefined
          ? { bodyText: typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body) }
          : {}),
        queryString: opts.query ?? '',
      },
      res: {
        json: (body, status = 200, responseHeaders = {}) => {
          out = { status, body: structuredClone(body), headers: responseHeaders };
          return out;
        },
      },
    });
    return out;
  }
  return { call, deps, persistence, handler, routes: learningWiring(deps).routes };
}
