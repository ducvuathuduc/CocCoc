// MAINTAINER ONLY (tools/admin/*.mjs). Promo-code and classroom administration over the Progress
// persistence port with a server key. Never routed: no user or service HTTP route reaches these.
// Plaintext codes are printed once by the CLI and stored only as SHA-256 hashes.
import { randomBytes } from 'node:crypto';
import { createPromoCode, codeHash, type PromoDefinition } from '../application/commerce.js';
import { operationId } from '../application/records.js';
import { classroomCodeHash } from '../application/settings.js';
import { normalizeCode, SHOP_ITEMS } from '../domain/commerce.js';
import { rowId } from '../persistence/core.js';
import type { ProgressPersistence, Row } from '../persistence/port.js';

export { createAppwriteProgressPersistence } from '../persistence/appwrite.js';
export { createMemoryProgressPersistence } from '../persistence/memory.js';
export { PROGRESS_SCHEMA } from '../persistence/schema.js';
export { createPromoCode, codeHash, classroomCodeHash };
export { joinClassroom } from '../application/settings.js';
export { redeemPromoCode } from '../application/commerce.js';

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE = /^[A-Za-z0-9-]+$/;
const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

/** Random human code (no 0/O/1/I), e.g. PREFIX-7Q2KM9XA. */
export function randomCode(prefix = '', length = 8): string {
  const bytes = randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i++) out += ALPHABET[(bytes[i] as number) % ALPHABET.length];
  return prefix ? `${prefix.toUpperCase()}-${out}` : out;
}

function fail(message: string): never {
  throw new Error(message);
}

export function validatePromo(def: PromoDefinition): PromoDefinition {
  if (!CODE.test(def.code) || def.code.length < 4 || def.code.length > 32)
    fail('code: 4-32 of A-Z 0-9 -');
  if (!['SUPER_DAYS', 'GEMS', 'ITEM'].includes(def.rewardType))
    fail('rewardType: SUPER_DAYS|GEMS|ITEM');
  if (
    def.rewardType === 'SUPER_DAYS' &&
    !(Number.isInteger(def.superDays) && def.superDays! >= 1 && def.superDays! <= 366)
  )
    fail('superDays: 1..366');
  if (
    def.rewardType === 'GEMS' &&
    !(Number.isInteger(def.gems) && def.gems! >= 1 && def.gems! <= 100000)
  )
    fail('gems: 1..100000');
  if (def.rewardType === 'ITEM') {
    if (!SHOP_ITEMS.some((item) => item.itemId === def.itemId))
      fail(`itemId: one of ${SHOP_ITEMS.map((i) => i.itemId).join(', ')}`);
    if (!(
      Number.isInteger(def.itemQuantity ?? 1) &&
      (def.itemQuantity ?? 1) >= 1 &&
      (def.itemQuantity ?? 1) <= 99
    ))
      fail('itemQuantity: 1..99');
  }
  if (
    def.maxRedemptions !== undefined &&
    def.maxRedemptions !== null &&
    !(Number.isInteger(def.maxRedemptions) && def.maxRedemptions >= 1)
  )
    fail('maxRedemptions: integer >= 1');
  if (Number.isNaN(Date.parse(def.startsAt))) fail('startsAt: ISO date-time');
  if (def.endsAt && (Number.isNaN(Date.parse(def.endsAt)) || def.endsAt <= def.startsAt))
    fail('endsAt: after startsAt');
  if (def.note && def.note.length > 160) fail('note: <= 160 chars');
  return def;
}

export function promoRowId(code: string): string {
  return rowId('p_promo_codes', operationId('promo', codeHash(code)));
}

/** Create (idempotent per code) and return the stored row. */
export async function adminCreatePromo(store: ProgressPersistence, def: PromoDefinition) {
  validatePromo(def);
  const promoId = await createPromoCode(store, def);
  const row = await store.read('p_promo_codes', promoRowId(def.code));
  return { promoId, row };
}

