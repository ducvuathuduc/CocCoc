import { readFileSync } from 'node:fs';
import path from 'node:path';
import { z } from 'zod';

const csvList = (raw: string | undefined): string[] =>
  (raw ?? '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);

const booleanEnv = (raw: string | undefined): boolean => raw === '1' || raw === 'true';

const appwriteShape = z.object({
  endpoint: z.string().url(),
  projectId: z.string().min(1),
  apiKey: z.string().min(1),
});

export type CmsMode = 'appwrite' | 'file';

export interface CmsConfig {
  mode: CmsMode;
  repoRoot: string;
  dataDir: string;
  endpoint: string;
  projectId: string;
  apiKey: string;
  databaseId: string;
  assetBucketId: string;
  admins: ReadonlySet<string>;
  publishAllowed: boolean;
  learningUrl: string;
  production: boolean;
}

function resolve(value: string | undefined, fallback: string): string {
  if (!value) return fallback;
  // Paths are given absolutely or relative to the process by the operator; this app is deployed as
  // source, not as a bundled serverless function, so the trace hint is only for the bundler.
  return path.isAbsolute(value)
    ? value
    : path.resolve(/* turbopackIgnore: true */ process.cwd(), value);
}

/**
 * The operator keeps the Appwrite pair in `<repoRoot>/.secrets/real.env`: git-ignored, and outside
 * this app, which must never hold a key in one of its own files. Only `NAME=value` lines are read,
 * and a value already in the process wins — so CI, the publishing machine and every harness, which
 * set their own endpoint, keep their own truth.
 */
function secretsFile(file: string): Record<string, string> {
  let raw: string;
  try {
    raw = readFileSync(file, 'utf8');
  } catch {
    return {};
  }
  const out: Record<string, string> = {};
  for (const line of raw.split(/\r?\n/)) {
    const entry = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(line);
    if (!entry || line.trimStart().startsWith('#')) continue;
    out[entry[1]] = entry[2].trim().replace(/^(["'])(.*)\1$/, '$2');
  }
  return out;
}

/**
 * Reads the environment once per process. A production process must never fall back to the file
 * store: an admin tool editing content silently is worse than one that refuses to start.
 */
export function readConfig(env: NodeJS.ProcessEnv = process.env): CmsConfig {
  const production = env.NODE_ENV === 'production';
  const repoRoot = resolve(env.CMS_REPO_ROOT, path.resolve(process.cwd(), '..', '..'));
  const secrets = secretsFile(
    path.join(/* turbopackIgnore: true */ repoRoot, '.secrets', 'real.env'),
  );
  const operator = (name: string) => env[name] ?? secrets[name] ?? '';
  const endpoint = operator('APPWRITE_ENDPOINT');
  const projectId = operator('APPWRITE_PROJECT_ID');
  const apiKey = operator('APPWRITE_API_KEY');
  const parsed = appwriteShape.safeParse({ endpoint, projectId, apiKey });

  const admins = new Set(csvList(env.CMS_ADMIN_USER_IDS));

  const mode: CmsMode = parsed.success ? 'appwrite' : 'file';
  if (production && mode !== 'appwrite') {
    throw new Error(
      'CONFIG_INCOMPLETE: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID and APPWRITE_API_KEY are required in production',
    );
  }
  if (production && admins.size === 0) {
    throw new Error('CONFIG_INCOMPLETE: CMS_ADMIN_USER_IDS is required in production');
  }

  return {
    mode,
    repoRoot,
    dataDir: resolve(env.CMS_DATA_DIR, path.resolve(process.cwd(), '.cms-data')),
    endpoint: parsed.success ? parsed.data.endpoint : '',
    projectId: parsed.success ? parsed.data.projectId : '',
    apiKey: parsed.success ? parsed.data.apiKey : '',
    databaseId: env.CMS_DATABASE_ID ?? 'cocenglish',
    assetBucketId: env.CMS_ASSET_BUCKET ?? 'learning-assets',
    admins,
    publishAllowed: booleanEnv(env.CMS_ALLOW_PUBLISH),
    learningUrl: env.CMS_LEARNING_URL ?? 'http://127.0.0.1:4101',
    production,
  };
}

let cached: CmsConfig | undefined;

export function config(): CmsConfig {
  if (!cached) cached = readConfig();
  return cached;
}
