import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const files = [
  'compose.env',
  'appwrite.env',
  'console.json',
  'learning.env',
  'progress.env',
  'ai.env',
];
const secret = () => randomBytes(32).toString('hex');
const envText = (values) =>
  Object.entries(values)
    .map(([k, v]) => `${k}=${v}`)
    .join('\n') + '\n';

/** Only creates a NEW isolated environment. Existing credentials are never rotated implicitly. */
export function prepareLocalConfig(dir) {
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  const present = files.filter((name) => fs.existsSync(path.join(dir, name)));
  if (present.length === files.length) return { created: false };
  if (present.length)
    throw new Error('PARTIAL_LOCAL_CONFIGURATION: restore missing files before continuing');
  const dbPassword = secret();
  const cachePassword = secret();
  const brokerPassword = secret();
  const geoSecret = secret();
  const common = {
    APPWRITE_ENDPOINT: 'https://local-tls:8443/v1',
    APPWRITE_PROJECT_ID: 'cocenglish-local',
    COC_DATABASE_ID: 'cocenglish',
    NODE_EXTRA_CA_CERTS: '/local-ca/ca.crt',
    COC_LEARNING_URL: 'https://local-tls:4101',
    COC_PROGRESS_URL: 'https://local-tls:4102',
    COC_AI_URL: 'https://local-tls:4103',
    COC_AI_PROVIDER: 'disabled',
    COC_EVENT_TRANSPORT: 'direct',
    COC_READ_CACHE: 'disabled',
    COC_WORKER_INTERVAL_MS: '5000',
  };
  const values = {
    'compose.env': envText({
      COMPOSE_PROJECT_NAME: 'cocenglish-dev',
      POSTGRES_PASSWORD: dbPassword,
      REDIS_PASSWORD: cachePassword,
      RABBITMQ_PASSWORD: brokerPassword,
    }),
    'appwrite.env': envText({
      _APP_ENV: 'production',
      _APP_VERSION: '2.3.0',
      _APP_DOMAIN: 'localhost',
      _APP_DOMAIN_TARGET: 'localhost',
      _APP_DOMAIN_FUNCTIONS: 'functions.localhost',
      _APP_DOMAIN_SITES: 'sites.localhost',
      _APP_CONSOLE_HOSTNAMES: 'localhost,127.0.0.1,10.0.2.2,local-tls',
      _APP_CONSOLE_WHITELIST_ROOT: 'enabled',
      _APP_OPTIONS_FORCE_HTTPS: 'disabled',
      _APP_OPTIONS_ROUTER_FORCE_HTTPS: 'disabled',
      _APP_OPTIONS_ABUSE: 'enabled',
      _APP_OPENSSL_KEY_V1: secret(),
      _APP_EXECUTOR_SECRET: secret(),
      _APP_WORKER_PER_CORE: '1',
      _APP_CPU_NUM: '2',
      _APP_WORKERS_NUM: '1',
      _APP_WORKER_MAX_COROUTINES: '8',
      _APP_DB_ADAPTER: 'postgresql',
      _APP_DB_HOST: 'postgresql',
      _APP_DB_PORT: '5432',
      _APP_DB_SCHEMA: 'appwrite',
      _APP_DB_USER: 'cocenglish',
      _APP_DB_PASS: dbPassword,
      // DocumentsDB is a separate, unused Mongo API. CocEnglish uses TablesDB only.
      _APP_DB_ADAPTER_DOCUMENTSDB: 'mongodb',
      _APP_DB_HOST_DOCUMENTSDB: 'mongodb',
      _APP_DB_ADAPTER_VECTORSDB: 'postgresql',
      _APP_DB_HOST_VECTORSDB: 'postgresql',
      _APP_REDIS_HOST: 'appwrite-redis',
      _APP_REDIS_PORT: '6379',
      _APP_SMTP_HOST: 'mailpit',
      _APP_SMTP_PORT: '1025',
      _APP_SMTP_SECURE: '',
      _APP_SMTP_USERNAME: '',
      _APP_SMTP_PASSWORD: '',
      _APP_SYSTEM_EMAIL_ADDRESS: 'noreply@cocenglish.local',
      _APP_SYSTEM_EMAIL_NAME: 'CocEnglish Local',
      _APP_GEO_ENDPOINT: 'http://appwrite-geo/v1',
      _APP_GEO_SECRET: geoSecret,
      GEO_SECRET: geoSecret,
      _APP_AUTOGRAVITY_HOST: 'http://appwrite-autogravity:8080',
      _APP_EMBEDDING: 'disabled',
      _APP_STORAGE_DEVICE: 'Local',
      _APP_STORAGE_LIMIT: '30000000',
      _APP_STORAGE_PREVIEW_LIMIT: '20000000',
      _APP_STORAGE_ANTIVIRUS: 'disabled',
      _APP_LOGGING_PROVIDER: '',
      _APP_USAGE_STATS: 'disabled',
    }),
    'console.json':
      JSON.stringify({ email: 'admin@cocenglish.local', password: secret() }, null, 2) + '\n',
  };
  for (const owner of ['learning', 'progress', 'ai']) {
    values[`${owner}.env`] = envText({
      ...common,
      [`COC_${owner.toUpperCase()}_PERSISTENCE`]: 'disabled',
    });
  }
  for (const [name, value] of Object.entries(values)) {
    fs.writeFileSync(path.join(dir, name), value, { flag: 'wx', mode: 0o600 });
  }
  return { created: true };
}

export function writeLocalMobileDefines(dir) {
  const ca = fs.readFileSync(path.join(dir, 'tls/ca.crt'));
  const host = 'https://10.0.2.2';
  const defines = {
    DATA_SOURCE: 'api',
    USE_MOCK_AUTH: 'false',
    APPWRITE_ENDPOINT: `${host}:8443/v1`,
    APPWRITE_PROJECT_ID: 'cocenglish-local',
    LEARNING_API_URL: `${host}:4101`,
    PROGRESS_API_URL: `${host}:4102`,
    AI_API_URL: `${host}:4103`,
    LOCAL_DEV_CA_BASE64: ca.toString('base64'),
  };
  fs.writeFileSync(path.join(dir, 'mobile-defines.json'), JSON.stringify(defines, null, 2) + '\n', {
    mode: 0o600,
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  prepareLocalConfig(path.join(root, '.secrets/local-dev'));
  if (fs.existsSync(path.join(root, '.secrets/local-dev/tls/ca.crt')))
    writeLocalMobileDefines(path.join(root, '.secrets/local-dev'));
  console.log('Local configuration ready in .secrets/local-dev (credentials withheld).');
}
