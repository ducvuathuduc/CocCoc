// Bounded loopback-only smoke benchmark. Never targets a hosted service or uses real credentials.
import { performance } from 'node:perf_hooks';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { startDevServices } from './dev-services.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const defaults = { requests: 200, concurrency: 10, port: 24101 };

export function parseOptions(args) {
  const options = { ...defaults };
  const seen = new Set();
  for (const arg of args) {
    const match = /^--(requests|concurrency|port)=([0-9]+)$/.exec(arg);
    if (!match || seen.has(match[1])) throw new Error(`Invalid option: ${arg}`);
    seen.add(match[1]);
    options[match[1]] = Number(match[2]);
  }
  if (
    !Number.isSafeInteger(options.requests) ||
    options.requests < 1 ||
    options.requests > 2000 ||
    !Number.isSafeInteger(options.concurrency) ||
    options.concurrency < 1 ||
    options.concurrency > 50 ||
    !Number.isSafeInteger(options.port) ||
    options.port < 1024 ||
    options.port > 65533
  ) {
    throw new Error('Invalid load limits or port');
  }
  return options;
}

function percentile(values, quantile) {
  return values[Math.max(0, Math.ceil(values.length * quantile) - 1)];
}

export async function runLoad({ requests, concurrency }, send) {
  parseOptions([`--requests=${requests}`, `--concurrency=${concurrency}`]);
  const latencies = [];
  const statuses = {};
  let next = 0;
  let successes = 0;
  const started = performance.now();
  async function worker() {
    while (next < requests) {
      next++;
      const begin = performance.now();
      let status;
      try {
        status = await send();
      } catch {
        status = 'network';
      }
      latencies.push(performance.now() - begin);
      statuses[status] = (statuses[status] ?? 0) + 1;
      if (status === 200) successes++;
    }
  }
  await Promise.all(Array.from({ length: Math.min(requests, concurrency) }, worker));
  const elapsedMs = performance.now() - started;
  latencies.sort((a, b) => a - b);
  return {
    requests,
    concurrency,
    successes,
    failures: requests - successes,
    statusCounts: statuses,
    elapsedMs,
    requestsPerSecond: (requests * 1000) / elapsedMs,
    latencyMs: {
      p50: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95),
      p99: percentile(latencies, 0.99),
    },
  };
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to run in production');
  // This process starts its own in-memory server. No user-provided URL, cloud key or host is used.
  process.env.NODE_ENV = 'development';
  process.env.COC_DEV_AUTH = '1';
  process.env.COC_DEV_RELAY = '0';
  process.env.COC_DEV_PORT_BASE = String(options.port);
  process.env.COC_SERVICE_KEYS = '';
  process.env.COC_REPO_ROOT = root;
  const server = await startDevServices(['learning'], process.env);
  try {
    const url = `http://127.0.0.1:${server.ports.learning}/v1/courses`;
    const result = await runLoad(options, async () => {
      const response = await fetch(url, {
        headers: { Authorization: 'Bearer dev-load-test' },
        signal: AbortSignal.timeout(5000),
      });
      const body = await response.json();
      return response.status === 200 && Array.isArray(body.items)
        ? 200
        : response.status === 200
          ? 'bad_body'
          : response.status;
    });
    console.log(
      JSON.stringify(
        {
          scope: 'loopback in-memory Learning catalog, synthetic identity; not production capacity',
          node: process.version,
          ...result,
        },
        null,
        2,
      ),
    );
    if (result.failures) process.exitCode = 1;
  } finally {
    await server.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(`Local load failed: ${error.message}`);
    process.exitCode = 1;
  });
}
