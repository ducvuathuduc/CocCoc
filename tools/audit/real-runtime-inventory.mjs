import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const folder = 'docs/quality/real-features-20261025';
const files = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'])
  .toString()
  .split('\0')
  .filter((file) => file.startsWith('apps/mobile/lib/') && file.endsWith('.dart'));
const sources = [...new Set(files)]
  .filter((file) => !file.includes('/generated/') && !file.endsWith('.g.dart'))
  .map((path) => ({ path, source: readFileSync(path, 'utf8') }));
const specBytes = readFileSync('docs/api/openapi.yaml');
const spec = JSON.parse(specBytes);
const operations = Object.entries(spec.paths).flatMap(([path, item]) =>
  Object.entries(item)
    .filter(
      ([method, op]) =>
        ['get', 'post', 'put', 'patch', 'delete'].includes(method) && op.operationId,
    )
    .map(([method, op]) => ({ operationId: op.operationId, owner: op['x-owner'], method, path })),
);
const routeSource = readFileSync('apps/mobile/lib/main.dart', 'utf8');
const routes = [...routeSource.matchAll(/\bpath:\s*'([^']+)'/g)].map((match) => ({
  route: match[1],
  line: routeSource.slice(0, match.index).split('\n').length,
}));
const actions = operations.map((operation) => {
  const evidence = sources
    .filter(({ source }) => new RegExp(`\\b${operation.operationId}\\s*\\(`).test(source))
    .map(({ path }) => path);
  const excluded = new Set([
    'verifyPurchase',
    'billingNotification',
    'sendGift',
    'redeemGift',
    'recordAdEvent',
  ]).has(operation.operationId);
  return {
    actionId: `api.${operation.operationId}`,
    route: null,
    owner: operation.owner,
    operationIds: [operation.operationId],
    method: operation.method.toUpperCase(),
    path: operation.path,
    currentSource: evidence.length
      ? 'api adapter; UI binding requires acceptance'
      : 'no mobile call found',
    implementationEvidence: evidence,
    uiEvidence: ['docs/design/qa/FLOW_CHECKLIST.md'],
    acceptance: [
      'verified JWT',
      'owner receipt',
      'duplicate/retry',
      'account switch',
      'unchanged reference state',
    ],
    runtimeStatus: excluded
      ? 'EXCLUDED'
      : evidence.length
        ? 'UNVERIFIED'
        : 'MISSING_IMPLEMENTATION',
    liveEvidence: [],
  };
});
const managed = [
  ['auth.login', '/login', 'apps/mobile/lib/features/auth/services/appwrite_auth_service.dart'],
  ['auth.emailOtp', '/login', 'apps/mobile/lib/features/auth/services/appwrite_auth_service.dart'],
  [
    'auth.recovery',
    '/reset-password',
    'apps/mobile/lib/features/auth/services/appwrite_auth_service.dart',
  ],
  [
    'auth.restoreLogout',
    '/login',
    'apps/mobile/lib/features/auth/application/auth_controller.dart',
  ],
  [
    'auth.socialOAuth',
    '/login',
    'apps/mobile/lib/features/auth/services/appwrite_auth_service.dart',
  ],
  [
    'os.lessonActivity',
    '/activity/resume',
    'apps/mobile/lib/features/learning/services/lesson_activity_gateway.dart',
  ],
  ['os.streakWidget', null, 'apps/mobile/lib/features/reminders/domain/streak_home_widget.dart'],
  [
    'os.reminders',
    null,
    'apps/mobile/lib/features/reminders/application/reminder_coordinator.dart',
  ],
  [
    'local.appearance',
    null,
    'apps/mobile/lib/features/appearance/application/appearance_controller.dart',
  ],
];
for (const [actionId, route, path] of managed) {
  actions.push({
    actionId,
    route,
    owner: actionId.startsWith('auth.') ? 'Appwrite Auth' : 'device',
    operationIds: [],
    currentSource: 'SDK/native adapter; credentials and device unverified',
    implementationEvidence: existsSync(path) ? [path] : [],
    uiEvidence: ['docs/design/qa/FLOW_CHECKLIST.md'],
    acceptance: [
      'configuration',
      'denied/offline',
      'account switch',
      'actual device/provider receipt',
    ],
    runtimeStatus: existsSync(path) ? 'UNVERIFIED' : 'MISSING_IMPLEMENTATION',
    liveEvidence: [],
  });
}
const callbacks = sources.flatMap(({ path, source }) =>
  source
    .split('\n')
    .flatMap((line, i) =>
      /\b(onPressed|onTap|onChanged|onSubmitted|onSelected|onLongPress):/.test(line)
        ? [{ path, line: i + 1, binding: line.trim(), runtimeStatus: 'UNVERIFIED' }]
        : [],
    ),
);
const providers = sources.flatMap(({ path, source }) =>
  [...source.matchAll(/\b(?:final|const)\s+(\w+Provider)\s*=/g)].map((match) => ({
    name: match[1],
    path,
    line: source.slice(0, match.index).split('\n').length,
  })),
);
const coverage = JSON.parse(readFileSync('docs/design/qa/FLOW_COVERAGE.json', 'utf8'));
const findings = JSON.parse(readFileSync(`${folder}/runtime-findings.json`, 'utf8'));
for (const finding of findings.actions)
  actions.push({
    ...finding,
    liveEvidence: [],
  });
const result = {
  generatedAt: new Date().toISOString(),
  contractSha256: createHash('sha256').update(specBytes).digest('hex'),
  discoveryLimits:
    'Lexical inventory is complete for listed syntax, not a claim of exhaustive reachable behavior. Each callback still needs semantic route/action mapping and live acceptance. Flow mock marks are never promoted to live.',
  actions,
  reviewedAt: findings.reviewedAt,
  routes,
  providers,
  callbacks,
  flowFamilies: coverage.families.map((family) => ({
    id: family.id,
    visualStatus: family.status,
    runtimeStatus: 'UNVERIFIED',
  })),
};
const ids = new Set();
for (const action of actions) {
  if (ids.has(action.actionId)) throw new Error(`Duplicate ${action.actionId}`);
  ids.add(action.actionId);
  for (const file of action.implementationEvidence)
    if (!existsSync(file)) throw new Error(`Missing ${file}`);
  for (const file of action.localEvidence ?? [])
    if (!existsSync(file)) throw new Error(`Missing evidence ${file}`);
  for (const id of action.operationIds)
    if (!operations.some((op) => op.operationId === id)) throw new Error(`Unknown operation ${id}`);
}
writeFileSync(`${folder}/runtime-register.json`, `${JSON.stringify(result, null, 2)}\n`);
process.stdout.write(
  `Inventoried ${operations.length} operations, ${routes.length} routes, ${providers.length} providers, ${callbacks.length} callback bindings; semantic acceptance pending.\n`,
);
