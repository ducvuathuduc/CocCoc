import { createHostedHandler } from '../../shared/src/transport.js';
import { createDisabledLearningPersistence } from './persistence/disabled.js';
// Hosted artifact: disabled persistence until the durable Appwrite adapter passes its gate.
export default createHostedHandler('learning', createDisabledLearningPersistence());
