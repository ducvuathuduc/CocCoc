import { createHostedHandler } from '../../shared/src/transport.js';
import { progressWiring } from './http/wiring.js';
import { createDisabledProgressPersistence } from './persistence/disabled.js';
// Hosted artifact: disabled persistence until the durable Appwrite adapter passes its gate.
const persistence = createDisabledProgressPersistence();
export default createHostedHandler(
  'progress',
  persistence,
  process.env,
  progressWiring(persistence),
);
