// P9-LEAGUE-001 (FR-SOCIAL-002): weekly cohorts of at most 30 per tier, deterministic ranking,
// settlement after the Learning outbox watermark proves no undelivered completion predates the
// cutoff. One cohort per transaction (<= 30 members + 30 league profiles + run row).
import { ServiceError } from '../../../shared/src/errors.js';
import type { ProgressPersistence, ProgressTx, Row } from '../persistence/port.js';
import { COHORT_SIZE, movementFor, nextTier, rankMembers } from '../domain/league.js';
import { leagueWeek, leagueWeekEnd } from '../domain/time.js';
import { editable, ids, operationId, requireProfile } from './records.js';

export const MAX_COHORTS_PER_TIER = 1000;
const MAX_SETTLE_DELAY_MS = 24 * 60 * 60 * 1000;

interface RunSnapshot {
  members: string[];
  ranks?: Array<{ userId: string; rank: number; eligibleXp: number; movement: string }>;
}

function snapshotOf(run: Readonly<Row> | null): RunSnapshot {
  if (!run) return { members: [] };
  try {
    const parsed = JSON.parse(String(run['snapshotJson'] ?? '{}')) as RunSnapshot;
    return { ...parsed, members: Array.isArray(parsed.members) ? parsed.members : [] };
  } catch {
    return { members: [] };
  }
}

export function cohortIdFor(weekId: string, tier: number, index: number): string {
  return operationId('cohort', weekId, String(tier), String(index));
}

async function leagueView(tx: ProgressTx, weekId: string, cohortId: string, tier: number) {
  const run = await tx.get('p_league_runs', ids.leagueRun(weekId, cohortId));
  const rows = await tx.list('p_league_members', {
    where: { weekId, cohortId },
    limit: COHORT_SIZE,
  });
  const ranked = rankMembers(
    rows
      .filter(({ row }) => !row['excluded'])
      .map(({ row }) => ({
        userId: String(row['userId']),
        eligibleXp: Number(row['eligibleXp'] ?? 0),
        lastXpAt: (row['lastXpAt'] as string | null) ?? null,
      })),
  );
  const members = [];
  for (const member of ranked) {
    const profile = await tx.get('p_profiles', ids.profile(member.userId));
    members.push({
      userId: member.userId,
      nickname: String(profile?.['nickname'] ?? 'Learner').slice(0, 40),
      eligibleXp: member.eligibleXp,
      rank: member.rank,
      lastXpAt: member.lastXpAt,
    });
  }
  return {
    weekId,
    cohortId,
    tier,
    status: (run?.['status'] as 'OPEN' | 'SETTLING' | 'CLOSED' | undefined) ?? 'OPEN',
    members,
    asOf: tx.nowIso,
    nextCursor: null,
  };
}

export async function getLeague(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const weekId = leagueWeek(tx.nowIso);
  const member = await tx.get('p_league_members', ids.leagueMember(weekId, userId));
  if (!member) throw new ServiceError('NOT_FOUND', { details: { reason: 'NOT_JOINED', weekId } });
  return leagueView(tx, weekId, String(member['cohortId']), Number(member['tier']));
}

/** Join the current week's first open cohort of the learner's tier; cohorts are immutable. */
export async function joinLeague(tx: ProgressTx, userId: string) {
  const profile = await requireProfile(tx, userId);
  if (!profile['publicOptIn'] || profile['ageBand'] === 'CHILD') {
    throw new ServiceError('FORBIDDEN', { details: { reason: 'PUBLIC_OPT_IN_REQUIRED' } });
  }
  const weekId = leagueWeek(tx.nowIso);
  const memberId = ids.leagueMember(weekId, userId);
  const existing = await tx.get('p_league_members', memberId);
  if (existing) {
    return leagueView(tx, weekId, String(existing['cohortId']), Number(existing['tier']));
  }
  const leagueProfile = await tx.get('p_league_profiles', ids.leagueProfile(userId));
  const tier = Number(leagueProfile?.['tier'] ?? 0);
  for (let index = 0; index < MAX_COHORTS_PER_TIER; index++) {
    const cohortId = cohortIdFor(weekId, tier, index);
    const runId = ids.leagueRun(weekId, cohortId);
    const run = await tx.get('p_league_runs', runId);
    const snapshot = snapshotOf(run);
    if (run && (run['status'] !== 'OPEN' || snapshot.members.length >= COHORT_SIZE)) continue;
    // Rewriting the run row makes concurrent joins of one cohort conflict and retry, so the
    // member list (and the 30 cap) is never lost.
    tx.put('p_league_runs', runId, {
      ...(run ? editable(run) : {}),
      weekId,
      cohortId,
      tier,
      stage: 'LEAGUE',
      status: 'OPEN',
      watermarkAt: null,
      checkpointUserId: null,
      closedAt: null,
      snapshotJson: JSON.stringify({ members: [...snapshot.members, userId] }),
    });
    tx.put('p_league_members', memberId, {
      weekId,
      cohortId,
      userId,
      tier,
      stage: 'LEAGUE',
      eligibleXp: 0,
      lastXpAt: null,
      rank: null,
      excluded: false,
      settled: false,
    });
    const view = await leagueView(tx, weekId, cohortId, tier);
    return view;
  }
  throw new ServiceError('RATE_LIMITED', { details: { reason: 'NO_OPEN_COHORT' } });
}

