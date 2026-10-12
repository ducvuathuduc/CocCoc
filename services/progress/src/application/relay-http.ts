// Signed HTTP adapters for the Progress jobs: event delivery to Learning/AI /internal/events and
// the Learning outbox watermark read (EVENTS_ERRORS HMAC). A target without a configured https
// base URL answers 'retry', so its rows stay PENDING (then DEAD after 10 attempts) instead of
// being acknowledged for an owner that never saw them.
import { createInternalClient } from '../../../shared/src/internal-client.js';
import type { ServiceKey } from '../../../shared/src/service-hmac.js';
import type { WatermarkSource } from './leagues.js';
import { relayOutcomeForStatus, type RelayDeliver, type RelayTarget } from './outbox-relay.js';

export interface RelayHttpOptions {
  key: ServiceKey;
  targets: Partial<Record<RelayTarget, string>>;
  fetchImpl?: typeof fetch;
}

export function httpRelayDeliver(options: RelayHttpOptions): RelayDeliver {
  const clients = new Map<RelayTarget, ReturnType<typeof createInternalClient>>();
  for (const [target, baseUrl] of Object.entries(options.targets) as [RelayTarget, string][]) {
    if (!baseUrl) continue;
    clients.set(
      target,
      createInternalClient({
        key: options.key,
        baseUrl,
        ...(options.fetchImpl ? { fetchImpl: options.fetchImpl } : {}),
      }),
    );
  }
  return async (target, event) => {
    const client = clients.get(target);
    if (!client) return 'retry';
    const response = await client.deliverEvent(event);
    const code = (response.body as { error?: { code?: string } } | null)?.error?.code;
    return relayOutcomeForStatus(response.status, code);
  };
}

export function httpWatermark(options: {
  key: ServiceKey;
  learningBaseUrl: string | undefined;
  fetchImpl?: typeof fetch;
}): WatermarkSource {
  return {
    async pendingBefore(cutoffIso) {
      if (!options.learningBaseUrl) throw new Error('WATERMARK_NOT_CONFIGURED');
      const client = createInternalClient({
        key: options.key,
        baseUrl: options.learningBaseUrl,
        ...(options.fetchImpl ? { fetchImpl: options.fetchImpl } : {}),
      });
      const response = await client.get('/internal/outbox-watermark', { before: cutoffIso });
      const pending = (response.body as { pendingBefore?: unknown } | null)?.pendingBefore;
      if (response.status !== 200 || !Number.isInteger(pending)) {
        throw new Error('WATERMARK_UNAVAILABLE');
      }
      return pending as number;
    },
  };
}
