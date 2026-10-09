import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MockCompletionStore } from '../../.cache/backend-fixtures/mock-completion.mjs';
import { MockRewardStore } from '../../.cache/backend-fixtures/mock-rewards.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
const validate = ajv.compile({
  $ref: 'https://cocenglish.example.invalid/schema#/components/schemas/BusinessEvent',
});
const learning = new MockCompletionStore([
  {
    id: 'fixture-session',
    userId: 'fixture-user',
    revision: 1,
    attempted: 10,
    required: 10,
    originalCorrect: 8,
    assisted: false,
    completed: false,
  },
]);
const progress = new MockRewardStore();
const receipt = await learning.complete({
  userId: 'fixture-user',
  sessionId: 'fixture-session',
  expectedRevision: 1,
  key: randomUUID(),
});
assert.equal(progress.xp('fixture-user'), 0);
let attempts = 0;
for (const event of learning.pendingEvents()) {
  assert.equal(validate(event), true, JSON.stringify(validate.errors));
  progress.failNextCommit = true;
  try {
    attempts++;
    await progress.consume(event);
  } catch (error) {
    assert.match(error.message, /TRANSACTION_FAILED/);
  }
  assert.equal(learning.pendingEvents().length, 1);
  await new Promise((resolve) => setImmediate(resolve));
  attempts++;
  await progress.consume(event);
  // Simulate an acknowledgement loss and subsequent redelivery.
  attempts++;
  await progress.consume(event);
  learning.acknowledge(event.eventId);
}
assert.equal(progress.xp('fixture-user'), 18);
assert.equal(progress.appliedEvents, 1);
assert.equal(learning.pendingEvents().length, 0);
console.log(
  JSON.stringify(
    {
      status: 'PASS',
      mode: 'LOCAL_IN_MEMORY_FIXTURE',
      completionId: receipt.completionId,
      deliveryAttempts: attempts,
      appliedEvents: progress.appliedEvents,
      xp: progress.xp('fixture-user'),
      cloudIntegration: 'NOT_RUN',
      providerCalls: 0,
    },
    null,
    2,
  ),
);