export interface WatermarkSource {
  /** Learning /internal/outbox-watermark: undelivered events occurring before the cutoff. */
  pendingBefore(cutoffIso: string): Promise<number>;
}

export interface SettlementReport {
  weekId: string;
  closed: string[];
  settling: string[];
  needsIntervention: boolean;
}

/**
 * Close every OPEN/SETTLING cohort of an ended week exactly once. Without a zero watermark the
 * runs move to SETTLING (never a knowingly incomplete rank); after 24h they stay SETTLING and
 * the report flags manual intervention. Top 5 promote / bottom 5 demote for cohorts >= 10.
 */
export async function settleLeagueWeek(
  store: ProgressPersistence,
  watermark: WatermarkSource,
  weekId: string,
): Promise<SettlementReport> {
  const cutoff = leagueWeekEnd(weekId);
  const report: SettlementReport = { weekId, closed: [], settling: [], needsIntervention: false };
  if (store.nowMs() < Date.parse(cutoff)) {
    throw new ServiceError('VALIDATION_ERROR', { details: { reason: 'WEEK_NOT_ENDED', weekId } });
  }
  const runs = (await store.list('p_league_runs', { where: { weekId }, limit: 500 })).filter(
    ({ row }) => row['status'] !== 'CLOSED',
  );
  let pending: number;
  try {
    pending = await watermark.pendingBefore(cutoff);
  } catch {
    pending = Number.POSITIVE_INFINITY;
  }
  for (const { row } of runs) {
    const cohortId = String(row['cohortId']);
    if (pending !== 0) {
      await store.transact(async (tx) => {
        const run = await tx.get('p_league_runs', ids.leagueRun(weekId, cohortId));
        if (run && run['status'] === 'OPEN') {
          tx.put('p_league_runs', ids.leagueRun(weekId, cohortId), {
            ...editable(run),
            status: 'SETTLING',
          });
        }
      });
      report.settling.push(cohortId);
      if (store.nowMs() - Date.parse(cutoff) > MAX_SETTLE_DELAY_MS) report.needsIntervention = true;
      continue;
    }
    await store.transact(async (tx) => {
      const runId = ids.leagueRun(weekId, cohortId);
      const run = await tx.get('p_league_runs', runId);
      if (!run || run['status'] === 'CLOSED') return;
      const tier = Number(run['tier']);
      const memberRows = await tx.list('p_league_members', {
        where: { weekId, cohortId },
        limit: COHORT_SIZE,
      });
      const eligible = memberRows.filter(({ row: member }) => !member['excluded']);
      const ranked = rankMembers(
        eligible.map(({ id, row: member }) => ({
          id,
          row: member,
          userId: String(member['userId']),
          eligibleXp: Number(member['eligibleXp'] ?? 0),
          lastXpAt: (member['lastXpAt'] as string | null) ?? null,
        })),
      );
      const ranks: NonNullable<RunSnapshot['ranks']> = [];
      for (const member of ranked) {
        const movement = movementFor(member.rank, ranked.length, tier);
        ranks.push({
          userId: member.userId,
          rank: member.rank,
          eligibleXp: member.eligibleXp,
          movement,
        });
        const current = await tx.get('p_league_members', member.id);
        if (current) {
          tx.put('p_league_members', member.id, {
            ...editable(current),
            rank: member.rank,
            settled: true,
          });
        }
        const profileId = ids.leagueProfile(member.userId);
        const leagueProfile = await tx.get('p_league_profiles', profileId);
        if (leagueProfile && leagueProfile['lastSettledWeekId'] !== weekId) {
          const newTier = nextTier(tier, movement);
          tx.put('p_league_profiles', profileId, {
            ...editable(leagueProfile),
            tier: newTier,
            weeksParticipated: Number(leagueProfile['weeksParticipated'] ?? 0) + 1,
            topThreeFinishes:
              Number(leagueProfile['topThreeFinishes'] ?? 0) + (member.rank <= 3 ? 1 : 0),
            diamondWeeks: Number(leagueProfile['diamondWeeks'] ?? 0) + (tier === 9 ? 1 : 0),
            lastSettledWeekId: weekId,
            lastResultJson: JSON.stringify({
              weekId,
              previousTier: tier,
              tier: newTier,
              rank: member.rank,
              movement,
            }),
          });
        }
      }
      tx.put('p_league_runs', runId, {
        ...editable(run),
        status: 'CLOSED',
        watermarkAt: tx.nowIso,
        closedAt: tx.nowIso,
        checkpointUserId: ranked[ranked.length - 1]?.userId ?? null,
        snapshotJson: JSON.stringify({ members: snapshotOf(run).members, ranks }),
      });
    });
    report.closed.push(cohortId);
  }
  return report;
}
