import { createDisabledOwnerStore } from '../../../shared/src/disabled-store.js';
import { ServiceError } from '../../../shared/src/errors.js';
import { PROGRESS_TABLES, type ProgressPersistence } from './port.js';

/** Hosted default: readiness and business routes fail closed until a durable adapter is admitted. */
export function createDisabledProgressPersistence(): ProgressPersistence & {
  readonly kind: 'disabled';
  readonly admittedForHosting: false;
} {
  const closed = async (): Promise<never> => {
    throw new ServiceError('SERVICE_NOT_CONFIGURED');
  };
  return {
    ...createDisabledOwnerStore('progress', PROGRESS_TABLES),
    commitWithReceipt: closed,
    applyInboxEvent: closed,
    transact: closed,
    list: closed,
    nowMs: () => Date.now(),
  };
}
