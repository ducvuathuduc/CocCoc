import { createHostedHandler } from '../../shared/src/transport.js';
import { learningWiring } from './http/wiring.js';
import { createDisabledLearningPersistence } from './persistence/disabled.js';
// Hosted artifact: disabled persistence until the durable Appwrite adapter passes its gate.
const persistence = createDisabledLearningPersistence();
export default createHostedHandler(
  'learning',
  persistence,
  process.env,
  learningWiring(persistence),
);
