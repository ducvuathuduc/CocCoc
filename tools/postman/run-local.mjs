// Executes this repository's trusted generated collection over loopback HTTP.
// Deliberately supports only its current synchronous pm API subset; unknown APIs fail.
// This is not a general Postman sandbox or a cloud/durable acceptance runner.
import assert from 'node:assert/strict';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { startDevServices } from '../scripts/dev-services.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const jsonValue = (value) => (value === undefined ? undefined : JSON.parse(JSON.stringify(value)));

function expect(value) {
  const chain = {
    eql: (other) => assert.deepStrictEqual(jsonValue(value), jsonValue(other)),
    include: (part) =>
      assert.ok(value?.includes(part), 'Expected value to include the required item'),
    property: (key) =>
      assert.ok(value !== null && Object.hasOwn(value, key), `Missing property: ${key}`),
    a: (type) =>
      assert.equal(Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value, type),
    above: (minimum) =>
      assert.ok(typeof value === 'number' && value > minimum, 'Expected a larger number'),
  };
  chain.an = chain.a;
  for (const name of ['to', 'be', 'have']) Object.defineProperty(chain, name, { get: () => chain });
  return chain;
}

function headerList(rows = []) {
  const values = new Map(
    rows.filter((r) => !r.disabled).map((r) => [r.key.toLowerCase(), String(r.value)]),
  );
  return {
    get: (name) => values.get(name.toLowerCase()),
    remove: (name) => values.delete(name.toLowerCase()),
    upsert: ({ key, value }) => values.set(key.toLowerCase(), String(value)),
    entries: () => values.entries(),
  };
}

const cryptoAdapter = {
  enc: { Hex: { parse: (value) => Buffer.from(value, 'hex') } },
  SHA256: (value) => ({ toString: () => createHash('sha256').update(value).digest('hex') }),
  HmacSHA256: (value, key) => ({
    toString: () => createHmac('sha256', key).update(value).digest('hex'),
  }),
};

export async function executeCollection(collection, environment, options) {
  const result = {
    requests: 0,
    skippedRequests: 0,
    passedAssertions: 0,
    failedAssertions: 0,
    scriptErrors: 0,
    baselineExecuted: 0,
    baselineExpected: 0,
    records: [],
  };
  const fetchImpl = options.fetchImpl ?? fetch;
  const collectionValues = new Map((collection.variable ?? []).map((v) => [v.key, v.value]));
  const replace = (text) =>
    String(text).replace(/\{\{([^{}]+)\}\}/g, (_, key) => {
      if (key === '$guid') return randomUUID();
      const value = environment.get(key) ?? collectionValues.get(key);
      if (value === undefined) throw new Error(`Unresolved collection variable: ${key}`);
      return String(value);
    });
  async function walk(group, ancestors = [], trail = []) {
    const scopes = [...ancestors, group];
    for (const item of group.item ?? []) {
      const names = [...trail, item.name];
      if (item.item) {
        await walk(item, scopes, names);
        continue;
      }
      if (!item.request) throw new Error('Unsupported collection item');
      const baseline = item.request.description?.startsWith('OpenAPI operation:') === true;
      if (baseline) result.baselineExpected++;
      const record = { name: names.join(' / '), baseline, status: null, assertions: [] };
      result.records.push(record);
      let skipped = false;
      const request = {
        method: item.request.method,
        headers: headerList(item.request.header),
        body: item.request.body ? structuredClone(item.request.body) : undefined,
        url: {
          toString: () =>
            typeof item.request.url === 'string' ? item.request.url : item.request.url.raw,
        },
      };
      const pm = {
        request,
        environment: {
          get: (key) => environment.get(key),
          set: (key, value) => environment.set(key, String(value)),
        },
        variables: { replaceIn: replace },
        execution: {
          skipRequest: () => {
            skipped = true;
          },
        },
        expect,
        test: (name, callback) => {
          try {
            const returned = callback();
            if (returned?.then) throw new Error('Async collection tests are unsupported');
            result.passedAssertions++;
            record.assertions.push({ name, passed: true });
          } catch (error) {
            result.failedAssertions++;
            record.assertions.push({ name, passed: false, error: error.message.slice(0, 500) });
          }
        },
      };
      const context = vm.createContext(
        { pm, CryptoJS: cryptoAdapter, URL },
        {
          codeGeneration: { strings: false, wasm: false },
        },
      );
      const run = (kind) => {
        for (const scope of [...scopes, item])
          for (const event of scope.event ?? []) {
            if (event.listen !== kind) continue;
            vm.runInContext(event.script.exec.join('\n'), context, {
              timeout: 1500,
              filename: `collection-${kind}.js`,
            });
          }
      };
      try {
        run('prerequest');
        if (skipped) {
          result.skippedRequests++;
          record.skipped = true;
          continue;
        }
        const url = new URL(replace(request.url.toString()));
        if (
          url.hostname !== '127.0.0.1' ||
          url.protocol !== 'http:' ||
          url.username ||
          url.password ||
          !options.allowedOrigins.includes(url.origin)
        ) {
          throw new Error('Collection attempted a non-admitted local URL');
        }
        const response = await fetchImpl(url, {
          method: request.method,
          headers: Object.fromEntries(
            [...request.headers.entries()].map(([k, v]) => [k, replace(v)]),
          ),
          ...(request.body?.raw ? { body: replace(request.body.raw) } : {}),
          redirect: 'error',
          signal: AbortSignal.timeout(10_000),
        });
        const text = await response.text();
        result.requests++;
        if (baseline) result.baselineExecuted++;
        record.status = response.status;
        pm.response = {
          code: response.status,
          headers: response.headers,
          json: () => JSON.parse(text),
          to: { have: { status: (expected) => assert.equal(response.status, expected) } },
        };
        run('test');
      } catch (error) {
        result.scriptErrors++;
        record.error = error.message.slice(0, 500);
      }
    }
  }
  await walk(collection);
  result.baselineComplete = result.baselineExecuted === result.baselineExpected;
  result.success =
    result.failedAssertions === 0 && result.scriptErrors === 0 && result.baselineComplete;
  return result;
}

