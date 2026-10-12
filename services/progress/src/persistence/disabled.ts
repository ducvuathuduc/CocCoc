import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { PROGRESS_TABLES, type ProgressPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledProgressPersistence(): ProgressPersistence {
  return createDisabledOwnerStore('progress', PROGRESS_TABLES);
}
