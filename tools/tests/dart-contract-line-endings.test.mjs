import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

test('contract check accepts CRLF checkout but still detects changed generated code', (t) => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-contract-'));
  t.after(() => {
    const target = fs.realpathSync(temp);
    assert.equal(path.dirname(target), fs.realpathSync(os.tmpdir()));
    assert.ok(path.basename(target).startsWith('coc-contract-'));
    fs.rmSync(target, { recursive: true, force: true });
  });
  const files = [
    'tools/blueprint/generate-dart-contracts.mjs',
    'docs/api/openapi.yaml',
    'apps/mobile/lib/core/api/generated/api_models.g.dart',
    'apps/mobile/lib/core/api/generated/api_schemas.g.dart',
  ];
  for (const file of files) {
    const destination = path.join(temp, file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    const text = fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
    fs.writeFileSync(destination, text.replace(/\n/g, '\r\n'));
  }
  const script = path.join(temp, files[0]);
  const run = () => spawnSync(process.execPath, [script, '--check'], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  fs.appendFileSync(path.join(temp, files[2]), '// changed\r\n');
  assert.equal(run().status, 1);
});