async function main() {
  if (process.argv.length > 2)
    throw new Error('This runner accepts no external URLs or environments');
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing production mode');
  Object.assign(process.env, {
    NODE_ENV: 'development',
    COC_DEV_AUTH: '1',
    COC_DEV_RELAY: '1',
    COC_DEV_PORT_BASE: '25101',
    COC_SERVICE_KEYS: '',
    COC_REPO_ROOT: root,
  });
  const running = await startDevServices(undefined, process.env);
  try {
    const collection = JSON.parse(
      fs.readFileSync(path.join(root, 'tools/postman/CocEnglish.postman_collection.json'), 'utf8'),
    );
    const publicEnv = JSON.parse(
      fs.readFileSync(
        path.join(root, 'tools/postman/CocEnglish-local.postman_environment.json'),
        'utf8',
      ),
    );
    const env = new Map(publicEnv.values.map((v) => [v.key, v.value]));
    const origins = ['learning', 'progress', 'ai'].map((owner) => {
      const origin = `http://127.0.0.1:${running.ports[owner]}`;
      env.set(`${owner}_base_url`, origin);
      return origin;
    });
    env.set('token_a', 'dev-user-a');
    env.set('token_b', 'dev-user-b');
    env.set('token_maintainer', 'dev-maintainer');
    const result = await executeCollection(collection, env, { allowedOrigins: origins });
    const destination = path.join(root, '.cache/postman-local-result.json');
    fs.writeFileSync(
      destination,
      JSON.stringify(
        {
          scope:
            'Generated collection scripts on loopback in-memory services; not Newman, cloud or durable acceptance',
          ...result,
        },
        null,
        2,
      ),
    );
    console.log(
      JSON.stringify(
        { ...result, records: undefined, report: '.cache/postman-local-result.json' },
        null,
        2,
      ),
    );
    for (const record of result.records) {
      if (record.error || record.assertions.some((a) => !a.passed))
        console.error(record.name, record.error ?? record.assertions.filter((a) => !a.passed));
    }
    if (!result.success) process.exitCode = 1;
  } finally {
    await running.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
