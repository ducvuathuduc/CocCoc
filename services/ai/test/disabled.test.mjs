import test from 'node:test';
import assert from 'node:assert/strict';
import learning from '../../learning/dist/function.mjs';
import progress from '../../progress/dist/function.mjs';
import ai from '../dist/function.mjs';
for (const [name, handler] of [
  ['learning', learning],
  ['progress', progress],
  ['ai', ai],
]) {
  async function request(path, headers = {}) {
    return handler({
      req: { method: 'GET', path, headers },
      res: {
        json: (body, status, responseHeaders) => ({ body, status, headers: responseHeaders }),
      },
    });
  }
  test(`${name}: health identifies package while privileged readiness fails closed`, async () => {
    const health = await request('/health', { 'x-request-id': 'bad\r\nheader' });
    assert.equal(health.body.service, name);
    assert.equal(health.body.status, 'degraded');
    assert.equal(health.status, 200);
    assert.match(health.headers['X-Request-ID'], /^[0-9a-f-]{36}$/);
    assert.equal((await request('/ready')).status, 401);
  });
  test(`${name}: unsupported business route cannot return fake success`, async () => {
    const response = await request('/v1/voice-sessions');
    assert.equal(response.status, 503);
    assert.equal(response.body.error.code, 'SERVICE_NOT_CONFIGURED');
  });
}
