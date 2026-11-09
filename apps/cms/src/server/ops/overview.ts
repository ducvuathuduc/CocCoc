import { cache } from 'react';
import { getDirectory, LEARNERS_UNAVAILABLE } from './learners';
import type {
  EntitlementCount,
  EntitlementRow,
  LearnerSummary,
  OpenCounts,
  ProfileRow,
} from './port';

/**
 * The numbers the overview shows.
 *
 * Every figure here is a count the project can answer with an indexed query — no scan of `p_day_activity`
 * by `day` (that column is only indexed behind `userId`), and no revenue: `p_purchases` stores no amount,
 * so a money figure would be invented. When the machine has no Appwrite pair the shape stays the same
 * with `connected: false`, so a screen can say "chưa nối" instead of printing a confident zero.
 */

/** The list read is capped: past this the screen says "at least", never a wrong total. */
export const DIRECTORY_SAMPLE = 500;

export interface PlanSlice {
  plan: 'SUPER' | 'MAX';
  count: number;
}

export interface LearnerOverview {
  connected: boolean;
  accounts: number;
  /** Accounts on a paid plan right now — SUPER or MAX with status ACTIVE. */
  paying: number;
  plans: PlanSlice[];
  /** ACTIVE + GRACE + HOLD … one row per status the schema allows. */
  statuses: EntitlementCount[];
  /** Accounts with no paid plan: total accounts minus `paying`. */
  free: number;
  /** True when the plan split read fewer rows than `paying`, so the split is a floor. */
  sampled: boolean;
  newest: LearnerSummary[];
}

const EMPTY: LearnerOverview = {
  connected: false,
  accounts: 0,
  paying: 0,
  plans: [
    { plan: 'SUPER', count: 0 },
    { plan: 'MAX', count: 0 },
  ],
  statuses: [],
  free: 0,
  sampled: false,
  newest: [],
};

function splitPlans(rows: EntitlementRow[]): PlanSlice[] {
  const counts = new Map<string, number>();
  for (const row of rows) counts.set(row.plan, (counts.get(row.plan) ?? 0) + 1);
  return [
    { plan: 'SUPER', count: counts.get('SUPER') ?? 0 },
    { plan: 'MAX', count: counts.get('MAX') ?? 0 },
  ];
}

export const learnerOverview = cache(async (): Promise<LearnerOverview> => {
  const directory = getDirectory();
  if (!directory) return EMPTY;
  try {
    const [accounts, statuses, active, newest] = await Promise.all([
      directory.countAccounts(),
      directory.entitlementCounts(),
      directory.activeEntitlements(DIRECTORY_SAMPLE),
      directory.listAccounts(''),
    ]);
    const plans = splitPlans(active);
    const paying = plans.reduce((sum, slice) => sum + slice.count, 0);
    return {
      connected: true,
      accounts,
      paying,
      plans,
      statuses,
      free: Math.max(accounts - paying, 0),
      sampled: paying > active.length,
      newest: newest.slice(0, 5),
    };
  } catch {
    // A dropped connection is not an empty project: the screen says so instead of showing zeros.
    return EMPTY;
  }
});

export const openQueue = cache(async (): Promise<OpenCounts | null> => {
  const directory = getDirectory();
  if (!directory) return null;
  try {
    return await directory.openCounts();
  } catch {
    return null;
  }
});

/** The one number a list screen needs before it renders: how many accounts exist. */
export const accountTotal = cache(async (): Promise<number | null> => {
  const directory = getDirectory();
  if (!directory) return null;
  try {
    return await directory.countAccounts();
  } catch {
    return null;
  }
});

export interface LearnerListRow extends LearnerSummary {
  /** Nickname from the app's profile row, falling back to the account name, then the email. */
  displayName: string;
  plan: string | null;
  planStatus: string | null;
}

/**
 * The account list with the two things a maintainer actually looks for — a human name and the plan —
 * resolved in two extra queries for the whole page instead of one query per row.
 */
export async function listLearnerRows(search: string): Promise<LearnerListRow[]> {
  const directory = getDirectory();
  if (!directory) throw new Error(LEARNERS_UNAVAILABLE);
  const accounts = await directory.listAccounts(search);
  const [profiles, entitlements] = await Promise.all([
    directory.profiles(DIRECTORY_SAMPLE),
    directory.entitlements(DIRECTORY_SAMPLE),
  ]);
  const names = new Map<string, ProfileRow>(profiles.map((row) => [row.userId, row]));
  const plans = new Map<string, EntitlementRow>(
    entitlements.map((row) => [row.userId, row]),
  );
  return accounts.map((account) => {
    const profile = names.get(account.userId);
    const entitlement = plans.get(account.userId);
    return {
      ...account,
      displayName:
        profile?.nickname?.trim() ||
        account.name?.trim() ||
        account.email ||
        account.userId,
      plan: entitlement?.plan ?? null,
      planStatus: entitlement?.status ?? null,
    };
  });
}

export interface PlanRow {
  userId: string;
  /** Nickname when the app stored one, otherwise "Chưa đặt tên" — never the raw id as a name. */
  name: string;
  plan: string;
  source: string;
  status: string;
  expiresAt: string | null;
}

/** The plan rows the billing screen lists, with the nickname resolved in one extra query. */
export async function planRows(limit = 200): Promise<PlanRow[]> {
  const directory = getDirectory();
  if (!directory) throw new Error(LEARNERS_UNAVAILABLE);
  const [entitlements, profiles] = await Promise.all([
    directory.activeEntitlements(limit),
    directory.profiles(DIRECTORY_SAMPLE),
  ]);
  const names = new Map(profiles.map((row) => [row.userId, row.nickname]));
  return entitlements.map((row) => ({
    userId: row.userId,
    name: names.get(row.userId)?.trim() || 'Chưa đặt tên',
    plan: row.plan,
    source: row.source,
    status: row.status,
    expiresAt: row.expiresAt,
  }));
}
