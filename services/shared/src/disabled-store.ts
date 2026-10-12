// Fail-closed persistence used by hosted entrypoints until a durable adapter is admitted.
import { ServiceError } from './errors.js';
import type { OwnerStore, ServiceName } from './ports.js';

export function createDisabledOwnerStore<S extends ServiceName, T extends string>(
  service: S,
  ownedTables: readonly T[],
): OwnerStore<S, T> & { readonly kind: 'disabled'; readonly admittedForHosting: false } {
  const closed = async (): Promise<never> => {
    throw new ServiceError('SERVICE_NOT_CONFIGURED');
  };
  return {
    service,
    kind: 'disabled',
    admittedForHosting: false,
    ownedTables,
    ping: async () => {
      throw new ServiceError('DB_UNAVAILABLE');
    },
    commitWithReceipt: closed,
    applyInboxEvent: closed,
    read: closed,
  };
}
