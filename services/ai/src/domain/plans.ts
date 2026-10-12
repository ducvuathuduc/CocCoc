// Entitlement projection (entitlement.changed.v1 from Progress) and the AI feature gate.
// Progress decides plans from p_entitlements; AI keeps only the newest entitlement revision per
// user and never trusts a client plan claim (docs/data/PERMISSIONS.md).
//
// Storage: the a_ schema has no dedicated entitlement table, so the projection is one a_usage row
// per user (deterministic ID ids.entitlement(userId)) whose utcDay is the ENTITLEMENT_DAY sentinel
// and whose reservationIdsJson holds {plan,status,expiresAt,entitlementRevision}. Daily usage rows
// always carry a real YYYY-MM-DD day, so the sentinel never collides with them.
export const ENTITLEMENT_DAY = 'ENTITLED';

export type Plan = 'FREE' | 'SUPER' | 'MAX';
export const PLANS: readonly Plan[] = ['FREE', 'SUPER', 'MAX'];
export type EntitlementStatus = 'ACTIVE' | 'GRACE' | 'HOLD' | 'CANCELED' | 'EXPIRED' | 'REVOKED';
export const ENTITLEMENT_STATUSES: readonly EntitlementStatus[] = [
  'ACTIVE',
  'GRACE',
  'HOLD',
  'CANCELED',
  'EXPIRED',
  'REVOKED',
];

export interface EntitlementProjection {
  plan: Plan;
  status: EntitlementStatus;
  expiresAt: string | null;
  entitlementRevision: number;
}

const RANK: Record<Plan, number> = { FREE: 0, SUPER: 1, MAX: 2 };

/** The plan in force now: ACTIVE/GRACE and unexpired, otherwise FREE. */
export function effectivePlan(projection: EntitlementProjection | null, nowMs: number): Plan {
  if (!projection) return 'FREE';
  if (projection.status !== 'ACTIVE' && projection.status !== 'GRACE') return 'FREE';
  if (projection.expiresAt !== null && Date.parse(projection.expiresAt) <= nowMs) return 'FREE';
  return projection.plan;
}

export function planAllows(plan: Plan, minimum: Plan): boolean {
  return RANK[plan] >= RANK[minimum];
}

export type ConversationKind = 'ROLEPLAY' | 'VIDEO_CALL';

/** Minimum plan per AI feature (P8-AI-003: Roleplay/Video Call are Max features by default). */
export interface FeatureGates {
  ROLEPLAY: Plan;
  VIDEO_CALL: Plan;
}
export const DEFAULT_GATES: FeatureGates = { ROLEPLAY: 'MAX', VIDEO_CALL: 'MAX' };

/** COC_AI_ROLEPLAY_MIN_PLAN / COC_AI_VIDEO_CALL_MIN_PLAN override the defaults (allowlisted). */
export function gatesFromEnv(env: Record<string, string | undefined>): FeatureGates {
  const pick = (value: string | undefined, fallback: Plan): Plan =>
    (PLANS as readonly string[]).includes(value ?? '') ? (value as Plan) : fallback;
  return {
    ROLEPLAY: pick(env['COC_AI_ROLEPLAY_MIN_PLAN'], DEFAULT_GATES.ROLEPLAY),
    VIDEO_CALL: pick(env['COC_AI_VIDEO_CALL_MIN_PLAN'], DEFAULT_GATES.VIDEO_CALL),
  };
}

export function parseProjection(json: unknown): EntitlementProjection | null {
  try {
    const value = JSON.parse(String(json)) as Partial<EntitlementProjection>;
    if (
      !value ||
      !(PLANS as readonly string[]).includes(String(value.plan)) ||
      !(ENTITLEMENT_STATUSES as readonly string[]).includes(String(value.status)) ||
      !Number.isInteger(value.entitlementRevision)
    ) {
      return null;
    }
    return {
      plan: value.plan as Plan,
      status: value.status as EntitlementStatus,
      expiresAt: typeof value.expiresAt === 'string' ? value.expiresAt : null,
      entitlementRevision: value.entitlementRevision as number,
    };
  } catch {
    return null;
  }
}
