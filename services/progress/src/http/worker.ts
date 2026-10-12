// Progress scheduled worker (Appwrite cron, x-appwrite-trigger=schedule at `/`). One function
// schedule (every minute) drives every Progress job; cadence is decided here from the server clock:
//   every minute    outbox relay (account.deleted / entitlement.changed / energy.granted)
//   every minute    deletion purge retry (PURGING tombstones)
//   minute 5 hourly streak day rollover (each zone's midnight falls in some UTC hour)
//   minute 15 hourly league settlement (last ended week + any SETTLING week; idempotent)
// The same jobs are reachable as signed /internal/jobs/* ticks (scheduler/maintainer key).
import { randomUUID } from 'node:crypto';
import type { JobCounts, JobTick } from '../../../shared/src/job-tick.js';
import {
  runDeletionPurge,
  runLeagueSettlement,
  runProgressOutboxRelay,
  runStreakRollover,
} from '../application/jobs.js';
import type { ProgressPersistence } from '../persistence/port.js';
import type { ProgressJobPorts } from './wiring.js';

export const STREAK_MINUTE = 5;
export const LEAGUE_MINUTE = 15;
const NO_WATERMARK = {
  async pendingBefore(): Promise<number> {
    throw new Error('WATERMARK_NOT_CONFIGURED');
  },
};

export async function runProgressWorker(
  store: ProgressPersistence,
  ports: ProgressJobPorts,
  nowMs: number,
): Promise<{
  worker: 'progress';
  at: string;
  jobs: Record<string, JobCounts | { error: string }>;
}> {
  const tick: JobTick = {
    tickId: randomUUID(),
    scheduledAt: new Date(nowMs).toISOString(),
    limit: undefined,
    cursor: null,
    weekId: null,
  };
  const minute = new Date(nowMs).getUTCMinutes();
  const plan: Array<[string, () => Promise<JobCounts>]> = [];
  if (ports.deliver)
    plan.push(['outboxRelay', () => runProgressOutboxRelay(store, ports.deliver, tick)]);
  plan.push(['deletionPurge', () => runDeletionPurge(store, tick)]);
  if (minute === STREAK_MINUTE) plan.push(['streakRollover', () => runStreakRollover(store, tick)]);
  if (minute === LEAGUE_MINUTE)
    plan.push([
      'leagueSettlement',
      () => runLeagueSettlement(store, ports.watermark ?? NO_WATERMARK, tick),
    ]);
  const jobs: Record<string, JobCounts | { error: string }> = {};
  for (const [name, job] of plan) {
    try {
      jobs[name] = await job();
    } catch (error) {
      // One failing job never blocks the others; the next minute retries it.
      jobs[name] = { error: (error as { code?: string }).code ?? 'JOB_FAILED' };
    }
  }
  return { worker: 'progress', at: tick.scheduledAt, jobs };
}
