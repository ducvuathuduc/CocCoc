import { createHostedHandler } from '../../shared/src/transport.js';
import { aiWiring } from './http/wiring.js';
import { createDisabledAiPersistence } from './persistence/disabled.js';
// Hosted artifact: disabled persistence until the durable Appwrite adapter passes its gate.
const persistence = createDisabledAiPersistence();
export default createHostedHandler('ai', persistence, process.env, aiWiring(persistence));
