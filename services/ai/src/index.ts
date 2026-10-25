// Hosted AI Function artifact (dist/function.mjs).
// Default: disabled persistence (fail closed). The durable Appwrite TablesDB adapter is selected
// only when COC_AI_PERSISTENCE=appwrite with an https endpoint and project; its credential is the
// per-execution dynamic key (`x-appwrite-key`, limited by the function scopes) first, then
// COC_AI_APPWRITE_KEY / APPWRITE_API_KEY. Business routes need COC_AI_ADMITTED=reviewed-cloud-gate.
// Provider: authored text scripts; COC_AI_PROVIDER=speech + secret provider keys
// (COC_AZURE_SPEECH_KEY/REGION, COC_ASSEMBLYAI_API_KEY, COC_DEEPGRAM_API_KEY) enables real STT and
// Azure pronunciation scores. Otherwise recorded speech is unavailable; hosted audio never
// receives a synthetic transcript. Scripted speech exists only in explicit dev/test adapters.
// Event relay: COC_PROGRESS_URL (https) + an 'ai' key in COC_SERVICE_KEYS.
import { randomUUID } from 'node:crypto';
import {
  currentExecutionKey,
  isScheduledExecution,
  plainRequest,
  withExecutionKey,
  type RawAppwriteContext,
} from '../../shared/src/appwrite-entry.js';
import { parseKeyring } from '../../shared/src/service-hmac.js';
import { createHostedHandler } from '../../shared/src/transport.js';
import { DISABLED_PROVIDER, speechProvider, type AiDeps } from './application/deps.js';
import { speechFromEnv } from './application/speech.js';
import { createImmediateRelay, dispatchOutbox, httpDeliver } from './application/outbox.js';
import { gatesFromEnv } from './domain/plans.js';
import { aiHandler, aiWiring } from './http/wiring.js';
import { appwriteConfigFromEnv, createAppwriteAiPersistence } from './persistence/appwrite.js';
import { createDisabledAiPersistence } from './persistence/disabled.js';
import type { AiPersistence } from './persistence/port.js';

const env = process.env;
const config = appwriteConfigFromEnv(env, currentExecutionKey);
const persistence: AiPersistence = config
  ? createAppwriteAiPersistence(config)
  : createDisabledAiPersistence();
const speech = speechFromEnv(env, persistence);
const deps: AiDeps = {
  persistence,
  nowMs: Date.now,
  newId: randomUUID,
  gates: gatesFromEnv(env),
  provider: speech ? speechProvider(speech) : DISABLED_PROVIDER,
};
let serviceKeys;
try {
  serviceKeys = parseKeyring(env['COC_SERVICE_KEYS']);
} catch {
  serviceKeys = undefined;
}
const ownKey = serviceKeys ? [...serviceKeys.values()].find((k) => k.sender === 'ai') : undefined;
const progressUrl = env['COC_PROGRESS_URL'];
if (ownKey && progressUrl?.startsWith('https://')) {
  deps.deliver = httpDeliver({ key: ownKey, progressBaseUrl: progressUrl });
  deps.relay = createImmediateRelay(() => deps, deps.deliver);
}

const router = aiHandler(createHostedHandler('ai', persistence, env, aiWiring(deps)));

// Appwrite cron (x-appwrite-trigger=schedule at `/`): drain due a_outbox rows. Takes no request
// input; rows are leased, so a spoofed or overlapping trigger cannot double-apply.
export default async function main(context: RawAppwriteContext): Promise<unknown> {
  const req = plainRequest(context.req);
  return withExecutionKey(req, async () => {
    if (isScheduledExecution(req)) {
      if (!persistence.admittedForHosting || !deps.deliver) {
        return context.res.json({ worker: 'ai', status: 'SERVICE_NOT_CONFIGURED' }, 503);
      }
      const report = await dispatchOutbox(deps, deps.deliver, { deadlineMs: 20_000 });
      context.log?.(JSON.stringify(report));
      return context.res.json({ worker: 'ai', at: new Date().toISOString(), report }, 200);
    }
    return router({ req, res: context.res });
  });
}
