import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { kit } from '../../services/progress/test/kit.mjs';

// Test-only: execute the unchanged Node router over its strict memory adapter.
// The .NET test replays the same inputs through ASP.NET Core. No production
// service invokes Node or selects a memory driver.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const inputPath = path.join(root, 'backend-dotnet/tests/fixtures/progress-parity-scenarios.json');
const outputPath = path.join(root, 'backend-dotnet/tests/fixtures/progress-node-golden.json');
const scenarioBytes = fs.readFileSync(inputPath);
const scenario = JSON.parse(scenarioBytes);
let now = Date.parse(scenario.now);
let deletionRequestId;
let watermarkPending;
let relayOutcome = 'ack';
let relayRandom = 0.5;
const relayDeliveries = [];
const store = kit.createMemoryProgressPersistence(() => now, { strictSchema: true });
const wiring = kit.progressWiring(
  store,
  {
    async deliver(target, event) {
      relayDeliveries.push({
        target,
        event: {
          ...event,
          eventId: '$event-id',
          requestId: '$event-id',
        },
      });
      return relayOutcome;
    },
    watermark: {
      async pendingBefore() {
        if (watermarkPending === undefined) throw new Error('WATERMARK_NOT_CONFIGURED');
        return watermarkPending;
      },
    },
    random: () => relayRandom,
  },
  { allowSimulatedCommerce: true },
);
const eventKeys = Object.fromEntries(
  Object.entries({ learning: 13, ai: 12, scheduler: 14, maintainer: 15 }).map(([sender, fill]) => [
    sender,
    { keyId: `parity-${sender}`, sender, secret: Buffer.alloc(32, fill) },
  ]),
);
const router = kit.scopeProgressHandler(
  kit.createRouter({
    service: 'progress',
    persistence: store,
    mode: 'local-test',
    auth: {
      async verify(userId) {
        return { userId };
      },
    },
    routes: wiring.routes,
    eventConsumer: wiring.eventConsumer,
    keyring: kit.createKeyring(Object.values(eventKeys)),
    nowMs: () => now,
  }),
);

