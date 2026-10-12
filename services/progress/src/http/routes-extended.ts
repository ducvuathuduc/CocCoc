// Progress routes for the operations promoted into OpenAPI on 2026-10-12 (pb/contract2):
// preferences, feedback, shop/boosts/streak repair, friend streaks, interactions, blocks,
// reports, classrooms, year in review, league result, entitlement, MOCK billing, family, gifts,
// referrals, promo codes and mock ads. Same receipt/idempotency rules as ./routes.ts.
import { canonicalBodyHash, type Route } from '../../../shared/src/transport.js';
import {
  activateBoost,
  applyBillingNotification,
  buyItem,
  createFamily,
  getEntitlement,
  getReferral,
  joinFamily,
  listShop,
  recordAdEvent,
  redeemGift,
  redeemPromoCode,
  redeemReferral,
  removeFamilyMember,
  repairStreak,
  sendGift,
  verifyPurchase,
} from '../application/commerce.js';
import {
  blockUser,
  getLeagueResult,
  getPreferences,
  getYearReview,
  inviteFriendStreak,
  joinClassroom,
  leaveClassroom,
  listFriendStreaks,
  markLeagueResultSeen,
  reportUser,
  respondFriendStreak,
  sendFeedback,
  sendInteraction,
  unblockUser,
  updatePreferences,
} from '../application/settings.js';
import type { ProgressPersistence } from '../persistence/port.js';
import type { PurchaseState } from '../domain/commerce.js';
import { ID, UUID, bad, emptyBody, mutate, objectBody, read, receipt } from './routes.js';
import { pathParam, requestScope } from './scope.js';

const STATES = ['PENDING', 'ACTIVE', 'GRACE', 'HOLD', 'CANCELED', 'EXPIRED', 'REVOKED', 'REFUNDED'];
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;

const str = (v: unknown, field: string, min: number, max: number, pattern?: RegExp): string => {
  if (typeof v !== 'string' || v.length < min || v.length > max || (pattern && !pattern.test(v)))
    bad(field);
  return v;
};
const oneOf = <T extends string>(v: unknown, field: string, values: readonly string[]): T => {
  if (typeof v !== 'string' || !values.includes(v)) bad(field);
  return v as T;
};
const bool = (v: unknown, field: string): boolean => {
  if (typeof v !== 'boolean') bad(field);
  return v;
};
const int = (v: unknown, field: string, min: number, max: number): number => {
  if (!Number.isInteger(v) || (v as number) < min || (v as number) > max) bad(field);
  return v as number;
};
const key = () => requestScope().idempotencyKey ?? '';

