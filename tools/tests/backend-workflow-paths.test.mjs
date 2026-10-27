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
      'tools/tests/dart-contract-line-endings.test.mjs',
      '.gitattributes',
      'pnpm-workspace.yaml',
      'tools/toolchain.json',
    ])
      assert.ok(paths.includes(required), `${event} missing ${required}`);
  }
  assert.ok(
    workflow.jobs.deterministic.steps.some(
      (step) => step.run === 'node tools/scripts/local-load.mjs --requests=100 --concurrency=10',
    ),
    'bounded local load smoke is missing',
  );
});
