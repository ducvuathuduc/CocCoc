// Learning inbox consumer (EVENTS_ERRORS, CONSISTENCY): Progress -> Learning events.
// energy.granted.v1 refills/adds energy; entitlement.changed.v1 projects the paid plan onto
// l_energy (newest revision wins). The l_inbox row and the effect commit together; a duplicate
// replays and a changed payload under the same eventId is IDEMPOTENCY_CONFLICT.
// account.deleted.v1 stays SERVICE_NOT_CONFIGURED (503, the relay retries) until the Learning
// purge task ships; it is never acknowledged without its effect.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import type { LearningDeps } from './deps.js';
import {
  applyEnergyGrant,
  applyEntitlement,
  type EnergyGrant,
  type EntitlementProjection,
} from './energy.js';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const REASONS = ['SHOP', 'CHEST', 'FRIEND', 'QUEST', 'AD', 'PROMO'];
const PLANS = ['FREE', 'SUPER', 'MAX'];
const STATUSES = ['ACTIVE', 'GRACE', 'HOLD', 'CANCELED', 'EXPIRED', 'REVOKED'];

function invalid(reason: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
}

function exactKeys(payload: Record<string, unknown>, keys: readonly string[]): void {
  const actual = Object.keys(payload);
  if (actual.length !== keys.length || actual.some((key) => !keys.includes(key))) {
    invalid('PAYLOAD_FIELDS');
  }
}

export function parseEnergyGrant(event: BusinessEvent): EnergyGrant {
  const p = event.payload as unknown as Record<string, unknown>;
  exactKeys(p, ['operationId', 'userId', 'amount', 'refillToCapacity', 'reason']);
  if (typeof p['operationId'] !== 'string' || !ID.test(p['operationId'])) invalid('operationId');
  if (typeof p['userId'] !== 'string' || !ID.test(p['userId'])) invalid('userId');
  if (p['userId'] !== event.aggregateId) invalid('aggregateId');
  const amount = p['amount'];
  if (
    amount !== null &&
    (!Number.isInteger(amount) || (amount as number) < 1 || (amount as number) > 100)
  ) {
    invalid('amount');
  }
  if (typeof p['refillToCapacity'] !== 'boolean' || p['refillToCapacity'] !== (amount === null)) {
    invalid('refillToCapacity');
  }
  if (typeof p['reason'] !== 'string' || !REASONS.includes(p['reason'])) invalid('reason');
  return {
    operationId: p['operationId'],
    userId: p['userId'],
    amount: amount as number | null,
    refillToCapacity: p['refillToCapacity'],
    reason: p['reason'],
  };
}

export function parseEntitlement(event: BusinessEvent): EntitlementProjection {
  const p = event.payload as unknown as Record<string, unknown>;
  exactKeys(p, ['userId', 'plan', 'status', 'expiresAt', 'entitlementRevision']);
  if (typeof p['userId'] !== 'string' || !ID.test(p['userId'])) invalid('userId');
  if (p['userId'] !== event.aggregateId) invalid('aggregateId');
  if (typeof p['plan'] !== 'string' || !PLANS.includes(p['plan'])) invalid('plan');
  if (typeof p['status'] !== 'string' || !STATUSES.includes(p['status'])) invalid('status');
  const expiresAt = p['expiresAt'];
  if (
    expiresAt !== null &&
    (typeof expiresAt !== 'string' || Number.isNaN(Date.parse(expiresAt)))
  ) {
    invalid('expiresAt');
  }
  const revision = p['entitlementRevision'];
  if (
    !Number.isInteger(revision) ||
    (revision as number) < 0 ||
    (revision as number) > 2147483647
  ) {
    invalid('entitlementRevision');
  }
  return {
    userId: p['userId'],
    plan: p['plan'],
    status: p['status'],
    expiresAt: expiresAt as string | null,
    entitlementRevision: revision as number,
  };
}

export function createLearningEventConsumer(deps: LearningDeps): EventConsumer {
  return {
    async consume(event, context) {
      const entry = { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash };
      if (event.type === 'energy.granted.v1') {
        const grant = parseEnergyGrant(event);
        return deps.persistence.applyInboxEvent(entry, (tx) => applyEnergyGrant(deps, tx, grant));
      }
      if (event.type === 'entitlement.changed.v1') {
        const change = parseEntitlement(event);
        return deps.persistence.applyInboxEvent(entry, (tx) => applyEntitlement(deps, tx, change));
      }
      throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { type: event.type } });
    },
  };
}
