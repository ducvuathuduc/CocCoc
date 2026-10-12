// Shared bootstrap for the maintainer CLIs (tools/admin/promo.mjs, tools/admin/classroom.mjs).
// Bundles services/progress/src/admin/maintainer.ts with esbuild (no network) and opens the
// Progress persistence: the Appwrite TablesDB adapter with a SERVER key (never a client), or an
// in-memory store with --memory for local rehearsal.
//   APPWRITE_ENDPOINT   default https://sgp.cloud.appwrite.io/v1
//   APPWRITE_PROJECT_ID default 6acc656d0025cc57bd81 (CocEnglish TEST project)
//   APPWRITE_API_KEY    server key with rows read/write on database cocenglish (required)
// Behind the sandbox egress proxy run with NODE_USE_ENV_PROXY=1.
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { buildSync } from 'esbuild';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const DEFAULT_ENDPOINT = 'https://sgp.cloud.appwrite.io/v1';
export const DEFAULT_PROJECT = '6acc656d0025cc57bd81';

export async function loadMaintainer() {
  const outfile = path.join(root, `.cache/admin/maintainer-${process.pid}.mjs`);
  buildSync({
    entryPoints: [path.join(root, 'services/progress/src/admin/maintainer.ts')],
    outfile,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    logLevel: 'error',
    banner: {
      js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
    },
  });
  return import(pathToFileURL(outfile).href);
}

/** Minimal --flag value / --switch parser. */
export function parseArgs(argv) {
  const [command, ...rest] = argv;
  const flags = {};
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (!arg.startsWith('--')) throw new Error(`unexpected argument ${arg}`);
    const key = arg.slice(2);
    const next = rest[i + 1];
    if (next === undefined || next.startsWith('--')) flags[key] = true;
    else {
      flags[key] = next;
      i++;
    }
  }
  return { command, flags };
}

export function openStore(kit, flags, env = process.env) {
  if (flags.memory) {
    return {
      store: kit.createMemoryProgressPersistence(Date.now, { strictSchema: true }),
      target: 'memory',
    };
  }
  const endpoint = env.APPWRITE_ENDPOINT ?? DEFAULT_ENDPOINT;
  const projectId = flags.project ?? env.APPWRITE_PROJECT_ID ?? DEFAULT_PROJECT;
  const apiKey = env.APPWRITE_API_KEY;
  if (!apiKey) throw new Error('APPWRITE_API_KEY (server key) is required; or pass --memory');
  if (!endpoint.startsWith('https://')) throw new Error('APPWRITE_ENDPOINT must be https');
  return {
    store: kit.createAppwriteProgressPersistence({ endpoint, projectId, apiKey, admitted: false }),
    target: `${endpoint} project ${projectId}`,
  };
}

export async function main(run, usage) {
  try {
    const { command, flags } = parseArgs(process.argv.slice(2));
    if (!command || flags.help) {
      console.log(usage);
      process.exit(command ? 0 : 2);
    }
    const result = await run(command, flags);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`error: ${error.message}`);
    console.error(usage);
    process.exit(1);
  }
}
