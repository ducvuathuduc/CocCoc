import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { build } from 'esbuild';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const bundle = path.join(root, `.cache/progress-test/chest-${process.pid}.mjs`);
const output = path.join(root, 'backend-dotnet/tests/fixtures/quest-chest-node-golden.json');
// Substitute only the entropy import used by quest-chest in this isolated test bundle.
// All route, reward, receipt and persistence code is the actual Node implementation.
await build({
  entryPoints: [path.join(root, 'services/progress/src/testing/testkit.ts')],
  outfile: bundle,
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  logLevel: 'error',
  banner: {
    js: "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);",
  },
  plugins: [
    {
      name: 'test-chest-entropy',
      setup(build) {
        build.onResolve({ filter: /^node:crypto$/ }, (args) =>
          args.importer.replaceAll('\\', '/').endsWith('/domain/quest-chest.ts')
            ? { path: 'chest-entropy', namespace: 'test-chest' }
            : undefined,
        );
        build.onLoad({ filter: /.*/, namespace: 'test-chest' }, () => ({
          contents:
            'export function randomBytes(size) { if(size !== 12) throw Error("Unexpected entropy size"); return Buffer.from(globalThis.__testChestHex, "hex"); }',
          loader: 'js',
        }));
      },
    },
  ],
});
try {
  const kit = await import(pathToFileURL(bundle).href);
  const cases = [];
  const now = Date.parse('2026-11-05T10:00:00.000Z');
  for (let mask = 0; mask < 8; mask++) {
    const bytes = Array.from({ length: 12 }, (_, i) => (i < 3 ? (mask & (1 << i) ? 63 : 64) : 255));
    globalThis.__testChestHex = Buffer.from(bytes).toString('hex');
    const store = kit.createMemoryProgressPersistence(() => now, { strictSchema: true });
    const wiring = kit.progressWiring(store);
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
        nowMs: () => now,
      }),
    );
    async function call(route, key) {
      let response;
      await router({
        req: {
          method: 'POST',
          path: route,
          queryString: '',
          headers: {
            authorization: 'Bearer alice',
            'x-request-id': 'chest-parity',
            ...(key ? { 'idempotency-key': key } : {}),
          },
          bodyText: route.includes('/quests/')
            ? JSON.stringify({ periodKey: '2026-11-05', upgradeChest: true })
            : '',
        },
        res: {
          json(body, status) {
            response = { status, body };
          },
        },
      });
      return response;
    }
    const initialized = await call('/v1/me/initialize', '33333333-3333-4333-8333-333333333333');
    if (initialized.status !== 200) throw Error(JSON.stringify(initialized));
    await store.transact(async (tx) =>
      tx.put('p_quests', kit.ids.quest('alice', 'DAY', '2026-11-05', 'daily_lessons'), {
        userId: 'alice',
        questId: 'daily_lessons',
        period: 'DAY',
        periodKey: '2026-11-05',
        metricValue: 2,
        target: 2,
        claimed: false,
        claimOperationId: null,
      }),
    );
    const responses = [];
    for (const key of [
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    ])
      responses.push(await call('/v1/quests/daily_lessons/claim', key));
    if (responses.some((r) => r.status !== 200)) throw Error(JSON.stringify(responses));
    const tables = Object.fromEntries(
      ['p_quests', 'p_rewards', 'p_reward_ledger', 'p_activity', 'p_receipts'].map((table) => [
        table,
        store
          .dump(table)
          .sort((a, b) => a.id.localeCompare(b.id))
          .map(({ id, row }) => {
            row = structuredClone(row);
            if (typeof row.responseJson === 'string')
              row.responseJson = JSON.parse(row.responseJson);
            return { id, row };
          }),
      ]),
    );
    cases.push({ operation: `ch1_${globalThis.__testChestHex}`, responses, tables });
  }
  const files = [
    'services/progress/src/domain/quest-chest.ts',
    'services/progress/src/application/economy.ts',
    'services/progress/src/http/routes.ts',
  ];
  const nodeSourceSha256 = createHash('sha256')
    .update(files.map((p) => fs.readFileSync(path.join(root, p))).join('\0'))
    .digest('hex');
  const text = JSON.stringify({ nodeSourceSha256, cases }, null, 2) + '\n';
  if (process.argv.includes('--check')) {
    if (fs.readFileSync(output, 'utf8') !== text) throw Error('Chest fixture is stale');
  } else fs.writeFileSync(output, text);
  console.log(
    JSON.stringify({
      status: 'PASS',
      cases: cases.length,
      scope: 'local controlled-entropy chest routes and persisted rows',
    }),
  );
} finally {
  delete globalThis.__testChestHex;
  fs.rmSync(bundle, { force: true });
}
