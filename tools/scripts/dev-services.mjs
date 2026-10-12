// `pnpm dev:services [learning|progress|ai ...]` — run the services locally in DEV MODE.
// Each service uses its real router/wiring (services/<svc>/src/dev.ts) with the explicit
// in-memory adapter: nothing is durable, /ready stays 503 (memory is never admitted), and
// user routes fail closed without an auth port. Ports: learning 4101, progress 4102, ai 4103
// (COC_DEV_PORT_BASE shifts all three). Internal HMAC uses built-in dev keys unless
// COC_SERVICE_KEYS is set. Binds 127.0.0.1 only.
import http from 'node:http';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const SERVICES = ['learning', 'progress', 'ai'];
const MAX_BODY_BYTES = 1_000_000;

export function devPorts(env = process.env) {
  const base = Number(env.COC_DEV_PORT_BASE ?? 4101);
  if (!Number.isInteger(base) || base < 1024 || base > 65533)
    throw new Error('Invalid COC_DEV_PORT_BASE.');
  return Object.fromEntries(SERVICES.map((name, index) => [name, base + index]));
}

/** Bundle the dev composition roots and the dev keyring into .cache/dev. */
export async function buildDevBundles() {
  const outdir = path.join(root, '.cache/dev');
  await build({
    entryPoints: {
      ...Object.fromEntries(SERVICES.map((name) => [name, `services/${name}/src/dev.ts`])),
      'dev-keyring': 'services/shared/src/testing/dev-keyring.ts',
      'internal-client': 'services/shared/src/internal-client.ts',
    },
    absWorkingDir: root,
    outdir,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    outExtension: { '.js': '.mjs' },
    banner: {
      js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
    },
    logLevel: 'warning',
  });
  return outdir;
}

function toFunctionContext(req, bodyText, res) {
  const url = new URL(req.url ?? '/', 'http://127.0.0.1');
  const headers = Object.fromEntries(
    Object.entries(req.headers).map(([key, value]) => [
      key,
      Array.isArray(value) ? value[0] : value,
    ]),
  );
  return {
    req: {
      method: req.method ?? 'GET',
      path: url.pathname,
      headers,
      bodyText,
      queryString: url.search.startsWith('?') ? url.search.slice(1) : '',
    },
    res: {
      json: (body, status = 200, responseHeaders = {}) => {
        res.writeHead(status, { 'Content-Type': 'application/json', ...responseHeaders });
        res.end(JSON.stringify(body));
      },
    },
  };
}

export async function startDevServices(names = SERVICES, env = process.env) {
  if (env.NODE_ENV === 'production') throw new Error('dev:services refuses NODE_ENV=production.');
  const outdir = await buildDevBundles();
  const { createDevKeyring } = await import(pathToFileURL(path.join(outdir, 'dev-keyring.mjs')));
  const keyring = createDevKeyring(env);
  const ports = devPorts(env);
  const servers = [];
  for (const name of names) {
    const { createDevHandler } = await import(pathToFileURL(path.join(outdir, `${name}.mjs`)));
    const { handler } = createDevHandler(keyring);
    const server = http.createServer((req, res) => {
      const chunks = [];
      let size = 0;
      req.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_BODY_BYTES) {
          res.writeHead(413, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: { code: 'PAYLOAD_TOO_LARGE' } }));
          req.destroy();
        } else chunks.push(chunk);
      });
      req.on('end', async () => {
        if (res.writableEnded) return;
        const bodyText = chunks.length ? Buffer.concat(chunks).toString('utf8') : undefined;
        try {
          await handler(toFunctionContext(req, bodyText, res));
        } catch (error) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: { code: 'INTERNAL_ERROR', message: String(error) } }));
        }
      });
    });
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(ports[name], '127.0.0.1', resolve);
    });
    servers.push(server);
    console.log(
      `[dev] ${name.padEnd(8)} http://127.0.0.1:${ports[name]}  (in-memory adapter, DEV MODE — not durable)`,
    );
  }
  return {
    ports,
    close: () =>
      Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve)))),
  };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const requested = process.argv.slice(2).filter((arg) => SERVICES.includes(arg));
  const unknown = process.argv.slice(2).filter((arg) => !SERVICES.includes(arg));
  if (unknown.length)
    throw new Error(`Unknown service(s): ${unknown.join(', ')}. Choose ${SERVICES.join(', ')}.`);
  const running = await startDevServices(requested.length ? requested : SERVICES);
  console.log(
    '[dev] GET /health on each; internal calls need X-Service-* HMAC headers (dev keys). Ctrl+C to stop.',
  );
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      await running.close();
      process.exit(0);
    });
  }
}
