import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const backendDirectory = path.resolve(scriptDirectory, '..');
const repositoryDirectory = path.resolve(backendDirectory, '..');
const testsDirectory = path.join(backendDirectory, 'tests');
const fixturesDirectory = path.join(testsDirectory, 'fixtures');
const matrix = readJson(path.join(backendDirectory, 'migration/operations.json'));
const scenarioFiles = {
  progress: path.join(fixturesDirectory, 'progress-parity-scenarios.json'),
  learning: path.join(fixturesDirectory, 'learning-parity-scenarios.json'),
  ai: path.join(fixturesDirectory, 'ai-parity-scenarios.json'),
};
const scenarios = Object.fromEntries(
  Object.entries(scenarioFiles).map(([owner, file]) => [owner, readJson(file)]),
);
const testFiles = collectFiles(testsDirectory, '.cs');
const testSources = testFiles.map((file) => ({ file, source: fs.readFileSync(file, 'utf8') }));
const errors = [];
const covered = new Set();
const supplemental = [
  {
    operationId: 'completeSession',
    fixture: 'completionParity',
    differentialTest: 'LearningNodeParityTests.AuthoredModeCompletionsMatchNodeResponsesAndEffects',
    generatorSource: 'tools/generate-learning-parity.mjs',
    generatorMarker: '/v1/sessions/${testCase.sessionId}/complete',
  },
  {
    operationId: 'publishContent',
    fixture: 'publication',
    differentialTest: 'LearningManifestTests.Publish_MatchesNodeResponsesAndOwnerRows',
    generatorSource: 'tools/generate-learning-parity.mjs',
    generatorMarker: '/v1/admin/content-versions',
  },
  {
    operationId: 'runLearningOutboxDispatch',
    fixture: 'dispatchJob',
    differentialTest: 'LearningNodeParityTests.SignedOutboxDispatchHttpMatchesNodeResponseAndRow',
    generatorSource: 'tools/generate-learning-parity.mjs',
    generatorMarker: '/internal/jobs/learning-outbox-dispatch',
  },
];

if (!Array.isArray(matrix.operations) || matrix.operations.length !== 91) {
  errors.push(
    `Expected 91 operations in the migration matrix; found ${matrix.operations?.length ?? 'none'}.`,
  );
}

const operationIds = new Set();
const routeKeys = new Set();
for (const operation of matrix.operations ?? []) {
  if (operationIds.has(operation.operationId))
    errors.push(`Duplicate operationId: ${operation.operationId}`);
  operationIds.add(operation.operationId);
  const routeKey = `${operation.owner} ${operation.method} ${operation.path}`;
  if (routeKeys.has(routeKey)) errors.push(`Duplicate owner route: ${routeKey}`);
  routeKeys.add(routeKey);
  if (operation.status !== 'implemented-local-tests') {
    errors.push(`${operation.operationId} is not marked implemented-local-tests.`);
  }
  if (!Array.isArray(operation.tests) || operation.tests.length === 0) {
    errors.push(`${operation.operationId} has no local test references.`);
    continue;
  }
  for (const testReference of operation.tests) {
    if (!testReferenceExists(testReference))
      errors.push(`${operation.operationId} references missing test ${testReference}.`);
  }
}

for (const [owner, scenario] of Object.entries(scenarios)) {
  for (const step of scenario.steps ?? []) {
    for (const operation of matrix.operations.filter((candidate) => candidate.owner === owner)) {
      if (operation.method === step.method && routeMatches(operation.path, step.path)) {
        covered.add(operation.operationId);
      }
    }
  }
}

for (const item of supplemental) {
  const operation = matrix.operations.find(
    (candidate) => candidate.operationId === item.operationId,
  );
  if (!operation) {
    errors.push(`Supplemental coverage references missing operation ${item.operationId}.`);
    continue;
  }
  if (!scenarios.learning[item.fixture])
    errors.push(`${item.operationId} is missing Learning fixture '${item.fixture}'.`);
  if (
    operation.method !== 'POST' ||
    !routeMatches(
      operation.path,
      item.generatorMarker.replace('${testCase.sessionId}', '{sessionId}'),
    )
  ) {
    errors.push(`${item.operationId} no longer matches its declared supplemental route.`);
  }
  if (!(operation.tests ?? []).includes(item.differentialTest)) {
    errors.push(
      `${item.operationId} does not reference its differential test ${item.differentialTest}.`,
    );
  }
  const generatorFile = path.join(backendDirectory, item.generatorSource);
  if (
    !fs.existsSync(generatorFile) ||
    !fs.readFileSync(generatorFile, 'utf8').includes(item.generatorMarker)
  ) {
    errors.push(`${item.operationId} no longer uses the expected Node generator route.`);
  }
  if (!testReferenceExists(item.differentialTest)) {
    errors.push(`${item.operationId} differential test is missing: ${item.differentialTest}.`);
  }
  covered.add(item.operationId);
}

for (const operation of matrix.operations ?? []) {
  if (!covered.has(operation.operationId))
    errors.push(`${operation.operationId} has no Node/.NET fixture route coverage.`);
}

const report = {
  status: errors.length === 0 ? 'PASS' : 'FAIL',
  operations: matrix.operations?.length ?? 0,
  routesCovered: covered.size,
  steps: Object.fromEntries(
    Object.entries(scenarios).map(([owner, scenario]) => [owner, scenario.steps?.length ?? 0]),
  ),
  supplementalRoutes: supplemental.length,
  testReferences: (matrix.operations ?? []).reduce(
    (total, operation) => total + (operation.tests?.length ?? 0),
    0,
  ),
  missing: errors,
};
console.log(JSON.stringify(report, null, 2));
if (errors.length > 0) process.exitCode = 1;

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function collectFiles(directory, extension) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory())
      return ['bin', 'obj'].includes(entry.name) ? [] : collectFiles(file, extension);
    return entry.isFile() && file.endsWith(extension) ? [file] : [];
  });
}

function testReferenceExists(reference) {
  const parts = reference.split('.');
  const className = parts.at(-2);
  const methodName = parts.at(-1);
  const escapedMethod = escapeRegex(methodName);
  return testSources.some(
    ({ source }) =>
      new RegExp(`\\bclass\\s+${escapeRegex(className)}\\b`).test(source) &&
      new RegExp(`\\b${escapedMethod}\\s*\\(`).test(source),
  );
}

function routeMatches(template, route) {
  const escaped = escapeRegex(template).replace(/\\\{[^}]+\\\}/g, '[^/]+');
  return new RegExp(`^${escaped}$`).test(route);
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
