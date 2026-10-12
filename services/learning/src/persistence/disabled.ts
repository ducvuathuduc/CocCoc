import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { ServiceError } from '../../../shared/src/errors.js';
import { LEARNING_TABLES, type LearningPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledLearningPersistence(): LearningPersistence & {
  readonly kind: 'disabled';
  readonly admittedForHosting: false;
} {
  const closed = async (): Promise<never> => {
    throw new ServiceError('SERVICE_NOT_CONFIGURED');
  };
  const base = createDisabledOwnerStore('learning', LEARNING_TABLES);
  return {
    ...base,
    commitWithReceipt: closed,
    applyInboxEvent: closed,
    transact: closed,
    list: closed,
  };
}
