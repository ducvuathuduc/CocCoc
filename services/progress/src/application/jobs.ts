// Progress scheduled jobs behind signed /internal/jobs/* ticks (OpenAPI runStreakRollover,
// runLeagueSettlement, runDeletionPurge, runProgressOutboxRelay). Every job re-reads durable state
// and reuses the idempotent domain steps (deterministic CONSUME ids, CLOSED league runs,
// COMPLETED tombstones, outbox leases), so a repeated or overlapping tick applies nothing twice.
import { ServiceError } from '../../../shared/src/errors.js';
import { emptyCounts, type JobCounts, type JobTick } from '../../../shared/src/job-tick.js';
import { addDays, leagueWeek } from '../domain/time.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { purgeDeletedAccount } from './deletion.js';
import { processMissedDays } from './economy.js';
import { settleLeagueWeek, type WatermarkSource } from './leagues.js';
import { relayOutbox, RELAY_MAX_BATCH, type RelayDeliver } from './outbox-relay.js';

export const STREAK_BATCH = 200;
export const PURGE_BATCH = 20;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
/** Outbox tick budget: well inside the 60s worker timeout and the 30s lease. */
export const RELAY_DEADLINE_MS = 20_000;

/**
 * Day rollover / missed-day freezes (P6-GAME-002). Candidates: a live streak whose last
 * qualified day is at least two UTC days old (every IANA zone's "yesterday" is then after it,
 * except a negative zone just before its midnight, which the step leaves untouched and the next
 * tick picks up). Oldest first; each user is one bounded transaction.
 */
export async function runStreakRollover(
  store: ProgressPersistence,
  tick: JobTick,
): Promise<JobCounts> {
  const counts = emptyCounts();
  const utcToday = new Date(store.nowMs()).toISOString().slice(0, 10);
  const rows = await store.list('p_rewards', {
    gte: { currentStreak: 1 },
    lt: { lastQualifiedDay: addDays(utcToday, -1) },
    orderBy: [['lastQualifiedDay', 'asc']],
    limit: Math.min(tick.limit ?? STREAK_BATCH, 500),
  });
  for (const { row } of rows) {
    const userId = String(row['userId']);
    counts.processed++;
    try {
      const result = await store.transact((tx) => processMissedDays(tx, userId));
      if (result.protectedDays.length || result.lostStreak !== null) counts.succeeded++;
      else counts.skipped++;
    } catch {
      counts.retried++; // left as is; the next tick retries the same user
    }
  }
  return counts;
}

/**
 * Weekly league settlement (P9-LEAGUE-001/002): the last ended week (or tick.weekId) plus every
 * week still SETTLING. Cohorts close only when Learning's outbox watermark is zero.
 */
export async function runLeagueSettlement(
  store: ProgressPersistence,
  watermark: WatermarkSource,
  tick: JobTick,
): Promise<JobCounts> {
  const counts = emptyCounts();
  const weeks = new Set<string>([tick.weekId ?? leagueWeek(store.nowMs() - WEEK_MS)]);
  if (!tick.weekId) {
    const settling = await store.list('p_league_runs', {
      where: { status: 'SETTLING' },
      limit: 500,
    });
    for (const { row } of settling) weeks.add(String(row['weekId']));
  }
  for (const weekId of [...weeks].sort()) {
    const report = await settleLeagueWeek(store, watermark, weekId);
    counts.processed += report.closed.length + report.settling.length;
    counts.succeeded += report.closed.length;
    counts.retried += report.settling.length;
    if (report.needsIntervention) counts.needsIntervention = true;
  }
  return counts;
}

/** Deletion purge retry (FR-AUTH-005): every tombstone whose owners all acknowledged. */
export async function runDeletionPurge(
  store: ProgressPersistence,
  tick: JobTick,
): Promise<JobCounts> {
  const counts = emptyCounts();
  const rows = await store.list('p_deletions', {
    where: { status: 'PURGING' },
    orderBy: [['requestedAt', 'asc']],
    limit: Math.min(tick.limit ?? PURGE_BATCH, 100),
  });
  for (const { row } of rows) {
    counts.processed++;
    try {
      if (await purgeDeletedAccount(store, String(row['userId']))) counts.succeeded++;
      else counts.retried++;
    } catch {
      counts.retried++;
    }
  }
  return counts;
}

/** Outbox relay tick: account.deleted.v1 / entitlement.changed.v1 / energy.granted.v1. */
export async function runProgressOutboxRelay(
  store: ProgressPersistence,
  deliver: RelayDeliver | undefined,
  tick: JobTick,
): Promise<JobCounts> {
  if (!deliver) throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { job: 'relay' } });
  const report = await relayOutbox(store, deliver, {
    limit: Math.min(tick.limit ?? RELAY_MAX_BATCH, RELAY_MAX_BATCH),
    deadlineMs: RELAY_DEADLINE_MS,
    owner: `tick-${tick.tickId.slice(0, 8)}-${Math.random().toString(36).slice(2, 10)}`,
  });
  return {
    ...emptyCounts(),
    processed: report.leased,
    succeeded: report.acked,
    retried: report.retried,
    dead: report.dead,
    skipped: report.leased - report.acked - report.retried - report.dead,
  };
}
