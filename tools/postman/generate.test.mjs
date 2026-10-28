import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { buildArtifacts } from './generate.mjs';
import { executeCollection } from './run-local.mjs';
import { correctAnswer } from '../../services/learning/test/helpers/answers.mjs';

test('the generated session response captures a correct plan for every authored exercise', async () => {
  const artifacts = buildArtifacts();
  const folder = artifacts.collection.item
    .find((i) => i.name === 'Learning')
    .item.find((i) => i.name.startsWith('Golden path'));
  const start = folder.item.find((i) => i.name === 'Start lesson session');
  const environment = JSON.parse(artifacts.localEnvironmentText);
  const env = new Map(environment.values.map((v) => [v.key, v.value]));
  env.set('token_a', 'dev-user-a');
  const bundle = JSON.parse(
    fs.readFileSync('apps/mobile/test/fixtures/api/lesson_bundle_u1n1l1.json', 'utf8'),
  );
  const text = bundle.exercises.find((exercise) => exercise.type === 'textTranslation');
  const choice = bundle.exercises.find((exercise) => exercise.type === 'choice');
  for (const type of ['speakRepeat', 'dialogueTurn', 'dictation', 'imageChoice', 'storyQuestion']) {
    if (bundle.exercises.some((exercise) => exercise.type === type)) continue;
    const template = ['imageChoice', 'storyQuestion'].includes(type) ? choice : text;
    bundle.exercises.push({ ...template, id: `test-${type}`, type });
  }
  assert.equal(new Set(bundle.exercises.map((exercise) => exercise.type)).size, 12);
  const result = await executeCollection({ item: [start] }, env, {
    allowedOrigins: ['http://127.0.0.1:4101'],
    fetchImpl: async () =>
      Response.json({ sessionId: 'session-1', revision: 0, lessonVersion: 'v2', bundle }),
  });
  assert.equal(result.success, true, JSON.stringify(result.records));
  assert.equal(env.get('sessionId'), 'session-1');
  assert.deepEqual(
    JSON.parse(env.get('sessionAnswers')),
    bundle.exercises.map((exercise) => ({
      exerciseId: exercise.id,
      answer: correctAnswer(exercise),
    })),
  );
});
