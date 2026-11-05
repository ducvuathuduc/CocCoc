import test from 'node:test';
import assert from 'node:assert/strict';
import {
  checkLocalAuthSmoke,
  findRecipientMessage,
  parseCallbackParameters,
  parseEmailOtp,
  publicAuthSummary,
} from '../scripts/local-auth-smoke.mjs';

const root = 'C:\\Users\\ADMIN\\Desktop\\CocEnglish';
const bootstrap = {
  endpoint: 'https://127.0.0.1:8443/v1',
  project: 'cocenglish-local',
  keys: { setup: 'private-server-key' },
};

test('check admits only regular local CA and exact isolated bootstrap identity', () => {
  const checked = [];
  const result = checkLocalAuthSmoke({
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
        checkLocalAuthSmoke({
          root,
          platform: 'win32',
          statFile: () => ({ isFile: () => true }),
          readJson: () => invalid,
        }),
      /LOCAL_AUTH_SMOKE_CONFIGURATION_INVALID/,
    );
  }
});

test('Mailpit selection requires a new message for the exact synthetic recipient', () => {
  const messages = [
    { ID: 'old', To: [{ Address: 'run@cocenglish.local' }] },
    { ID: 'other', To: [{ Address: 'other@cocenglish.local' }] },
    { ID: 'match', To: [{ Address: 'run@cocenglish.local' }] },
  ];
  assert.equal(
    findRecipientMessage(messages, 'run@cocenglish.local', new Set(['old'])).ID,
    'match',
  );
  assert.equal(findRecipientMessage(messages, 'RUN@cocenglish.local', new Set()), undefined);
});

test('callback parser decodes Mailpit HTML and accepts only the fixed local callback', () => {
  const message = {
    Text: '',
    HTML: '<a href="https://127.0.0.1:8443/auth/verify-email?userId=user-1&amp;secret=private-secret&amp;expire=soon">Verify</a>',
  };
  assert.deepEqual(parseCallbackParameters(message, '/auth/verify-email'), {
    userId: 'user-1',
    secret: 'private-secret',
  });
  assert.throws(
    () =>
      parseCallbackParameters(
        { Text: 'https://example.com/auth/verify-email?userId=user-1&secret=secret' },
        '/auth/verify-email',
      ),
    /AUTH_MESSAGE_CALLBACK_MISSING/,
  );
});

test('email OTP parser accepts one six-digit code and rejects ambiguous bodies', () => {
  assert.equal(
    parseEmailOtp({
      Text: 'Your security code is 123456.',
      HTML: '<style>color:#654321</style><p>Your security code is 123456.</p>',
    }),
    '123456',
  );
  assert.throws(
    () => parseEmailOtp({ Text: 'Codes 123456 and 654321' }),
    /AUTH_MESSAGE_OTP_INVALID/,
  );
});

test('public summary exposes proof booleans and provider blocker only', () => {
  const summary = publicAuthSummary({
    emailVerification: true,
    passwordRecovery: true,
    emailOtp: false,
    emailOtpBlocker: 'provider_disabled',
    email: 'private@cocenglish.local',
    password: 'private-password',
    secret: 'private-secret',
  });
  assert.deepEqual(summary, {
    status: 'passed_with_provider_blocker',
    emailVerification: true,
    passwordRecovery: true,
    emailOtp: false,
    emailOtpBlocker: 'provider_disabled',
    callbackUiVerified: false,
    publicDeliverabilityVerified: false,
  });
  assert.equal(JSON.stringify(summary).includes('private'), false);
});
