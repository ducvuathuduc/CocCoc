// Shared Progress test harness: memory store (strict schema), real router + request scope,
// fake verified-subject auth (Bearer <userId>), signed-event helper and OpenAPI validators.
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { kit, repoRoot } from './kit.mjs';

const api = JSON.parse(fs.readFileSync(path.join(repoRoot, 'docs/api/openapi.yaml'), 'utf8'));
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

export function setup({
  start = Date.parse('2026-10-12T03:00:00.000Z'),
  store: given,
  realClock = false,
  allowSimulatedCommerce = true,
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
  const store =
    given ?? kit.createMemoryProgressPersistence(() => clock.now, { strictSchema: true });
  const wiring = kit.progressWiring(store, {}, { allowSimulatedCommerce });
  const auth = {
    async verify(jwt) {
      return { userId: jwt };
    },
  };
  const router = kit.scopeProgressHandler(
    kit.createRouter({
      service: 'progress',
      persistence: store,
      mode: 'local-test',
      auth,
      routes: wiring.routes,
      eventConsumer: wiring.eventConsumer,
      nowMs: () => clock.now,
    }),
  );
  async function call(method, urlPath, { user, body, key, query = '' } = {}) {
    const headers = {};
    if (user) headers.authorization = `Bearer ${user}`;
    if (key !== null && method !== 'GET') headers['idempotency-key'] = key ?? randomUUID();
    let result;
    await router({
      req: {
        method,
        path: urlPath,
        headers,
        bodyText: body === undefined ? '' : JSON.stringify(body),
        queryString: query,
      },
      res: { json: (b, status) => (result = { status, body: b }) },
    });
    return result;
  }
  const consumer = wiring.eventConsumer;
  async function deliver(event) {
    return consumer.consume(event, {
      bodyHash: kit.canonicalBodyHash(event),
      requestId: 'r',
      sender: event.producer,
    });
  }
  return { clock, store, call, deliver, kit };
}

export function lessonEvent(overrides = {}, payload = {}) {
  const completionId = payload.completionId ?? `c-${randomUUID().slice(0, 8)}`;
  return {
    eventId: randomUUID(),
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: completionId,
    occurredAt: '2026-10-12T03:00:00.000Z',
    requestId: randomUUID(),
    ...overrides,
    payload: {
      completionId,
      userId: 'alice',
      courseId: 'vi_en',
      lessonVersion: 'v1',
      rewardIdentity: `lesson-${completionId}`,
      source: 'ONLINE',
      mode: 'LESSON',
      originalCount: 10,
      originalCorrect: 9,
      assisted: false,
      ...payload,
    },
  };
}

export async function initUser(h, user, { publicOptIn = false } = {}) {
  const init = await h.call('POST', '/v1/me/initialize', { user });
  if (init.status !== 200) throw new Error(JSON.stringify(init));
  if (publicOptIn) {
    const patched = await h.call('PATCH', '/v1/me', {
      user,
      body: { publicOptIn: true, expectedRevision: init.body.revision },
    });
    if (patched.status !== 200) throw new Error(JSON.stringify(patched));
  }
  return init.body;
}

export async function rewardsOf(h, user, query = '') {
  const r = await h.call('GET', '/v1/me/rewards', { user, query });
  if (r.status !== 200) throw new Error(JSON.stringify(r));
  return validate('Rewards', r.body);
}
