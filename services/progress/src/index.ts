import { createHostedHandler } from '../../shared/src/transport.js';
import { setCodeSecret } from './application/commerce.js';
import { progressWiring, scopeProgressHandler } from './http/wiring.js';
import { createAppwriteProgressPersistence } from './persistence/appwrite.js';
import { createDisabledProgressPersistence } from './persistence/disabled.js';
import type { ProgressPersistence } from './persistence/port.js';

// Hosted artifact. Persistence stays disabled (fail closed) unless the deployment explicitly
// opts into the durable Appwrite TablesDB adapter after the live gate
// (COC_PROGRESS_PERSISTENCE=appwrite plus endpoint/project and a Progress-scoped server key).
function hostedPersistence(env: Record<string, string | undefined>): ProgressPersistence {
  const endpoint = env['APPWRITE_FUNCTION_API_ENDPOINT'];
  const projectId = env['APPWRITE_FUNCTION_PROJECT_ID'];
  const apiKey = env['COC_PROGRESS_APPWRITE_KEY'];
  if (
    env['COC_PROGRESS_PERSISTENCE'] === 'appwrite' &&
    endpoint?.startsWith('https://') &&
    projectId &&
    apiKey
  ) {
    return createAppwriteProgressPersistence({ endpoint, projectId, apiKey, admitted: true });
  }
  return createDisabledProgressPersistence();
}

setCodeSecret(process.env['COC_PROGRESS_CODE_SECRET']);
const persistence = hostedPersistence(process.env);
export default scopeProgressHandler(
  createHostedHandler('progress', persistence, process.env, progressWiring(persistence)),
);
