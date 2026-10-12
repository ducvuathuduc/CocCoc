import {
  currentExecutionKey,
  isScheduledExecution,
  plainRequest,
  withExecutionKey,
  type RawAppwriteContext,
} from '../../shared/src/appwrite-entry.js';
import { parseKeyring } from '../../shared/src/service-hmac.js';
import { createHostedHandler } from '../../shared/src/transport.js';
import { setCodeSecret } from './application/commerce.js';
import { httpRelayDeliver, httpWatermark } from './application/relay-http.js';
import { runProgressWorker } from './http/worker.js';
import { progressWiring, scopeProgressHandler, type ProgressJobPorts } from './http/wiring.js';
import { createAppwriteProgressPersistence } from './persistence/appwrite.js';
import { createDisabledProgressPersistence } from './persistence/disabled.js';
import type { ProgressPersistence } from './persistence/port.js';

// Hosted artifact. Persistence stays disabled (fail closed) unless the deployment explicitly
// opts into the durable Appwrite TablesDB adapter (COC_PROGRESS_PERSISTENCE=appwrite plus
// endpoint/project). The Appwrite credential is the per-execution dynamic key (`x-appwrite-key`,
// limited by the function scopes), falling back to COC_PROGRESS_APPWRITE_KEY / APPWRITE_API_KEY.
function hostedPersistence(env: Record<string, string | undefined>): ProgressPersistence {
  const endpoint = env['APPWRITE_FUNCTION_API_ENDPOINT'] ?? env['APPWRITE_ENDPOINT'];
  const projectId = env['APPWRITE_FUNCTION_PROJECT_ID'] ?? env['APPWRITE_PROJECT_ID'];
  const fallbackKey = env['COC_PROGRESS_APPWRITE_KEY'] ?? env['APPWRITE_API_KEY'];
  if (
    env['COC_PROGRESS_PERSISTENCE'] === 'appwrite' &&
    endpoint?.startsWith('https://') &&
    projectId
  ) {
    return createAppwriteProgressPersistence({
      endpoint,
      projectId,
      apiKey: () => currentExecutionKey() ?? fallbackKey,
      databaseId: env['COC_DATABASE_ID'] ?? 'cocenglish',
      admitted: true,
    });
  }
  return createDisabledProgressPersistence();
}

// Scheduler job ports: the relay and the watermark read sign with Progress' own key from
// COC_SERVICE_KEYS and reach Learning/AI at COC_LEARNING_URL / COC_AI_URL (https only).
function jobPorts(env: Record<string, string | undefined>): ProgressJobPorts {
  let keyring;
  try {
    keyring = parseKeyring(env['COC_SERVICE_KEYS']);
  } catch {
    keyring = undefined;
  }
  const key = keyring ? [...keyring.values()].find((k) => k.sender === 'progress') : undefined;
  if (!key) return {};
  const https = (value: string | undefined) => (value?.startsWith('https://') ? value : undefined);
  const learning = https(env['COC_LEARNING_URL']);
  const ai = https(env['COC_AI_URL']);
  return {
    deliver: httpRelayDeliver({
      key,
      targets: { ...(learning ? { learning } : {}), ...(ai ? { ai } : {}) },
    }),
    watermark: httpWatermark({ key, learningBaseUrl: learning }),
  };
}

setCodeSecret(process.env['COC_PROGRESS_CODE_SECRET']);
const persistence = hostedPersistence(process.env);
const ports = jobPorts(process.env);
const router = scopeProgressHandler(
  createHostedHandler('progress', persistence, process.env, progressWiring(persistence, ports)),
);

export default async function main(context: RawAppwriteContext): Promise<unknown> {
  const req = plainRequest(context.req);
  return withExecutionKey(req, async () => {
    if (isScheduledExecution(req)) {
      if (persistence.kind === 'disabled') {
        return context.res.json({ worker: 'progress', status: 'SERVICE_NOT_CONFIGURED' }, 503);
      }
      const report = await runProgressWorker(persistence, ports, Date.now());
      context.log?.(JSON.stringify(report));
      return context.res.json(report, 200);
    }
    return router({ req, res: context.res });
  });
}
