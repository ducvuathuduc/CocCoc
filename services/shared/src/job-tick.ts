// Signed scheduler ticks (OpenAPI JobTickRequest/JobRunReport, /internal/jobs/*). Transport-level
// parsing and the report envelope only; each owner implements the job itself. A tick is
// idempotent by construction: every job re-reads durable state, so a repeated or overlapping
// tick never applies an effect twice (leases, deterministic row IDs, CLOSED/COMPLETED states).
import { ServiceError } from './errors.js';
import type { Route, RouteContext, RouteResult } from './transport.js';

export type JobName =
  | 'STREAK_ROLLOVER'
  | 'LEAGUE_SETTLEMENT'
  | 'DELETION_PURGE'
  | 'PROGRESS_OUTBOX_RELAY'
  | 'LEARNING_OUTBOX_DISPATCH';

export interface JobTick {
  tickId: string;
  scheduledAt: string;
  limit: number | undefined;
  cursor: string | null;
  weekId: string | null;
}

export interface JobCounts {
  processed: number;
  succeeded: number;
  retried: number;
  dead: number;
  skipped: number;
  nextCursor: string | null;
  needsIntervention: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
const KEYS = ['tickId', 'scheduledAt', 'limit', 'cursor', 'weekId'];

function bad(field: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { field } });
}

export function parseJobTick(body: unknown): JobTick {
  if (!body || typeof body !== 'object' || Array.isArray(body)) bad('body');
  const value = body as Record<string, unknown>;
  for (const key of Object.keys(value)) if (!KEYS.includes(key)) bad(key);
  const { tickId, scheduledAt, limit, cursor, weekId } = value;
  if (typeof tickId !== 'string' || !UUID.test(tickId)) bad('tickId');
  if (
    typeof scheduledAt !== 'string' ||
    scheduledAt.length > 40 ||
    Number.isNaN(Date.parse(scheduledAt))
  ) {
    bad('scheduledAt');
  }
  if (
    limit !== undefined &&
    (!Number.isInteger(limit) || (limit as number) < 1 || (limit as number) > 500)
  ) {
    bad('limit');
  }
  if (
    cursor !== undefined &&
    cursor !== null &&
    (typeof cursor !== 'string' || cursor.length > 256)
  ) {
    bad('cursor');
  }
  if (
    weekId !== undefined &&
    weekId !== null &&
    (typeof weekId !== 'string' || !DAY.test(weekId) || Number.isNaN(Date.parse(weekId)))
  ) {
    bad('weekId');
  }
  return {
    tickId,
    scheduledAt,
    limit: limit as number | undefined,
    cursor: (cursor as string | null | undefined) ?? null,
    weekId: (weekId as string | null | undefined) ?? null,
  };
}

export function emptyCounts(): JobCounts {
  return {
    processed: 0,
    succeeded: 0,
    retried: 0,
    dead: 0,
    skipped: 0,
    nextCursor: null,
    needsIntervention: false,
  };
}

/** A signed POST /internal/jobs/<name> route accepting the scheduler (and maintainer) key. */
export function jobRoute(
  path: string,
  job: JobName,
  nowMs: () => number,
  run: (tick: JobTick, context: RouteContext) => Promise<JobCounts>,
): Route {
  return {
    method: 'POST',
    path,
    auth: 'service',
    allowedSenders: ['scheduler', 'maintainer'],
    async handle(context): Promise<RouteResult> {
      const tick = parseJobTick(context.body);
      const startedAt = new Date(nowMs()).toISOString();
      const counts = await run(tick, context);
      return {
        status: 200,
        body: {
          job,
          tickId: tick.tickId,
          startedAt,
          finishedAt: new Date(nowMs()).toISOString(),
          ...counts,
        },
      };
    },
  };
}
