// P3-AUTH-002: initializeProfile / getMe / updateMe / deleteAccount (SRS FR-AUTH-001/005,
// FR-SET-001; DATA_MODEL "Profile initialization writes ..."). Subject comes only from the
// verified JWT; no caller-supplied user ID is consulted.
import { randomUUID } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import { isValidZone, nextUtcMidnight, zonedDay } from '../domain/time.js';
import {
  DEFAULT_ZONE,
  INITIAL_GEMS,
  ZONE_EPOCH,
  achievementIds,
  editable,
  emptyRewards,
  ids,
  isDeleted,
  operationId,
  profileView,
  promoteZone,
  putOutbox,
  requireProfile,
} from './records.js';

export const ZONE_CHANGE_INTERVAL_MS = 24 * 60 * 60 * 1000;
export const DELETION_OWNERS = ['learning', 'ai'] as const;

export function generatedUsername(userId: string): string {
  return `user${operationId('username', userId).slice(0, 12)}`;
}

/** Idempotent: an existing profile is returned unchanged (no second INITIAL credit). */
export async function initializeProfile(tx: ProgressTx, userId: string) {
  if (await isDeleted(tx, userId)) throw new ServiceError('PROFILE_UNAVAILABLE');
  const profileId = ids.profile(userId);
  const existing = await tx.get('p_profiles', profileId);
  if (existing) {
    return profileView(promoteZone(existing, tx.nowIso), await achievementIds(tx, userId));
  }
  const username = generatedUsername(userId);
  const profile: Row = {
    userId,
    username,
    nickname: username,
    avatarId: null,
    avatarConfigJson: null,
    publicOptIn: false,
    ageBand: 'ADULT',
    emailVerifiedSnapshot: false,
    dailyGoal: 10,
    learningZone: DEFAULT_ZONE,
    pendingZone: null,
    zoneEffectiveAt: null,
    lastZoneChangedAt: ZONE_EPOCH,
    onboardingJson: null,
    deletedAt: null,
  };
  tx.put('p_profiles', profileId, profile);
  // Rewards may already exist when a completion event arrived before initialization.
  const rewardsId = ids.rewards(userId);
  const rewards = editable((await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId));
  rewards['gems'] = Number(rewards['gems']) + INITIAL_GEMS;
  tx.put('p_rewards', rewardsId, rewards);
  const initOp = operationId('initialize', userId);
  tx.put('p_reward_ledger', ids.ledger(userId, initOp, 'INITIAL'), {
    eventId: initOp,
    completionId: initOp,
    userId,
    rewardIdentity: 'initialize',
    kind: 'INITIAL',
    studyXpDelta: 0,
    leagueXpDelta: 0,
    gemsDelta: INITIAL_GEMS,
    learningDay: zonedDay(tx.nowIso, DEFAULT_ZONE),
    leagueWeek: zonedDay(tx.nowIso, DEFAULT_ZONE),
    occurredAt: tx.nowIso,
    capped: false,
  });
  if (!(await tx.get('p_zone_history', ids.zone(userId, ZONE_EPOCH)))) {
    tx.put('p_zone_history', ids.zone(userId, ZONE_EPOCH), {
      userId,
      zone: DEFAULT_ZONE,
      effectiveAt: ZONE_EPOCH,
    });
  }
  if (!(await tx.get('p_preferences', ids.preferences(userId)))) {
    tx.put('p_preferences', ids.preferences(userId), {
      userId,
      notificationsOffJson: '[]',
      smartScheduling: true,
      reminderMinute: 1200,
      soundEffects: true,
      haptics: true,
      motivationalMessages: true,
      listeningExercises: true,
      speakingExercises: true,
      friendStreakInvites: true,
    });
  }
  if (!(await tx.get('p_league_profiles', ids.leagueProfile(userId)))) {
    tx.put('p_league_profiles', ids.leagueProfile(userId), {
      userId,
      tier: 0,
      stage: 'LEAGUE',
      weeksParticipated: 0,
      topThreeFinishes: 0,
      diamondWeeks: 0,
      lastSettledWeekId: null,
      lastResultJson: null,
      resultSeenWeekId: null,
    });
  }
  if (!(await tx.get('p_entitlements', ids.entitlement(userId)))) {
    tx.put('p_entitlements', ids.entitlement(userId), {
      userId,
      plan: 'FREE',
      source: 'NONE',
      status: 'ACTIVE',
      expiresAt: null,
      autoRenew: false,
      familyGroupId: null,
      purchaseId: null,
      giftId: null,
    });
  }
  return profileView({ ...profile, revision: 0 }, await achievementIds(tx, userId));
}

