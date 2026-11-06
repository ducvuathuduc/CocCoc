import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { root } from './kit.mjs';

test('removes a generated test bundle when its owning process exits', () => {
  const outfile = path.join(root, '.cache/shared-tests', `cleanup-${process.pid}.mjs`);
  const cleanupUrl = new URL('./cleanup-generated-bundle.mjs', import.meta.url).href;
  const script = [
    `import { writeFileSync } from 'node:fs';`,
    `import { cleanupGeneratedBundleOnExit } from ${JSON.stringify(cleanupUrl)};`,
    `const outfile = ${JSON.stringify(outfile)};`,
    `writeFileSync(outfile, 'test bundle');`,
    `cleanupGeneratedBundleOnExit(outfile);`,
  ].join('\n');

  const result = spawnSync(process.execPath, ['--input-type=module', '--eval', script], {
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(outfile), false, 'the child process should remove its bundle at exit');
});
