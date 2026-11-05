import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { kit } from './kit.mjs';

test('family/referral codes require an explicit secret and reject removed or short configuration', () => {
  const secret = 'synthetic-test-only-secret-value';
  kit.setCodeSecret(secret);
  const first = kit.derivedCode('family', 'group-1');
  assert.equal(kit.derivedCode('family', 'group-1'), first);
  assert.notEqual(kit.derivedCode('family', 'group-2'), first);
  for (const invalid of [undefined, '', 'short']) {
    kit.setCodeSecret(invalid);
    assert.throws(() => kit.derivedCode('family', 'group-1'), { code: 'SERVICE_NOT_CONFIGURED' });
  }
  kit.setCodeSecret(secret);
  assert.equal(kit.derivedCode('family', 'group-1'), first);
});

test('hosted Progress bundles never include the public dev code secret', () => {
  for (const entry of ['function', 'http', 'worker']) {
    assert.doesNotMatch(
      fs.readFileSync(`services/progress/dist/${entry}.mjs`, 'utf8'),
      /cocenglish-dev-only-code-secret/,
    );
  }
});