export function extendedRoutes(store: ProgressPersistence): Route[] {
  const user = (method: string, path: string, handle: Route['handle']) =>
    ({ method, path, auth: 'user', handle }) as Route;
  const prefKeys = [
    'notificationsOff',
    'smartScheduling',
    'reminderMinute',
    'soundEffects',
    'haptics',
    'motivationalMessages',
    'listeningExercises',
    'speakingExercises',
    'friendStreakInvites',
    'expectedRevision',
  ];
  return [
    user('GET', '/v1/me/preferences', (c) => read(store, c, getPreferences)),
    user('PATCH', '/v1/me/preferences', (c) => {
      const b = objectBody(c.body, prefKeys, ['expectedRevision']);
      int(b['expectedRevision'], 'expectedRevision', 0, 2147483647);
      if ('notificationsOff' in b) {
        const list = b['notificationsOff'];
        if (!Array.isArray(list) || list.length > 32) bad('notificationsOff');
        list.forEach((item) =>
          str(item, 'notificationsOff', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/),
        );
      }
      if ('reminderMinute' in b) int(b['reminderMinute'], 'reminderMinute', 0, 1439);
      for (const k of prefKeys.slice(1))
        if (k !== 'reminderMinute' && k !== 'expectedRevision' && k in b) bool(b[k], k);
      return mutate(store, c, 'updatePreferences', async (tx, u) => ({
        status: 200,
        body: await updatePreferences(
          tx,
          u,
          b as Record<string, unknown> & { expectedRevision: number },
        ),
      }));
    }),
    user('POST', '/v1/feedback', (c) => {
      const b = objectBody(
        c.body,
        ['topic', 'message', 'appVersion', 'platform'],
        ['topic', 'message', 'appVersion', 'platform'],
      );
      const request = {
        topic: str(b['topic'], 'topic', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/),
        message: str(b['message'], 'message', 1, 2000),
        appVersion: str(b['appVersion'], 'appVersion', 1, 32),
        platform: oneOf(b['platform'], 'platform', ['ANDROID', 'IOS', 'WEB']),
      };
      return mutate(store, c, 'sendFeedback', async (tx, u) =>
        receipt(c, await sendFeedback(tx, u, request, key())),
      );
    }),
    user('GET', '/v1/shop', (c) => read(store, c, listShop)),
    user('POST', '/v1/shop/purchases', (c) => {
      const b = objectBody(
        c.body,
        ['itemId', 'quantity', 'catalogVersion'],
        ['itemId', 'quantity', 'catalogVersion'],
      );
      const request = {
        itemId: str(b['itemId'], 'itemId', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/),
        quantity: int(b['quantity'], 'quantity', 1, 10),
        catalogVersion: str(b['catalogVersion'], 'catalogVersion', 1, 36, ID),
      };
      return mutate(store, c, 'buyItem', async (tx, u) => ({
        status: 200,
        body: await buyItem(tx, u, request, key()),
      }));
    }),
    user('POST', '/v1/me/boosts', (c) => {
      const b = objectBody(c.body, ['itemId'], ['itemId']);
      const itemId = str(b['itemId'], 'itemId', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/);
      return mutate(store, c, 'activateBoost', async (tx, u) => ({
        status: 200,
        body: await activateBoost(tx, u, itemId, key()),
      }));
    }),
    user('POST', '/v1/me/streak-repair', (c) => {
      const b = objectBody(c.body, ['lostStreakDay', 'payWith'], ['lostStreakDay', 'payWith']);
      const request = {
        lostStreakDay: str(b['lostStreakDay'], 'lostStreakDay', 10, 10, /^\d{4}-\d{2}-\d{2}$/),
        payWith: oneOf<'GEMS' | 'ITEM'>(b['payWith'], 'payWith', ['GEMS', 'ITEM']),
      };
      return mutate(store, c, 'repairStreak', async (tx, u) => ({
        status: 200,
        body: await repairStreak(tx, u, request, key()),
      }));
    }),
    user('GET', '/v1/friend-streaks', (c) => read(store, c, listFriendStreaks)),
    user('POST', '/v1/friend-streaks', (c) => {
      const b = objectBody(c.body, ['targetUserId'], ['targetUserId']);
      const target = str(b['targetUserId'], 'targetUserId', 1, 36, ID);
      return mutate(store, c, 'inviteFriendStreak', async (tx, u) => ({
        status: 200,
        body: await inviteFriendStreak(tx, u, target),
      }));
    }),
    user('POST', '/v1/friend-streaks/{pairId}/respond', (c) => {
      const pairId = pathParam('pairId');
      const b = objectBody(c.body, ['accept'], ['accept']);
      const accept = bool(b['accept'], 'accept');
      return mutate(store, c, 'respondFriendStreak', async (tx, u) => ({
        status: 200,
        body: await respondFriendStreak(tx, u, pairId, accept),
      }));
    }),
    user('POST', '/v1/interactions', (c) => {
      const b = objectBody(
        c.body,
        ['targetUserId', 'kind', 'contextId', 'messageKey'],
        ['targetUserId', 'kind', 'contextId', 'messageKey'],
      );
      const request = {
        targetUserId: str(b['targetUserId'], 'targetUserId', 1, 36, ID),
        kind: oneOf(b['kind'], 'kind', ['NUDGE', 'HIGH_FIVE', 'KUDOS', 'GIFT_BOOST', 'CONGRATS']),
        contextId: str(b['contextId'], 'contextId', 1, 36, ID),
        messageKey: str(b['messageKey'], 'messageKey', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/),
      };
      return mutate(store, c, 'sendInteraction', async (tx, u) => ({
        status: 200,
        body: await sendInteraction(tx, u, request, key()),
      }));
    }),
    user('POST', '/v1/blocks', (c) => {
      const b = objectBody(c.body, ['targetUserId'], ['targetUserId']);
      const target = str(b['targetUserId'], 'targetUserId', 1, 36, ID);
      return mutate(store, c, 'blockUser', async (tx, u) =>
        receipt(c, await blockUser(tx, u, target)),
      );
    }),
    user('DELETE', '/v1/blocks/{userId}', (c) => {
      emptyBody(c.body);
      const target = pathParam('userId');
      return mutate(store, c, 'unblockUser', async (tx, u) =>
        receipt(c, await unblockUser(tx, u, target)),
      );
    }),
    user('POST', '/v1/user-reports', (c) => {
      const b = objectBody(
        c.body,
        ['targetUserId', 'reason', 'note'],
        ['targetUserId', 'reason', 'note'],
      );
      const request = {
        targetUserId: str(b['targetUserId'], 'targetUserId', 1, 36, ID),
        reason: oneOf(b['reason'], 'reason', [
          'SPAM',
          'INAPPROPRIATE_NAME',
          'INAPPROPRIATE_AVATAR',
          'HARASSMENT',
          'CHEATING',
          'OTHER',
        ]),
        note: b['note'] === null ? null : str(b['note'], 'note', 0, 512),
      };
      return mutate(store, c, 'reportUser', async (tx, u) =>
        receipt(c, await reportUser(tx, u, request)),
      );
    }),
    user('POST', '/v1/classrooms/join', (c) => {
      const b = objectBody(c.body, ['joinCode'], ['joinCode']);
      const code = str(b['joinCode'], 'joinCode', 4, 16, /^[A-Za-z0-9-]+$/);
      return mutate(store, c, 'joinClassroom', async (tx, u) => ({
        status: 200,
        body: await joinClassroom(tx, u, code),
      }));
    }),
    user('DELETE', '/v1/classrooms/{classroomId}/membership', (c) => {
      emptyBody(c.body);
      const classroomId = pathParam('classroomId');
      return mutate(store, c, 'leaveClassroom', async (tx, u) =>
        receipt(c, await leaveClassroom(tx, u, classroomId)),
      );
    }),
    user('GET', '/v1/me/year-review/{year}', (c) => {
      const raw = pathParam('year');
      if (!/^\d{4}$/.test(raw)) bad('year');
      return read(store, c, (tx, u) => getYearReview(tx, u, Number(raw)));
    }),
    user('GET', '/v1/league/result', (c) => read(store, c, getLeagueResult)),
    user('POST', '/v1/league/result/seen', (c) => {
      const b = objectBody(c.body, ['weekId'], ['weekId']);
      const weekId = str(b['weekId'], 'weekId', 10, 10, /^\d{4}-\d{2}-\d{2}$/);
      return mutate(store, c, 'markLeagueResultSeen', async (tx, u) =>
        receipt(c, await markLeagueResultSeen(tx, u, weekId)),
      );
    }),
    user('GET', '/v1/me/entitlement', (c) => read(store, c, getEntitlement)),
    user('POST', '/v1/billing/purchases', (c) => {
      const b = objectBody(
        c.body,
        ['productId', 'kind', 'platform', 'simulationOutcome'],
        ['productId', 'kind', 'platform', 'simulationOutcome'],
      );
      if (b['platform'] !== 'SIMULATION') bad('platform');
      const request = {
        productId: str(b['productId'], 'productId', 1, 64, /^[A-Za-z0-9][A-Za-z0-9_.-]*$/),
        kind: oneOf<'SUBSCRIPTION' | 'GEMS'>(b['kind'], 'kind', ['SUBSCRIPTION', 'GEMS']),
        simulationOutcome: oneOf<PurchaseState>(
          b['simulationOutcome'],
          'simulationOutcome',
          STATES,
        ),
      };
      return mutate(store, c, 'verifyPurchase', async (tx, u) => ({
        status: 200,
        body: await verifyPurchase(tx, u, request, key()),
      }));
    }),
    {
      method: 'POST',
      path: '/internal/billing/notifications',
      auth: 'service',
      allowedSenders: ['maintainer'],
      async handle(c) {
        const b = objectBody(
          c.body,
          ['notificationId', 'purchaseId', 'platform', 'state', 'occurredAt'],
          ['notificationId', 'purchaseId', 'platform', 'state', 'occurredAt'],
        );
        if (b['platform'] !== 'SIMULATION') bad('platform');
        const notification = {
          notificationId: str(b['notificationId'], 'notificationId', 1, 128),
          purchaseId: str(b['purchaseId'], 'purchaseId', 1, 36, ID),
          state: oneOf<PurchaseState>(b['state'], 'state', STATES),
          occurredAt: str(b['occurredAt'], 'occurredAt', 20, 40, ISO),
        };
        const status = await applyBillingNotification(store, notification, canonicalBodyHash(b));
        return {
          status: 200,
          body: {
            operationId: notification.notificationId.slice(0, 64),
            status,
            requestId: c.requestId,
          },
        };
      },
    },
    user('POST', '/v1/family', (c) => {
      const b = objectBody(c.body, ['plan'], ['plan']);
      const plan = oneOf<'SUPER' | 'MAX'>(b['plan'], 'plan', ['SUPER', 'MAX']);
      return mutate(store, c, 'createFamily', async (tx, u) => ({
        status: 200,
        body: await createFamily(tx, u, plan, key()),
      }));
    }),
    user('POST', '/v1/family/{groupId}/members', (c) => {
      const groupId = pathParam('groupId');
      const b = objectBody(c.body, ['inviteCode'], ['inviteCode']);
      const code = str(b['inviteCode'], 'inviteCode', 4, 16, /^[A-Za-z0-9-]+$/);
      return mutate(store, c, 'joinFamily', async (tx, u) => ({
        status: 200,
        body: await joinFamily(tx, u, groupId, code),
      }));
    }),
    user('DELETE', '/v1/family/{groupId}/members/{userId}', (c) => {
      emptyBody(c.body);
      const groupId = pathParam('groupId');
      const member = pathParam('userId');
      return mutate(store, c, 'removeFamilyMember', async (tx, u) => ({
        status: 200,
        body: await removeFamilyMember(tx, u, groupId, member),
      }));
    }),
    user('POST', '/v1/gifts', (c) => {
      const b = objectBody(
        c.body,
        ['recipientUserId', 'plan', 'durationDays', 'note', 'simulationOutcome'],
        ['recipientUserId', 'plan', 'durationDays', 'note', 'simulationOutcome'],
      );
      const request = {
        recipientUserId: str(b['recipientUserId'], 'recipientUserId', 1, 36, ID),
        plan: oneOf<'SUPER' | 'MAX'>(b['plan'], 'plan', ['SUPER', 'MAX']),
        durationDays: int(b['durationDays'], 'durationDays', 1, 365),
        note: b['note'] === null ? null : str(b['note'], 'note', 0, 160),
        simulationOutcome: oneOf<PurchaseState>(
          b['simulationOutcome'],
          'simulationOutcome',
          STATES,
        ),
      };
      return mutate(store, c, 'sendGift', async (tx, u) => ({
        status: 200,
        body: await sendGift(tx, u, request, key()),
      }));
    }),
    user('POST', '/v1/gifts/{giftId}/redeem', (c) => {
      emptyBody(c.body);
      const giftId = pathParam('giftId');
      return mutate(store, c, 'redeemGift', async (tx, u) => ({
        status: 200,
        body: await redeemGift(tx, u, giftId),
      }));
    }),
    user('GET', '/v1/me/referral', (c) => read(store, c, getReferral)),
    user('POST', '/v1/referrals/redeem', (c) => {
      const b = objectBody(c.body, ['code'], ['code']);
      const code = str(b['code'], 'code', 4, 16, /^[A-Za-z0-9-]+$/);
      return mutate(store, c, 'redeemReferral', async (tx, u) =>
        receipt(c, await redeemReferral(tx, u, code)),
      );
    }),
    user('POST', '/v1/promo-codes/redeem', (c) => {
      const b = objectBody(c.body, ['code'], ['code']);
      const code = str(b['code'], 'code', 4, 32, /^[A-Za-z0-9 -]+$/);
      return mutate(store, c, 'redeemPromoCode', async (tx, u) => ({
        status: 200,
        body: await redeemPromoCode(tx, u, code, key()),
      }));
    }),
    user('POST', '/v1/ad-events', (c) => {
      const b = objectBody(
        c.body,
        ['adEventId', 'placement', 'kind'],
        ['adEventId', 'placement', 'kind'],
      );
      const request = {
        adEventId: str(b['adEventId'], 'adEventId', 36, 36, UUID),
        placement: oneOf(b['placement'], 'placement', [
          'LESSON_END_INTERSTITIAL',
          'REWARDED_GEMS',
          'REWARDED_ENERGY_REFILL',
        ]),
        kind: oneOf<'IMPRESSION' | 'REWARDED_COMPLETION'>(b['kind'], 'kind', [
          'IMPRESSION',
          'REWARDED_COMPLETION',
        ]),
      };
      return mutate(store, c, 'recordAdEvent', async (tx, u) => ({
        status: 200,
        body: await recordAdEvent(tx, u, request),
      }));
    }),
  ];
}
