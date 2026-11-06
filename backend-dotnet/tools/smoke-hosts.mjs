import assert from 'node:assert/strict';

// This gate proves process liveness and fail-closed hosting only. It does not
// admit Appwrite persistence, migrated business behavior or background workers.
for (const [service, port] of [
  ['learning', 5101],
  ['progress', 5102],
  ['ai', 5103],
]) {
  const base = `http://127.0.0.1:${port}`;
  const health = await fetch(`${base}/health`, { signal: AbortSignal.timeout(5000) });
  assert.equal(health.status, 200);
  const body = await health.json();
  assert.equal(body.service, service);
  assert.equal(body.status, 'degraded');
  assert.equal(typeof body.buildId, 'string');
  const operation =
    service === 'progress'
      ? '/v1/me'
      : service === 'learning'
        ? '/v1/courses'
        : '/v1/voice-sessions';
  const closed = await fetch(`${base}${operation}`, {
    method: service === 'ai' ? 'POST' : 'GET',
    signal: AbortSignal.timeout(5000),
  });
  assert.equal(closed.status, 503);
  assert.equal((await closed.json()).error.code, 'SERVICE_NOT_CONFIGURED');
  const ready = await fetch(`${base}/ready`, { signal: AbortSignal.timeout(5000) });
  assert.notEqual(ready.status, 200);
  console.log(
    JSON.stringify({
      service,
      liveness: 'PASS',
      unconfigured: 'closed',
      readiness: 'not-admitted',
    }),
  );
}
