import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { parse } from 'yaml';

test('backend CI runs when its content, contract, toolchain and workspace inputs change', () => {
  const workflow = parse(fs.readFileSync('.github/workflows/backend.yml', 'utf8'));
  for (const event of ['push', 'pull_request']) {
    const paths = workflow.on[event].paths;
    for (const required of [
      'content/**',
      'tools/blueprint/**',
      'tools/postman/**',
      'tools/tests/dart-contract-line-endings.test.mjs',
      '.gitattributes',
      'pnpm-workspace.yaml',
      'tools/toolchain.json',
    ])
      assert.ok(paths.includes(required), `${event} missing ${required}`);
  }
  assert.deepEqual(workflow.on.push.branches, ['main']);
  const steps = workflow.jobs.deterministic.steps;
  for (const command of [
    'pnpm backend:verify',
    'pnpm backend:smoke',
    'pnpm dev:smoke',
    'pnpm contracts:check',
    'pnpm api:lint',
  ]) {
    assert.ok(
      steps.some((step) => step.run === command),
      command,
    );
  }
  const extended = steps.find((step) => step.name === 'Extended checks (manual)');
  assert.ok(extended?.if.includes("github.event_name == 'workflow_dispatch'"));
  assert.ok(extended.if.includes('inputs.extended_checks'));
  assert.ok(
    extended.run.includes('node tools/scripts/local-load.mjs --requests=100 --concurrency=10'),
  );
  for (const command of ['pnpm postman:check', 'pnpm postman:test', 'pnpm postman:run:local']) {
    assert.ok(extended.run.includes(command), command);
    assert.equal(
      steps.some((step) => step.run === command),
      false,
    );
  }
});

test('expensive container checks are manual and ordinary CI stays read-only', () => {
  const containers = parse(fs.readFileSync('.github/workflows/containers.yml', 'utf8'));
  assert.deepEqual(Object.keys(containers.on), ['workflow_dispatch']);
  for (const name of ['backend', 'mobile', 'security', 'containers']) {
    const workflow = parse(fs.readFileSync(`.github/workflows/${name}.yml`, 'utf8'));
    assert.deepEqual(workflow.permissions, { contents: 'read' });
    if (name !== 'containers') assert.deepEqual(workflow.on.push.branches, ['main']);
  }
});
