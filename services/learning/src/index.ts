// Hosted Learning Function artifact (dist/function.mjs).
// Default: disabled persistence (fail closed). The durable Appwrite TablesDB adapter is selected only
// when COC_LEARNING_PERSISTENCE=appwrite with endpoint/project present, and serves business routes
// only when also admitted (COC_LEARNING_ADMITTED=reviewed-cloud-gate). The Appwrite credential is
// the per-execution dynamic key (`x-appwrite-key`, limited by the function scopes), falling back to
// COC_LEARNING_APPWRITE_KEY / APPWRITE_API_KEY; with neither, data calls fail SERVICE_NOT_CONFIGURED.
// Content trust: COC_CONTENT_PUBLIC_KEYS. Immediate event relay: COC_PROGRESS_URL + a 'learning'
// key in COC_SERVICE_KEYS (otherwise events wait in l_outbox for a dispatcher run).
import { randomUUID } from 'node:crypto';
import { Client, Storage, TablesDB } from 'node-appwrite';
import {
  currentExecutionKey,
  isScheduledExecution,
  plainRequest,
  withExecutionKey,
  type RawAppwriteContext,
} from '../../shared/src/appwrite-entry.js';
import { ServiceError } from '../../shared/src/errors.js';
import { parseKeyring } from '../../shared/src/service-hmac.js';
import { createHostedHandler } from '../../shared/src/transport.js';
import type { LearningDeps } from './application/deps.js';
import { energyModeFrom } from './application/energy.js';
import { dispatchOutbox } from './application/outbox.js';
import { createImmediateRelay, httpDeliver } from './application/relay.js';
import { parseContentKeyring } from './content/integrity.js';
import { createContentRepository, type ContentFileStore } from './content/repository.js';
import { createStorageContentFiles } from './content/storage-files.js';
import { learningHandler, learningWiring } from './http/wiring.js';
import {
  appwriteConfigFromEnv,
  createAppwriteLearningPersistence,
} from './persistence/appwrite.js';
import { createDisabledLearningPersistence } from './persistence/disabled.js';
import type { LearningPersistence } from './persistence/port.js';

const env = process.env;
const fallbackKey = env['COC_LEARNING_APPWRITE_KEY'] ?? env['APPWRITE_API_KEY'];
const config = appwriteConfigFromEnv({ ...env, APPWRITE_API_KEY: fallbackKey ?? 'execution-key' });

/**
 * An Appwrite SDK service whose every call uses the current execution's dynamic key (or the
 * fallback key). One client per key is cached; a new key replaces the old client.
 */
function keyed<T extends object>(make: (client: Client) => T): T {
  let cached: { key: string; service: T } | undefined;
  const current = (): T => {
    const key = currentExecutionKey() ?? fallbackKey;
    if (!key || !config) {
      throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'NO_KEY' } });
    }
    if (cached?.key !== key) {
      const client = new Client()
        .setEndpoint(config.endpoint)
        .setProject(config.projectId)
        .setKey(key);
      cached = { key, service: make(client) };
    }
    return cached.service;
  };
  return new Proxy({} as T, {
    get(_target, prop) {
      const service = current();
      const value = Reflect.get(service, prop, service) as unknown;
      return typeof value === 'function'
        ? (value as (...args: unknown[]) => unknown).bind(service)
        : value;
    },
  });
}

const persistence: LearningPersistence = config
  ? createAppwriteLearningPersistence(
      config,
      keyed((client) => new TablesDB(client)),
    )
  : createDisabledLearningPersistence();
const files: ContentFileStore = config
  ? createStorageContentFiles(
      config,
      keyed((client) => new Storage(client)),
    )
  : { read: async () => null };
let contentKeyring = new Map();
try {
  contentKeyring = new Map(parseContentKeyring(env['COC_CONTENT_PUBLIC_KEYS']));
} catch {
  contentKeyring = new Map(); // malformed key material: content verification fails closed
}
const deps: LearningDeps = {
  persistence,
  content: createContentRepository({ persistence, files, keyring: contentKeyring }),
  nowMs: Date.now,
  newId: randomUUID,
  maintainers: new Set((env['COC_MAINTAINER_USER_IDS'] ?? '').split(',').filter(Boolean)),
  // FR-GAME-005: energy is spent only when the deployment sets COC_ENERGY_MODE=LIMITED.
  energyMode: energyModeFrom(env['COC_ENERGY_MODE']),
};
let serviceKeys;
try {
  serviceKeys = parseKeyring(env['COC_SERVICE_KEYS']);
} catch {
  serviceKeys = undefined;
}
const ownKey = serviceKeys
  ? [...serviceKeys.values()].find((k) => k.sender === 'learning')
  : undefined;
const progressUrl = env['COC_PROGRESS_URL'];
if (ownKey && progressUrl?.startsWith('https://')) {
  deps.deliver = httpDeliver({ key: ownKey, progressBaseUrl: progressUrl });
  deps.relay = createImmediateRelay(() => deps, deps.deliver);
}

const router = learningHandler(
  createHostedHandler('learning', persistence, env, learningWiring(deps)),
  deps,
);

// Appwrite cron (x-appwrite-trigger=schedule at `/`): drain due l_outbox rows. Takes no request
// input; dispatchOutbox leases rows, so a spoofed or overlapping trigger cannot double-apply.
export default async function main(context: RawAppwriteContext): Promise<unknown> {
  const req = plainRequest(context.req);
  return withExecutionKey(req, () => execute(context, req));
}

async function execute(
  context: RawAppwriteContext,
  req: ReturnType<typeof plainRequest>,
): Promise<unknown> {
  if (isScheduledExecution(req)) {
    if (persistence.kind === 'disabled' || !deps.deliver) {
      return context.res.json({ worker: 'learning', status: 'SERVICE_NOT_CONFIGURED' }, 503);
    }
    const report = await dispatchOutbox(deps, deps.deliver, { deadlineMs: 20_000 });
    context.log?.(JSON.stringify(report));
    return context.res.json({ worker: 'learning', at: new Date().toISOString(), report }, 200);
  }
  return router({ req, res: context.res });
}
