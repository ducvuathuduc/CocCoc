// Signed HTTP delivery of Learning outbox events to Progress /internal/events (HMAC, EVENTS_ERRORS).
import { createInternalClient } from '../../../shared/src/internal-client.js';
import type { ServiceKey } from '../../../shared/src/service-hmac.js';
import type { EventRelay, LearningDeps } from './deps.js';
import { dispatchOutbox, outcomeForStatus, type Deliver } from './outbox.js';

export function httpDeliver(options: {
  key: ServiceKey;
  progressBaseUrl: string;
  fetchImpl?: typeof fetch;
}): Deliver {
  const client = createInternalClient({
    key: options.key,
    baseUrl: options.progressBaseUrl,
    ...(options.fetchImpl ? { fetchImpl: options.fetchImpl } : {}),
  });
  return async (event) => {
    const response = await client.deliverEvent(event);
    const code = (response.body as { error?: { code?: string } } | null)?.error?.code;
    return outcomeForStatus(response.status, code);
  };
}

/** Immediately try to deliver just-committed events, bounded so the user response is not held long. */
export function createImmediateRelay(
  getDeps: () => LearningDeps,
  deliver: Deliver,
  deadlineMs = 1500,
): EventRelay {
  return {
    async afterCommit(eventIds) {
      await dispatchOutbox(getDeps(), deliver, {
        eventIds,
        deadlineMs,
        owner: `relay-${getDeps().newId()}`,
      });
    },
  };
}
