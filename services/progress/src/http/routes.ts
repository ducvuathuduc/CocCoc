import { getLearningStats } from '../application/learning-stats.js';
// Progress business routes: one per docs/api/openapi.yaml operation tagged progress.
// Every mutation requires a UUID Idempotency-Key and commits through p_receipts (same key +
// same body replays; changed body is IDEMPOTENCY_CONFLICT). Subject = verified JWT only.
import { ServiceError } from '../../../shared/src/errors.js';
import {
  canonicalBodyHash,
  type Route,
  type RouteContext,
  type RouteResult,
} from '../../../shared/src/transport.js';
import { buyFreeze, claimQuest, getRewards, listQuests } from '../application/economy.js';
import { getLeague, joinLeague } from '../application/leagues.js';
import {
  getMe,
  initializeProfile,
  requestDeletion,
  updateMe,
  type ProfilePatch,
} from '../application/profile.js';
import {
  decodeCursor,
  encodeCursor,
  followUser,
  getPublicProfile,
  listActivity,
  listFriends,
  optInFriendQuest,
  unfollowUser,
} from '../application/social.js';
import type { ProgressPersistence, ProgressTx } from '../persistence/port.js';
import { pathParam, requestScope, type RouteTemplate } from './scope.js';

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

export function bad(field: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { field } });
}

export function objectBody(
  body: unknown,
  allowed: readonly string[],
  required: readonly string[] = [],
): Record<string, unknown> {
  if (!body || typeof body !== 'object' || Array.isArray(body)) bad('body');
  const value = body as Record<string, unknown>;
  for (const key of Object.keys(value)) if (!allowed.includes(key)) bad(key);
  for (const key of required) if (!(key in value)) bad(key);
  return value;
}

export function parseQuery(query: string, allowed: readonly string[]): Record<string, string> {
  const out: Record<string, string> = {};
  if (!query) return out;
  for (const part of query.split('&')) {
    if (!part) bad('query');
    const index = part.indexOf('=');
    let key: string;
    let value: string;
    try {
      key = decodeURIComponent(index < 0 ? part : part.slice(0, index));
      value = decodeURIComponent(index < 0 ? '' : part.slice(index + 1).replace(/\+/g, ' '));
    } catch {
      bad('query');
    }
    if (!allowed.includes(key) || key in out) bad(key);
    out[key] = value;
  }
  return out;
}

export function paging(query: string): { offset: number; limit: number } {
  const q = parseQuery(query, ['cursor', 'limit']);
  let limit = 20;
  if (q['limit'] !== undefined) {
    if (!/^[0-9]{1,3}$/.test(q['limit'])) bad('limit');
    limit = Number(q['limit']);
    if (limit < 1 || limit > 100) bad('limit');
  }
  if (q['cursor'] !== undefined && q['cursor'].length > 256) bad('cursor');
  return { offset: decodeCursor(q['cursor']), limit };
}

export function subjectOf(context: RouteContext): string {
  const userId = context.subject?.userId;
  if (!userId) throw new ServiceError('AUTH_REQUIRED');
  return userId;
}

type Effect = (tx: ProgressTx, userId: string) => Promise<{ status: number; body: unknown }>;

/** Receipt-backed mutation: idempotency key is scoped by user + operation. */
export async function mutate(
  store: ProgressPersistence,
  context: RouteContext,
  operation: string,
  effect: Effect,
): Promise<RouteResult> {
  const userId = subjectOf(context);
  const key = requestScope().idempotencyKey;
  if (!key || !UUID.test(key)) bad('Idempotency-Key');
  const bodyHash = canonicalBodyHash({ body: context.body ?? null, params: requestScope().params });
  const outcome = await store.commitWithReceipt(
    { userId, operation, key },
    bodyHash,
    async (tx) => {
      const result = await effect(tx as ProgressTx, userId);
      return { statusCode: result.status, response: result.body };
    },
  );
  let body = outcome.receipt.response;
  if (
    outcome.status === 'replayed' &&
    body &&
    typeof body === 'object' &&
    'operationId' in body &&
    'status' in body
  ) {
    body = {
      ...(body as Record<string, unknown>),
      status: 'replayed',
      requestId: context.requestId,
    };
  }
  return { status: outcome.receipt.statusCode, body };
}

