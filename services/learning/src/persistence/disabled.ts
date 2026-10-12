import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { LEARNING_TABLES, type LearningPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledLearningPersistence(): LearningPersistence {
  return createDisabledOwnerStore('learning', LEARNING_TABLES);
}
