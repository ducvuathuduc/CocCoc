// Test-only bundle entry for services/ai/test (never bundled into dist/).
export * from '../../../shared/src/errors.js';
export * from '../../../shared/src/transport.js';
export * from '../../../shared/src/service-hmac.js';
export { createMemoryAiPersistence } from '../persistence/memory.js';
export { createAppwriteAiPersistence } from '../persistence/appwrite.js';
export { aiHandler, aiWiring, aiRoutes } from '../http/wiring.js';
export { SCRIPTED_PROVIDER, speechProvider, uuidFrom } from '../application/deps.js';
export {
  createSpeechEngine,
  parseAzure,
  speechFromEnv,
  SPEECH_GLOBAL_USER,
} from '../application/speech.js';
export { DEFAULT_GATES, gatesFromEnv, effectivePlan } from '../domain/plans.js';
export { SCENARIOS, scenarioById, onTopic, usedTargetWords } from '../domain/scenarios.js';
export { scoreConversation } from '../domain/scoring.js';
export { dispatchOutbox, outcomeForStatus, createImmediateRelay } from '../application/outbox.js';
export { createAiEventConsumer, PURGE_BATCH } from '../application/events.js';
export { validateWav } from '../application/audio.js';
export { ids } from '../persistence/ids.js';
