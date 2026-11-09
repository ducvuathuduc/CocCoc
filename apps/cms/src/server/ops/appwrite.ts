import { Client, Query, TablesDB, Users } from 'node-appwrite';
import type { Models } from 'node-appwrite';
import { statusOf, withTransientRetry } from '../store/retry';
import { APP_TABLE, type AppTableName, type LearnerDirectory, type LearnerSummary, type EntitlementCount, type EntitlementRow, type OpenCounts, type ProfileRow } from './port';

type AnyRow = Models.Row & Record<string, unknown>;

const ACCOUNTS_PAGE = 50;

/** The six values `p_entitlements.status` allows; one count each is six cheap indexed queries. */
const ENTITLEMENT_STATUSES = ['ACTIVE', 'GRACE', 'HOLD', 'CANCELED', 'EXPIRED', 'REVOKED'] as const;

const toSummary = (user: Models.User<Models.Preferences>): LearnerSummary => ({
  userId: user.$id,
  email: user.email,
  name: user.name,
  locked: !user.status,
  anonymous: !user.email,
  createdAt: user.$createdAt,
});

/** Newest first, decided here so every screen lists accounts in one order without re-sorting. */
const byNewest = (a: { createdAt: string }, b: { createdAt: string }): number =>
  b.createdAt.localeCompare(a.createdAt);

/**
 * Reads the app's own tables with the same project key the content store uses, and writes only
 * Appwrite Auth. A learner's row is never found by `$id` — nobody knows it — so every read goes through
 * the indexed column declared in `appwrite/schema/foundation.json`; an unindexed filter is a 400 that
 * only a live project ever reports.
 */
export class AppwriteLearnerDirectory implements LearnerDirectory {
  private readonly rows: TablesDB;
  private readonly people: Users;
  private readonly databaseId: string;

  constructor(endpoint: string, projectId: string, apiKey: string, databaseId: string) {
    const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
    this.rows = new TablesDB(client);
    this.people = new Users(client);
    this.databaseId = databaseId;
  }

  async listAccounts(search: string): Promise<LearnerSummary[]> {
    const term = search.trim();
    // An empty term must not become the param at all: Appwrite answers 400 to `search=""`, which would
    // leave the plain account list — the first thing an operator sees — unable to load.
    const list = await withTransientRetry(() =>
      this.people.list({
        ...(term ? { search: term.slice(0, 256) } : {}),
        queries: [Query.limit(ACCOUNTS_PAGE)],
      }),
    );
    return list.users.map(toSummary).sort(byNewest);
  }

  async getAccount(userId: string): Promise<LearnerSummary | null> {
    try {
      return toSummary(await withTransientRetry(() => this.people.get({ userId })));
    } catch (error) {
      if (statusOf(error) === 404) return null;
      throw error;
    }
  }

  /**
   * The one write this directory performs: disabling or re-enabling the account itself. The app reads
   * that status when a person signs in, so no row in `l_*`/`p_*` has to change to stop access.
   */
  async setAccess(userId: string, locked: boolean): Promise<void> {
    await withTransientRetry(() => this.people.updateStatus({ userId, status: !locked }));
  }

  async firstRow<T>(table: AppTableName, userId: string): Promise<T | null> {
    const rows = await this.list<T>(table, [Query.equal('userId', [userId]), Query.limit(1)]);
    return rows[0] ?? null;
  }

  async userRows<T>(table: AppTableName, userId: string, newestBy: string, limit: number): Promise<T[]> {
    return this.list<T>(table, [
      Query.equal('userId', [userId]),
      Query.orderDesc(newestBy),
      Query.limit(limit),
    ]);
  }

  async openRows<T>(table: AppTableName, limit: number): Promise<T[]> {
    return this.list<T>(table, [
      Query.equal('status', ['OPEN']),
      Query.orderDesc('createdAt'),
      Query.limit(limit),
    ]);
  }

  async countAccounts(): Promise<number> {
    const list = await withTransientRetry(() =>
      this.people.list({ queries: [Query.limit(1)] }),
    );
    return list.total;
  }

  async entitlementCounts(): Promise<EntitlementCount[]> {
    return Promise.all(
      ENTITLEMENT_STATUSES.map(async (status) => ({
        status,
        count: await this.count('entitlements', [Query.equal('status', [status])]),
      })),
    );
  }

  async entitlements(limit: number): Promise<EntitlementRow[]> {
    // No filter and no order: `p_entitlements` has no index on `plan`, and inventing one here would be
    // the unindexed query this module exists to avoid.
    return this.list<EntitlementRow>('entitlements', [Query.limit(limit)]);
  }

  async activeEntitlements(limit: number): Promise<EntitlementRow[]> {
    return this.list<EntitlementRow>('entitlements', [
      Query.equal('status', ['ACTIVE']),
      Query.limit(limit),
    ]);
  }

  async profiles(limit: number): Promise<ProfileRow[]> {
    return this.list<ProfileRow>('profiles', [Query.limit(limit)]);
  }

  async openCounts(): Promise<OpenCounts> {
    const [feedback, userReports, contentReports] = await Promise.all([
      this.count('feedback', [Query.equal('status', ['OPEN'])]),
      this.count('userReports', [Query.equal('status', ['OPEN'])]),
      this.count('contentReports', [Query.equal('status', ['OPEN'])]),
    ]);
    return { feedback, userReports, contentReports };
  }

  /** Appwrite returns `total` alongside the page; asking for one row is the cheapest honest count. */
  private async count(table: AppTableName, filters: string[]): Promise<number> {
    const result = await withTransientRetry(() =>
      this.rows.listRows<AnyRow>({
        databaseId: this.databaseId,
        tableId: APP_TABLE[table],
        queries: [...filters, Query.limit(1)],
      }),
    );
    return result.total;
  }

  private async list<T>(table: AppTableName, queries: string[]): Promise<T[]> {
    const result = await withTransientRetry(() =>
      this.rows.listRows<AnyRow>({
        databaseId: this.databaseId,
        tableId: APP_TABLE[table],
        queries,
      }),
    );
    return result.rows as T[];
  }
}
