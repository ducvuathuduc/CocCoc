import assert from 'node:assert/strict';

// Read-only smoke for the no-credential Compose profile. This is not admission.
for (const [service, port] of [
  ['learning', 4101],
  ['progress', 4102],
  ['ai', 4103],
]) {
  const base = `http://127.0.0.1:${port}`;
  let health;
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      health = await fetch(`${base}/health`, { signal: AbortSignal.timeout(2000) });
      if (health.ok) break;
    } catch {
      /* Wait for the container to listen, never for business admission. */
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  assert.equal(health?.status, 200, `${service} liveness`);
  const body = await health.json();
  assert.equal(body.service, service);
  const ready = await fetch(`${base}/ready`, { signal: AbortSignal.timeout(2000) });
  assert.ok([401, 503].includes(ready.status), `${service} unconfigured readiness must be closed`);
  const privateResponse = await fetch(`${base}/v1/me`, {
    headers: { 'x-appwrite-trigger': 'schedule', 'x-appwrite-key': 'untrusted-test-value' },
    signal: AbortSignal.timeout(2000),
  });
  assert.notEqual(
    privateResponse.status,
    200,
    `${service} spoofed platform headers cannot admit private data`,
  );
  process.stdout.write(
    `${JSON.stringify({ service, health: health.status, ready: ready.status, private: privateResponse.status })}\n`,
  );
}
