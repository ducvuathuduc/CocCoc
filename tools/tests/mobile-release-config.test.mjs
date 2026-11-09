import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'yaml';

// Release builds keep config/real.public.json, and the API lane (a test lane) never replaces it.
const read = (file) => fs.readFileSync(file, 'utf8');
const REAL = '--dart-define-from-file=config/real.public.json';
const workflows = fs
  .readdirSync('.github/workflows')
  .filter((name) => name.endsWith('.yml'))
  .map((name) => ({ name, text: read(path.join('.github/workflows', name)) }));

test('every workflow that builds an app builds it from the real public profile', () => {
  const builds = workflows.flatMap(({ name, text }) =>
    text
      .split('\n')
      .filter((line) => /flutter\s+build\s+(apk|appbundle|ios|ipa)\b/.test(line))
      .map((line) => ({ name, line: line.trim() })),
  );
  assert.ok(builds.length >= 3, 'debug APK, iOS simulator and release APK builds are declared');
  for (const { name, line } of builds) assert.ok(line.includes(REAL), `${name}: ${line}`);
  assert.ok(
    builds.some(({ line }) => line.includes('--release')),
    'a release-mode build exists and carries the real profile',
  );
});

test('the local build script that ships an APK also uses the real profile', () => {
  const script = read('tools/scripts/mobile-check.mjs');
  const block = script.slice(script.indexOf("'Flutter Android debug build'"));
  assert.ok(block.includes("'--dart-define-from-file=config/real.public.json'"));
});

test('the real public profile is a valid release profile', () => {
  const profile = JSON.parse(read('apps/mobile/config/real.public.json'));
  assert.equal(profile.DATA_SOURCE, 'api');
  assert.equal(profile.USE_MOCK_AUTH, 'false');
  assert.notEqual(profile.ALLOW_INSECURE_LOCAL_ENDPOINTS, 'true');
  for (const key of ['APPWRITE_ENDPOINT', 'LEARNING_API_URL', 'PROGRESS_API_URL', 'AI_API_URL']) {
    const url = new URL(profile[key]);
    assert.equal(url.protocol, 'https:', key);
    assert.doesNotMatch(url.hostname, /^(localhost|127\.|10\.|192\.168\.)|\.invalid$/, key);
  }
  assert.doesNotMatch(read('apps/mobile/config/real.public.json'), /10\.0\.2\.2/);
});

test('the API lane passes its own defines and never touches the real profile', () => {
  for (const file of ['tools/scripts/mobile-api-lane.mjs', 'tools/scripts/api-lane-backend.mjs']) {
    const code = read(file)
      .split('\n')
      .filter((line) => !line.trimStart().startsWith('//'))
      .join('\n');
    assert.doesNotMatch(code, /real\.public\.json/, file);
    assert.doesNotMatch(code, /config\/(?!state)/, file);
  }
  const lane = read('tools/scripts/mobile-api-lane.mjs');
  for (const define of ['DATA_SOURCE=api', 'LEARNING_API_URL=', 'USE_MOCK_AUTH=false']) {
    assert.ok(lane.includes(`--dart-define=${define}`), define);
  }
});

test('the mock suite stays in mobile.yml and the API lane is a separate workflow', () => {
  const mobile = parse(read('.github/workflows/mobile.yml'));
  const verify = mobile.jobs.linux.steps.find((step) => step.id === 'verify');
  assert.equal(verify.run, 'node tools/scripts/mobile-check.mjs');
  const lane = parse(read('.github/workflows/mobile-api.yml'));
  assert.notDeepEqual(Object.keys(lane.jobs), Object.keys(mobile.jobs));
  assert.deepEqual(lane.permissions, { contents: 'read' });
  assert.deepEqual(lane.on.push.branches, ['main']);
  assert.ok(
    lane.jobs['api-lane'].steps.some(
      (step) => step.run === 'node tools/scripts/mobile-api-lane.mjs',
    ),
  );
  assert.ok(lane.on.pull_request.paths.includes('services/learning/**'));
  assert.ok(lane.on.pull_request.paths.includes('apps/mobile/**'));
});

test('every workflow installs the Flutter version the repository pins', () => {
  const pinned = JSON.parse(read('tools/toolchain.json')).flutter;
  const lock = read('apps/mobile/pubspec.lock');
  assert.match(lock, new RegExp(`flutter: ">=${pinned.replaceAll('.', '\\.')}"`));
  const using = workflows.filter(({ text }) => text.includes('FLUTTER_VERSION:'));
  assert.ok(using.length >= 3);
  for (const { name, text } of using) {
    assert.match(text, new RegExp(`FLUTTER_VERSION: ${pinned.replaceAll('.', '\\.')}\\b`), name);
  }
});