export function receipt(context: RouteContext, status: 'completed' | 'replayed') {
  return {
    status: 200,
    body: {
      operationId: requestScope().idempotencyKey ?? context.requestId,
      status: status === 'replayed' ? 'completed' : status,
      requestId: context.requestId,
    },
  };
}

export function read<R>(
  store: ProgressPersistence,
  context: RouteContext,
  work: (tx: ProgressTx, userId: string) => Promise<R>,
): Promise<RouteResult> {
  const userId = subjectOf(context);
  return store.transact((tx) => work(tx, userId)).then((body) => ({ status: 200, body }));
}

function profilePatch(body: unknown): ProfilePatch {
  const value = objectBody(
    body,
    ['nickname', 'avatarId', 'publicOptIn', 'dailyGoal', 'learningZone', 'expectedRevision'],
    ['expectedRevision'],
  );
  const patch: ProfilePatch = { expectedRevision: -1 };
  const revision = value['expectedRevision'];
  if (
    !Number.isInteger(revision) ||
    (revision as number) < 0 ||
    (revision as number) > 2147483647
  ) {
    bad('expectedRevision');
  }
  patch.expectedRevision = revision as number;
  if ('nickname' in value) {
    if (typeof value['nickname'] !== 'string' || value['nickname'].length > 40) bad('nickname');
    patch.nickname = value['nickname'];
  }
  if ('avatarId' in value) {
    const avatar = value['avatarId'];
    if (avatar !== null && (typeof avatar !== 'string' || !ID.test(avatar))) bad('avatarId');
    patch.avatarId = avatar as string | null;
  }
  if ('publicOptIn' in value) {
    if (typeof value['publicOptIn'] !== 'boolean') bad('publicOptIn');
    patch.publicOptIn = value['publicOptIn'];
  }
  if ('dailyGoal' in value) {
    if (![5, 10, 15, 20].includes(value['dailyGoal'] as number)) bad('dailyGoal');
    patch.dailyGoal = value['dailyGoal'] as 5 | 10 | 15 | 20;
  }
  if ('learningZone' in value) {
    if (typeof value['learningZone'] !== 'string' || value['learningZone'].length > 64) {
      bad('learningZone');
    }
    patch.learningZone = value['learningZone'];
  }
  return patch;
}

export function emptyBody(body: unknown): void {
  objectBody(body, []);
}

export const PROGRESS_ROUTE_TEMPLATES: readonly RouteTemplate[] = [
  { method: 'GET', path: '/v1/billing/purchases/{purchaseId}' },
  { method: 'POST', path: '/v1/billing/subscription/cancel', noBody: true },
  { method: 'POST', path: '/v1/friend-streaks/{pairId}/respond' },
  { method: 'DELETE', path: '/v1/blocks/{userId}', noBody: true },
  { method: 'DELETE', path: '/v1/classrooms/{classroomId}/membership', noBody: true },
  { method: 'GET', path: '/v1/me/year-review/{year}' },
  { method: 'POST', path: '/v1/family/{groupId}/members' },
  { method: 'DELETE', path: '/v1/family/{groupId}/members/{userId}', noBody: true },
  { method: 'POST', path: '/v1/gifts/{giftId}/redeem', noBody: true },
  { method: 'POST', path: '/v1/me/initialize', noBody: true },
  { method: 'POST', path: '/v1/me/freezes', noBody: true },
  { method: 'POST', path: '/v1/league/join', noBody: true },
  { method: 'POST', path: '/v1/friend-quests/opt-in', noBody: true },
  { method: 'POST', path: '/v1/quests/{questId}/claim' },
  { method: 'GET', path: '/v1/profiles/{userId}' },
  { method: 'DELETE', path: '/v1/follows/{userId}', noBody: true },
];

