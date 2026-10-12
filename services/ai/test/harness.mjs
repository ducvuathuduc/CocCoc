// Shared AI test harness: memory store, real router + request scope, fake verified-subject auth
// (Bearer <userId>), signed Progress events, OpenAPI response validation and an Appwrite column
// check of every stored row against appwrite/schema/foundation.json (the memory adapter does not
// enforce the TablesDB schema, so tests do).
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { kit, repoRoot } from './kit.mjs';

const api = JSON.parse(fs.readFileSync(path.join(repoRoot, 'docs/api/openapi.yaml'), 'utf8'));
const schema = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'appwrite/schema/foundation.json'), 'utf8'),
);
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://coc.invalid/s', components: api.components });
const validators = new Map();
export function validate(name, value) {
  if (!validators.has(name)) {
    validators.set(
      name,
      ajv.compile({ $ref: `https://coc.invalid/s#/components/schemas/${name}` }),
    );
  }
  const fn = validators.get(name);
  if (!fn(value))
    throw new Error(`${name} invalid: ${JSON.stringify(fn.errors)} ${JSON.stringify(value)}`);
  return value;
}

const TABLES = new Map(schema.tables.filter((t) => t.id.startsWith('a_')).map((t) => [t.id, t]));
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
/** Throws when a stored row would be rejected by the Appwrite table definition. */
export function checkRows(store) {
  let checked = 0;
  for (const [tableId, table] of TABLES) {
    const columns = new Map(table.columns.map((c) => [c.key, c]));
    for (const { id, row } of store.dump(tableId)) {
      if (!/^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/.test(id))
        throw new Error(`${tableId}: bad id ${id}`);
      for (const key of Object.keys(row)) {
        if (!columns.has(key)) throw new Error(`${tableId}.${key}: unknown column`);
      }
      for (const [key, col] of columns) {
        const value = row[key];
        if (value === null || value === undefined) {
          if (col.required !== false) throw new Error(`${tableId}.${key}: required`);
          continue;
        }
        const fail = (why) => {
          throw new Error(`${tableId}.${key}: ${why} (${JSON.stringify(value).slice(0, 80)})`);
        };
        if (col.type === 'string' && (typeof value !== 'string' || value.length > col.size))
          fail('string');
        if (col.type === 'integer') {
          if (!Number.isSafeInteger(value)) fail('integer');
          if (col.min !== undefined && value < col.min) fail('min');
          if (col.max !== undefined && value > col.max) fail('max');
        }
        if (col.type === 'enum' && !col.elements.includes(value)) fail('enum');
        if (col.type === 'datetime' && (typeof value !== 'string' || !ISO.test(value)))
          fail('datetime');
        if (col.type === 'boolean' && typeof value !== 'boolean') fail('boolean');
      }
      checked++;
    }
  }
  return checked;
}

export const progressKey = { keyId: 'p-to-ai', sender: 'progress', secret: Buffer.alloc(32, 4) };
export const learningKey = { keyId: 'l-to-ai', sender: 'learning', secret: Buffer.alloc(32, 5) };

export function setup({
  start = Date.parse('2026-10-12T03:00:00Z'),
  gates,
  store: given,
  realClock = false,
  provider,
} = {}) {
  const clock = {
    fixed: start,
    get now() {
      return realClock ? Date.now() : this.fixed;
    },
    set now(value) {
      this.fixed = value;
    },
  };
  const store = given ?? kit.createMemoryAiPersistence(() => clock.now);
  const deps = {
    persistence: store,
    nowMs: () => clock.now,
    newId: randomUUID,
    gates: gates ?? kit.DEFAULT_GATES,
    provider: provider ?? kit.SCRIPTED_PROVIDER,
  };
  const wiring = kit.aiWiring(deps);
  const auth = { verify: async (jwt) => ({ userId: jwt }) };
  const router = kit.aiHandler(
    kit.createRouter({
      service: 'ai',
      persistence: store,
      mode: 'local-test',
      auth,
      keyring: kit.createKeyring([progressKey, learningKey]),
      routes: wiring.routes,
      eventConsumer: wiring.eventConsumer,
      nowMs: () => clock.now,
    }),
  );
  async function call(method, pathname, { user, body, idem, query = '', headers = {} } = {}) {
    const bodyText = body === undefined ? undefined : JSON.stringify(body);
    const h = { ...headers };
    if (user) h.authorization = `Bearer ${user}`;
    if (idem) h['idempotency-key'] = idem;
    return router({
      req: {
        method,
        path: pathname,
        headers: h,
        ...(bodyText !== undefined ? { bodyText } : {}),
        queryString: query,
      },
      res: { json: (b, status) => ({ status, body: b }) },
    });
  }
  async function event(
    type,
    payload,
    {
      eventId = randomUUID(),
      sender = progressKey,
      occurredAt = new Date(clock.now).toISOString(),
    } = {},
  ) {
    const envelope = {
      eventId,
      type,
      schemaVersion: 1,
      producer: sender.sender,
      aggregateId: payload.userId,
      occurredAt,
      requestId: eventId,
      payload,
    };
    const bodyText = JSON.stringify(envelope);
    const signed = kit.signServiceRequest({
      key: sender,
      method: 'POST',
      path: '/internal/events',
      body: bodyText,
      nowSeconds: Math.floor(clock.now / 1000),
    });
    const response = await router({
      req: { method: 'POST', path: '/internal/events', headers: signed, bodyText },
      res: { json: (b, status) => ({ status, body: b }) },
    });
    return { ...response, envelope };
  }
  const grant = (userId, plan = 'MAX', revision = 1, extra = {}) =>
    event('entitlement.changed.v1', {
      userId,
      plan,
      status: 'ACTIVE',
      expiresAt: null,
      entitlementRevision: revision,
      ...extra,
    });
  return { clock, store, deps, call, event, grant };
}

/** 16 kHz mono 16-bit PCM WAV of `seconds` silence, base64 + sha256. */
export function wav(seconds = 1) {
  const data = Buffer.alloc(Math.round(16000 * 2 * seconds));
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(16000, 24);
  header.writeUInt32LE(32000, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);
  const bytes = Buffer.concat([header, data]);
  return {
    wavBase64: bytes.toString('base64'),
    audioSha256: createHash('sha256').update(bytes).digest('hex'),
  };
}
export { kit };
