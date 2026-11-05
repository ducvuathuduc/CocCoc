import test from 'node:test';
import assert from 'node:assert/strict';
import {
  checkLocalLearningSmoke,
  rewardSnapshot,
  validateRestartEvidence,
  publicSummary,
} from '../scripts/local-learning-smoke.mjs';

const root = 'C:\\Users\\ADMIN\\Desktop\\CocEnglish';
const bootstrap = {
  endpoint: 'https://127.0.0.1:8443/v1',
  project: 'cocenglish-local',
  keys: { setup: 'private-server-key' },
};

test('check admits only regular local CA and exact isolated bootstrap identity', () => {
  const checked = [];
  const result = checkLocalLearningSmoke({
    root,
    platform: 'win32',
    statFile: (file) => {
      checked.push(file);
      return { isFile: () => true };
    },
    readJson: () => bootstrap,
  });
  assert.deepEqual(result, { status: 'ready', project: 'cocenglish-local' });
  assert.equal(
    checked.some((file) => file.endsWith('tls\\ca.crt')),
    true,
  );
  assert.equal(
    checked.some((file) => file.endsWith('bootstrap.json')),
    true,
  );

  for (const invalid of [
    { ...bootstrap, endpoint: 'https://cloud.appwrite.io/v1' },
    { ...bootstrap, project: 'production' },
    { ...bootstrap, keys: {} },
  ]) {
    assert.throws(
      () =>
        checkLocalLearningSmoke({
          root,
          platform: 'win32',
          statFile: () => ({ isFile: () => true }),
          readJson: () => invalid,
        }),
      /LOCAL_SMOKE_CONFIGURATION_INVALID/,
    );
  }
});

test('restart evidence requires local identity, two credentials, session and reward snapshot', () => {
  const evidence = {
    version: 1,
    endpoint: 'https://127.0.0.1:8443/v1',
    project: 'cocenglish-local',
    runId: 'abc123',
    users: [
      { id: 'lsa', email: 'lsa@cocenglish.local', password: 'private-pass-a' },
      { id: 'lsb', email: 'lsb@cocenglish.local', password: 'private-pass-b' },
    ],
    sessionId: 'session-1',
    lessonId: 'u1n1l1',
    completionId: 'session-1',
    rewards: {
      completionId: 'session-1',
      status: 'credited',
      studyXp: 25,
      leagueXp: 25,
      gems: 20,
      freezeSlots: 0,
      currentStreak: 1,
      awardXp: 25,
      revision: 1,
    },
  };
  assert.equal(validateRestartEvidence(evidence), evidence);
  assert.throws(() => validateRestartEvidence({ ...evidence, sessionId: '' }), /invalid/);
  assert.throws(
    () => validateRestartEvidence({ ...evidence, endpoint: 'https://example.com/v1' }),
    /invalid/,
  );
});

test('reward snapshots and stdout summaries never retain credentials, JWTs, or volatile time', () => {
  const rewards = rewardSnapshot({
    completionId: 'session-1',
    status: 'credited',
    studyXp: 25,
    leagueXp: 25,
    gems: 20,
    freezeSlots: 0,
    currentStreak: 1,
    awardXp: 25,
    revision: 1,
    asOf: '2026-10-26T00:00:00.000Z',
  });
  assert.equal('asOf' in rewards, false);
  const summary = publicSummary({
    runId: 'abc123',
    sessionId: 'session-1',
    completionId: 'session-1',
    rewards,
    users: [{ password: 'never-print' }],
    jwt: 'never-print-jwt',
  });
  assert.deepEqual(summary, {
    status: 'passed',
    rewardIdentity: 'session-1',
    rewardStatus: 'credited',
    awardXp: 25,
    studyXp: 25,
    revision: 1,
  });
  assert.equal(JSON.stringify(summary).includes('never-print'), false);
});