export async function adminSetPromoStatus(
  store: ProgressPersistence,
  code: string,
  status: 'ACTIVE' | 'PAUSED' | 'RETIRED',
) {
  const id = promoRowId(code);
  return store.transact(async (tx) => {
    const row = await tx.get('p_promo_codes', id);
    if (!row) fail('promo code not found');
    const { revision: _r, createdAt: _c, updatedAt: _u, ...rest } = row as Row;
    void _r;
    void _c;
    void _u;
    tx.put('p_promo_codes', id, { ...rest, status });
    return { promoId: String(row['promoId']), status };
  });
}

export async function adminListPromos(store: ProgressPersistence, limit = 100) {
  return (await store.list('p_promo_codes', { orderBy: [['createdAt', 'desc']], limit })).map(
    ({ row }) => ({
      promoId: row['promoId'],
      rewardType: row['rewardType'],
      superDays: row['superDays'],
      gems: row['gems'],
      itemId: row['itemId'],
      itemQuantity: row['itemQuantity'],
      redeemedCount: row['redeemedCount'],
      maxRedemptions: row['maxRedemptions'],
      startsAt: row['startsAt'],
      endsAt: row['endsAt'],
      status: row['status'],
      note: row['note'],
    }),
  );
}

export interface ClassroomDefinition {
  name: string;
  courseId: string;
  teacherUserId: string;
  joinCode: string;
}

export function classroomRowId(classroomId: string): string {
  return rowId('p_classrooms', classroomId);
}

/** Create a classroom; the join code must be unused by any ACTIVE classroom. */
export async function adminCreateClassroom(store: ProgressPersistence, def: ClassroomDefinition) {
  if (!def.name || def.name.length > 80) fail('name: 1..80 chars');
  if (!ID.test(def.courseId)) fail('courseId');
  if (!ID.test(def.teacherUserId)) fail('teacherUserId');
  if (!CODE.test(def.joinCode) || def.joinCode.length < 4 || def.joinCode.length > 16)
    fail('joinCode: 4-16 of A-Z 0-9 -');
  const hash = classroomCodeHash(def.joinCode);
  const classroomId = operationId('classroom', hash);
  return store.transact(async (tx) => {
    const taken = await tx.list('p_classrooms', {
      where: { joinCodeHash: hash, status: 'ACTIVE' },
      limit: 1,
    });
    const id = classroomRowId(classroomId);
    const existing = await tx.get('p_classrooms', id);
    if (taken.length || existing) fail('join code already used');
    tx.put('p_classrooms', id, {
      classroomId,
      teacherUserId: def.teacherUserId,
      name: def.name,
      courseId: def.courseId,
      joinCodeHash: hash,
      status: 'ACTIVE',
    });
    return {
      classroomId,
      joinCode: normalizeCode(def.joinCode),
      name: def.name,
      courseId: def.courseId,
    };
  });
}

export async function adminArchiveClassroom(store: ProgressPersistence, classroomId: string) {
  const id = classroomRowId(classroomId);
  return store.transact(async (tx) => {
    const row = await tx.get('p_classrooms', id);
    if (!row) fail('classroom not found');
    const { revision: _r, createdAt: _c, updatedAt: _u, ...rest } = row as Row;
    void _r;
    void _c;
    void _u;
    tx.put('p_classrooms', id, { ...rest, status: 'ARCHIVED' });
    return { classroomId, status: 'ARCHIVED' };
  });
}

export async function adminListClassrooms(store: ProgressPersistence, limit = 100) {
  const rows = await store.list('p_classrooms', { orderBy: [['createdAt', 'desc']], limit });
  const out = [];
  for (const { row } of rows) {
    const members = await store.list('p_classroom_members', {
      where: { classroomId: String(row['classroomId']), status: 'ACTIVE' },
      limit: 500,
    });
    out.push({
      classroomId: row['classroomId'],
      name: row['name'],
      courseId: row['courseId'],
      teacherUserId: row['teacherUserId'],
      status: row['status'],
      activeMembers: members.length,
    });
  }
  return out;
}
