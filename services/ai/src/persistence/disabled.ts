import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { AI_TABLES, type AiPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledAiPersistence(): AiPersistence {
  return createDisabledOwnerStore('ai', AI_TABLES);
}
