import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { ServiceError } from '../../../shared/src/errors.js';
import { AI_TABLES, type AiPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledAiPersistence(): AiPersistence & {
  readonly kind: 'disabled';
  readonly admittedForHosting: false;
} {
  const closed = async (): Promise<never> => {
    throw new ServiceError('SERVICE_NOT_CONFIGURED');
  };
  const base = createDisabledOwnerStore('ai', AI_TABLES);
  return {
    ...base,
    commitWithReceipt: closed,
    applyInboxEvent: closed,
    transact: closed,
    list: closed,
  };
}
