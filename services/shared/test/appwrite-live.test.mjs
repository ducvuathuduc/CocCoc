import test from 'node:test';
import assert from 'node:assert/strict';

// Gated live probe (P1-FOUND-002 cloud half). Never runs in deterministic CI: it needs an
// admitted Appwrite project, a real short-lived user JWT and network access.
const enabled = process.env.COC_LIVE_APPWRITE_PROBE === '1';
const reason =
  'live Appwrite Account.get probe gated: set COC_LIVE_APPWRITE_PROBE=1 with COC_PROBE_ENDPOINT, COC_PROBE_PROJECT, COC_PROBE_JWT';

test(
  'live: valid JWT maps to Account.get subject; tampered JWT is rejected',
  { skip: enabled ? false : reason },
  async () => {
    const { createAccountVerifier, createAppwriteAuthPort } =
      await import('../../../.cache/backend-fixtures/foundation-testkit.mjs');
    const endpoint = process.env.COC_PROBE_ENDPOINT;
    const project = process.env.COC_PROBE_PROJECT;
    const jwt = process.env.COC_PROBE_JWT;
    assert.ok(endpoint && project && jwt, reason);
    const port = createAppwriteAuthPort(createAccountVerifier(endpoint, project));
    const subject = await port.verify(jwt);
    assert.match(subject.userId, /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/);
    await assert.rejects(port.verify(`${jwt.slice(0, -2)}xx`), (error) =>
      ['AUTH_EXPIRED', 'AUTH_REQUIRED'].includes(error.code),
    );
  },
);
