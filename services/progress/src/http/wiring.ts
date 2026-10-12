// Progress HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Business routes are the docs/api/openapi.yaml operations tagged progress (./routes.ts);
// withRequestScope (./scope.ts) supplies path parameters and the Idempotency-Key.
// Scheduler ticks (/internal/jobs/*) are signed by the 'scheduler' (or maintainer) key.
import { jobRoute } from '../../../shared/src/job-tick.js';
import type { FunctionContext, Route, ServiceWiring } from '../../../shared/src/transport.js';
import { createProgressEventConsumer } from '../application/consume-events.js';
import {
  runDeletionPurge,
  runLeagueSettlement,
  runProgressOutboxRelay,
  runStreakRollover,
} from '../application/jobs.js';
import type { WatermarkSource } from '../application/leagues.js';
import type { RelayDeliver } from '../application/outbox-relay.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { extendedRoutes } from './routes-extended.js';
import { PROGRESS_ROUTE_TEMPLATES, progressRoutes } from './routes.js';
import { withRequestScope } from './scope.js';

export interface ProgressJobPorts {
  /** Signed delivery to Learning/AI; absent -> the relay tick is SERVICE_NOT_CONFIGURED. */
  deliver?: RelayDeliver | undefined;
  /** Learning outbox watermark; absent -> settlement keeps cohorts SETTLING. */
  watermark?: WatermarkSource | undefined;
}

const NO_WATERMARK: WatermarkSource = {
  async pendingBefore() {
    throw new Error('WATERMARK_NOT_CONFIGURED');
  },
};

export function jobRoutes(store: ProgressPersistence, ports: ProgressJobPorts = {}): Route[] {
  const now = () => store.nowMs();
  return [
    jobRoute('/internal/jobs/streak-rollover', 'STREAK_ROLLOVER', now, (t) =>
      runStreakRollover(store, t),
    ),
    jobRoute('/internal/jobs/league-settlement', 'LEAGUE_SETTLEMENT', now, (t) =>
      runLeagueSettlement(store, ports.watermark ?? NO_WATERMARK, t),
    ),
    jobRoute('/internal/jobs/deletion-purge', 'DELETION_PURGE', now, (t) =>
      runDeletionPurge(store, t),
    ),
    jobRoute('/internal/jobs/progress-outbox-relay', 'PROGRESS_OUTBOX_RELAY', now, (t) =>
      runProgressOutboxRelay(store, ports.deliver, t),
    ),
  ];
}

export function progressWiring(
  persistence: ProgressPersistence,
  ports: ProgressJobPorts = {},
): ServiceWiring {
  return {
    routes: [
      ...progressRoutes(persistence),
      ...extendedRoutes(persistence),
      ...jobRoutes(persistence, ports),
    ],
    eventConsumer: createProgressEventConsumer(persistence),
  };
}

/** Wrap the shared router so templated paths and idempotency keys reach the handlers. */
export function scopeProgressHandler(router: (context: FunctionContext) => Promise<unknown>) {
  return withRequestScope(router, PROGRESS_ROUTE_TEMPLATES);
}