export function progressRoutes(store: ProgressPersistence): Route[] {
  const user = (
    method: string,
    path: string,
    handle: Route['handle'],
    extra: Partial<Route> = {},
  ) => ({ method, path, auth: 'user', handle, ...extra }) as Route;
  return [
    user('GET', '/v1/me', (c) => read(store, c, (tx, u) => getMe(tx, u))),
    user('PATCH', '/v1/me', (c) => {
      const patch = profilePatch(c.body);
      return mutate(store, c, 'updateMe', async (tx, u) => ({
        status: 200,
        body: await updateMe(tx, u, patch),
      }));
    }),
    user('POST', '/v1/me/initialize', (c) => {
      emptyBody(c.body);
      return mutate(store, c, 'initializeProfile', async (tx, u) => ({
        status: 200,
        body: await initializeProfile(tx, u),
      }));
    }),
    user('GET', '/v1/me/learning-stats', (c) => {
      parseQuery(c.query, []);
      return read(store, c, (tx, u) => getLearningStats(tx, u));
    }),
    user('GET', '/v1/me/rewards', (c) => {
      const q = parseQuery(c.query, ['completionId']);
      const completionId = q['completionId'] ?? null;
      if (completionId !== null && !ID.test(completionId)) bad('completionId');
      return read(store, c, (tx, u) => getRewards(tx, u, completionId));
    }),
    user('GET', '/v1/quests', (c) => {
      const { offset, limit } = paging(c.query);
      return read(store, c, async (tx, u) => {
        const all = await listQuests(tx, u);
        return {
          items: all.slice(offset, offset + limit),
          nextCursor: all.length > offset + limit ? encodeCursor(offset + limit) : null,
          asOf: tx.nowIso,
        };
      });
    }),
    user('POST', '/v1/quests/{questId}/claim', (c) => {
      const questId = pathParam('questId');
      const body = objectBody(c.body, ['periodKey', 'upgradeChest'], ['periodKey']);
      if (typeof body['periodKey'] !== 'string' || body['periodKey'].length > 16) bad('periodKey');
      if (body['upgradeChest'] !== undefined && typeof body['upgradeChest'] !== 'boolean')
        bad('upgradeChest');
      const periodKey = body['periodKey'];
      return mutate(store, c, 'claimQuest', async (tx, u) => ({
        status: 200,
        body: await claimQuest(tx, u, questId, periodKey, body['upgradeChest'] === true),
      }));
    }),
    user('POST', '/v1/me/freezes', (c) => {
      emptyBody(c.body);
      const key = requestScope().idempotencyKey ?? '';
      return mutate(store, c, 'buyFreeze', async (tx, u) => ({
        status: 200,
        body: await buyFreeze(tx, u, key),
      }));
    }),
    user('GET', '/v1/profiles/{userId}', (c) => {
      const target = pathParam('userId');
      return read(store, c, (tx, u) => getPublicProfile(tx, u, target));
    }),
    user('POST', '/v1/follows', (c) => {
      const body = objectBody(c.body, ['targetUserId'], ['targetUserId']);
      const target = body['targetUserId'];
      if (typeof target !== 'string' || !ID.test(target)) bad('targetUserId');
      return mutate(store, c, 'followUser', async (tx, u) =>
        receipt(c, await followUser(tx, u, target)),
      );
    }),
    user('DELETE', '/v1/follows/{userId}', (c) => {
      emptyBody(c.body);
      const target = pathParam('userId');
      return mutate(store, c, 'unfollowUser', async (tx, u) =>
        receipt(c, await unfollowUser(tx, u, target)),
      );
    }),
    user('GET', '/v1/friends', (c) => {
      const { offset, limit } = paging(c.query);
      return read(store, c, (tx, u) => listFriends(tx, u, offset, limit));
    }),
    user('GET', '/v1/activity', (c) => {
      const { offset, limit } = paging(c.query);
      return read(store, c, (tx, u) => listActivity(tx, u, offset, limit));
    }),
    user('GET', '/v1/league', (c) => {
      paging(c.query);
      return read(store, c, (tx, u) => getLeague(tx, u));
    }),
    user('POST', '/v1/league/join', (c) => {
      emptyBody(c.body);
      return mutate(store, c, 'joinLeague', async (tx, u) => ({
        status: 200,
        body: await joinLeague(tx, u),
      }));
    }),
    user('POST', '/v1/friend-quests/opt-in', (c) => {
      emptyBody(c.body);
      return mutate(store, c, 'optInFriendQuest', async (tx, u) =>
        receipt(c, await optInFriendQuest(tx, u)),
      );
    }),
    user('POST', '/v1/me/deletion', (c) => {
      const body = objectBody(c.body, ['confirmation'], ['confirmation']);
      if (body['confirmation'] !== 'DELETE') bad('confirmation');
      return mutate(store, c, 'deleteAccount', async (tx, u) => ({
        status: 202,
        body: await requestDeletion(tx, u),
      }));
    }),
  ];
}