export async function getMe(tx: ProgressTx, userId: string) {
  const profile = await requireProfile(tx, userId);
  return profileView(profile, await achievementIds(tx, userId));
}

export interface ProfilePatch {
  nickname?: string;
  avatarId?: string | null;
  publicOptIn?: boolean;
  dailyGoal?: 5 | 10 | 15 | 20;
  learningZone?: string;
  expectedRevision: number;
}

export async function updateMe(tx: ProgressTx, userId: string, patch: ProfilePatch) {
  const stored = await requireProfile(tx, userId);
  const current = Number(stored['revision'] ?? 0);
  if (patch.expectedRevision !== current) {
    throw new ServiceError('REVISION_CONFLICT', { details: { currentRevision: current } });
  }
  const next = editable(stored);
  if (patch.nickname !== undefined) {
    const nickname = patch.nickname.normalize('NFC').trim().replace(/\s+/g, ' ');
    if (!nickname || nickname.length > 40) {
      throw new ServiceError('VALIDATION_ERROR', { details: { field: 'nickname' } });
    }
    next['nickname'] = nickname;
  }
  if (patch.avatarId !== undefined) next['avatarId'] = patch.avatarId;
  if (patch.dailyGoal !== undefined) next['dailyGoal'] = patch.dailyGoal;
  if (patch.publicOptIn !== undefined) {
    if (patch.publicOptIn && stored['ageBand'] === 'CHILD') {
      throw new ServiceError('FORBIDDEN', { details: { field: 'publicOptIn' } });
    }
    next['publicOptIn'] = patch.publicOptIn;
  }
  if (patch.learningZone !== undefined && patch.learningZone !== stored['learningZone']) {
    if (!isValidZone(patch.learningZone)) throw new ServiceError('INVALID_TIMEZONE');
    const last = Date.parse(String(stored['lastZoneChangedAt'] ?? ZONE_EPOCH));
    const wait = last + ZONE_CHANGE_INTERVAL_MS - tx.nowMs;
    if (wait > 0) {
      throw new ServiceError('RATE_LIMITED', {
        details: { field: 'learningZone' },
        retryAfterSeconds: Math.ceil(wait / 1000),
      });
    }
    // Effective at the next UTC midnight; the immutable history row decides event days.
    const effectiveAt = nextUtcMidnight(tx.nowMs);
    next['pendingZone'] = patch.learningZone;
    next['zoneEffectiveAt'] = effectiveAt;
    next['lastZoneChangedAt'] = tx.nowIso;
    const historyId = ids.zone(userId, effectiveAt);
    const prior = await tx.get('p_zone_history', historyId);
    if (prior) {
      throw new ServiceError('RATE_LIMITED', { details: { field: 'learningZone' } });
    }
    tx.put('p_zone_history', historyId, { userId, zone: patch.learningZone, effectiveAt });
  }
  tx.put('p_profiles', ids.profile(userId), next);
  return profileView({ ...next, revision: current + 1 }, await achievementIds(tx, userId));
}

/** FR-AUTH-005: tombstone + account.deleted.v1 outbox in one transaction; idempotent. */
export async function requestDeletion(tx: ProgressTx, userId: string) {
  const deletionId = ids.deletion(userId);
  const existing = await tx.get('p_deletions', deletionId);
  if (existing) {
    return {
      requestId: String(existing['requestId']),
      status: String(existing['status']) as 'REQUESTED' | 'REVOKED' | 'PURGING' | 'COMPLETED',
      requestedAt: String(existing['requestedAt']),
    };
  }
  const requestId = randomUUID();
  tx.put('p_deletions', deletionId, {
    userId,
    requestId,
    status: 'REQUESTED',
    ownerAcksJson: '[]',
    requestedAt: tx.nowIso,
    completedAt: null,
  });
  const profile = await tx.get('p_profiles', ids.profile(userId));
  if (profile) {
    tx.put('p_profiles', ids.profile(userId), {
      ...editable(profile),
      publicOptIn: false,
      deletedAt: tx.nowIso,
    });
  }
  putOutbox(tx, 'account.deleted.v1', userId, { userId, requestId }, randomUUID());
  return { requestId, status: 'REQUESTED' as const, requestedAt: tx.nowIso };
}
