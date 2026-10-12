import { createHostedHandler } from '../../shared/src/transport.js';
import { createDisabledAiPersistence } from './persistence/disabled.js';
// Hosted artifact: disabled persistence until the durable Appwrite adapter passes its gate.
export default createHostedHandler('ai', createDisabledAiPersistence());