function projectRow(table, entry) {
  const row = structuredClone(entry.row);
  let id = entry.id;
  if (table === 'p_outbox') {
    id = '$event-id';
    row.eventId = '$event-id';
  }
  for (const key of ['responseJson', 'payloadJson'])
    if (typeof row[key] === 'string') row[key] = JSON.parse(row[key]);
  if (table === 'p_outbox' && row.type === 'account.deleted.v1' &&
      deletionRequestId && row.payloadJson?.requestId === deletionRequestId)
    row.payloadJson.requestId = '$deletion-request-id';
  return { id, row };
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}
const results = [];
for (const [index, step] of scenario.steps.entries()) {
  if (step.clock) {
    now = Date.parse(step.clock);
    results.push({ index, kind: 'clock' });
    continue;
  }
  if ('watermarkPending' in step) {
    watermarkPending = step.watermarkPending;
    results.push({ index, kind: 'control' });
    continue;
  }
  if ('relayOutcome' in step) {
    relayOutcome = step.relayOutcome;
    results.push({ index, kind: 'control' });
    continue;
  }
  if ('relayRandom' in step) {
    relayRandom = step.relayRandom;
    results.push({ index, kind: 'control' });
    continue;
  }
  if (step.seedRangeDays) {
    const { table, userId, startDay, count, row: source } = step.seedRangeDays;
    await store.transact(async (tx) => {
      for (let offset = 0; offset < count; offset++) {
        const day = kit.addDays(startDay, offset);
        const id = kit.rowId(table, userId, day);
        const row = Object.fromEntries(
          Object.entries(source).map(([key, value]) => [
            key,
            typeof value === 'string' ? value.replaceAll('{day}', day) : value,
          ]),
        );
        const existing = await tx.get(table, id);
        tx.put(table, id, { ...existing, ...row });
      }
    });
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.seedMany) {
    const { table, partPrefix, count, row: source } = step.seedMany;
    await store.transact(async (tx) => {
      for (let offset = 0; offset < count; offset++) {
        const index = String(offset).padStart(3, '0');
        const parts = (step.seedMany.parts ?? [`${partPrefix}${index}`]).map((part) =>
          part.replaceAll('{index}', index),
        );
        const row = Object.fromEntries(
          Object.entries(source).map(([key, value]) => [
            key,
            typeof value === 'string' ? value.replaceAll('{index}', index) : value,
          ]),
        );
        const id = kit.rowId(table, ...parts);
        const existing = await tx.get(table, id);
        tx.put(table, id, { ...existing, ...row });
      }
    });
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.seed) {
    await store.transact(async (tx) => {
      for (const seed of step.seed) {
        const id = kit.rowId(seed.table, ...seed.parts);
        const existing = await tx.get(seed.table, id);
        tx.put(seed.table, id, { ...existing, ...seed.patch });
      }
    });
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.deleteRows) {
    const attempt = store.driver.begin();
    const writes = [];
    for (const row of step.deleteRows) {
      const id = kit.rowId(row.table, ...row.parts);
      const current = await attempt.get(row.table, id);
      if (!current) throw new Error(`Cannot delete missing fixture row ${row.table}/${id}`);
      writes.push({
        action: 'delete',
        table: row.table,
        id,
        expectedRevision: Number(current['revision'] ?? 0),
      });
    }
    await attempt.commit(writes);
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.seedRaw) {
    // Test-only legacy/corrupt rows bypass strict schema checks to exercise reader resilience.
    if (step.seedRaw.some((seed) => seed.table !== 'p_achievements'))
      throw new Error('Raw fixture seeding is restricted to p_achievements');
    const attempt = store.driver.begin();
    await attempt.commit(
      step.seedRaw.map((seed) => ({
        action: 'create',
        table: seed.table,
        id: kit.rowId(seed.table, ...seed.parts),
        data: structuredClone(seed.row),
      })),
    );
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.inspect) {
    const tables = Object.fromEntries(
      step.inspect.map((table) => [
        table,
        table === '@relay-deliveries'
          ? structuredClone(relayDeliveries).sort((a, b) => {
              const left = stableJson(a);
              const right = stableJson(b);
              return left < right ? -1 : left > right ? 1 : 0;
            })
          : (() => {
              const rows = store.dump(table).map((row) => projectRow(table, row));
              rows.sort((a, b) => {
                const left = table === 'p_outbox' ? stableJson(a) : a.id;
                const right = table === 'p_outbox' ? stableJson(b) : b.id;
                return left < right ? -1 : left > right ? 1 : 0;
              });
              return rows;
            })(),
      ]),
    );
    results.push({ index, kind: 'inspect', tables });
    continue;
  }
  const question = step.path.indexOf('?');
  const routePath = question < 0 ? step.path : step.path.slice(0, question);
  const query = question < 0 ? '' : step.path.slice(question + 1);
  const headers = { authorization: `Bearer ${step.user}`, 'x-request-id': scenario.requestId };
  if (step.sender) Object.assign(headers, kit.signServiceRequest({ key: eventKeys[step.sender], method: step.method, path: routePath, body: JSON.stringify(step.body), nowSeconds: Math.floor(now / 1000) }));
  if (step.key) headers['idempotency-key'] = step.key;
  let response;
  await router({
    req: {
      method: step.method,
      path: routePath,
      headers,
      queryString: query,
      bodyText: 'body' in step ? JSON.stringify(step.body) : '',
    },
    res: { json: (body, status) => (response = { status, body }) },
  });
  // Only the server-generated deletion request UUID is volatile in this scenario.
  if (routePath === '/v1/me/deletion' && response.status === 202) {
    deletionRequestId = response.body.requestId;
    response.body = { ...response.body, requestId: '$deletion-request-id' };
  }
  results.push({ index, kind: 'call', ...response });
}

function sourceFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? sourceFiles(file) : file.endsWith('.ts') ? [file] : [];
  });
}
const hash = createHash('sha256');
for (const { file, relative } of [
  ...sourceFiles(path.join(root, 'services/progress/src')),
  ...sourceFiles(path.join(root, 'services/shared/src')),
]
  .map((file) => ({ file, relative: path.relative(root, file).split(path.sep).join('/') }))
  .sort((a, b) => (a.relative < b.relative ? -1 : a.relative > b.relative ? 1 : 0)))
  hash.update(relative).update('\0').update(fs.readFileSync(file)).update('\0');
const output =
  JSON.stringify(
    {
      nodeSourceSha256: hash.digest('hex'),
      scenarioSha256: createHash('sha256').update(scenarioBytes).digest('hex'),
      results,
    },
    null,
    2,
  ) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(outputPath) || fs.readFileSync(outputPath, 'utf8') !== output)
    throw new Error('Progress Node parity fixture is stale; regenerate and review the diff.');
} else fs.writeFileSync(outputPath, output);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'Node Progress fixture only; no durable parity admission',
    steps: results.length,
    mode: process.argv.includes('--check') ? 'check' : 'write',
  }),
);
