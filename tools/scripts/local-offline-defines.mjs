import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const privateDir = path.join(root, '.secrets/local-dev');
const mobileFile = path.join(privateDir, 'mobile-defines.json');
const learningFile = path.join(privateDir, 'learning-smoke.json');
const outputFile = path.join(privateDir, 'offline-defines.json');

const fixedMobile = {
  DATA_SOURCE: 'api',
  USE_MOCK_AUTH: 'false',
  APPWRITE_ENDPOINT: 'https://10.0.2.2:8443/v1',
  APPWRITE_PROJECT_ID: 'cocenglish-local',
  LEARNING_API_URL: 'https://10.0.2.2:4101',
  PROGRESS_API_URL: 'https://10.0.2.2:4102',
  AI_API_URL: 'https://10.0.2.2:4103',
};

function validCertificate(encoded) {
  if (typeof encoded !== 'string' || encoded.length < 32) return false;
  try {
    const pem = Buffer.from(encoded, 'base64').toString('utf8').replaceAll('\r\n', '\n').trim();
    return (
      pem.startsWith('-----BEGIN CERTIFICATE-----\n') && pem.endsWith('\n-----END CERTIFICATE-----')
    );
  } catch {
    return false;
  }
}

export function buildOfflineDefines(mobile, learningSmoke) {
  const alice = learningSmoke?.users?.[0];
  const fixed = Object.entries(fixedMobile).every(([key, value]) => mobile?.[key] === value);
  if (
    !fixed ||
    !validCertificate(mobile?.LOCAL_DEV_CA_BASE64) ||
    learningSmoke?.endpoint !== 'https://127.0.0.1:8443/v1' ||
    learningSmoke?.project !== 'cocenglish-local' ||
    learningSmoke?.status !== 'passed' ||
    typeof alice?.id !== 'string' ||
    !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/.test(alice.id) ||
    typeof alice?.email !== 'string' ||
    !/^[^@\s]+@cocenglish\.local$/.test(alice.email) ||
    typeof alice?.password !== 'string' ||
    alice.password.length < 12
  ) {
    throw new Error('LOCAL_OFFLINE_CONFIGURATION_INVALID');
  }
  return {
    ...fixedMobile,
    LOCAL_DEV_CA_BASE64: mobile.LOCAL_DEV_CA_BASE64,
    LOCAL_TEST_EMAIL: alice.email,
    LOCAL_TEST_PASSWORD: alice.password,
  };
}

function readPrivateJson(file) {
  if (!fs.statSync(file).isFile()) throw new Error('LOCAL_OFFLINE_CONFIGURATION_INVALID');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function main() {
  const action = process.argv[2] ?? 'generate';
  if (!['generate', '--check'].includes(action)) {
    throw new Error('UNKNOWN_LOCAL_OFFLINE_DEFINES_ACTION');
  }
  let defines;
  try {
    defines = buildOfflineDefines(readPrivateJson(mobileFile), readPrivateJson(learningFile));
  } catch {
    throw new Error('LOCAL_OFFLINE_CONFIGURATION_INVALID');
  }
  if (action === '--check') {
    process.stdout.write('{"status":"ready"}\n');
    return;
  }
  const temporary = `${outputFile}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(defines, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, outputFile);
  process.stdout.write('{"status":"written","file":"offline-defines.json"}\n');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    const safe =
      error instanceof Error && /^[A-Z0-9_]+$/.test(error.message)
        ? error.message
        : 'LOCAL_OFFLINE_CONFIGURATION_INVALID';
    process.stderr.write(`${safe}\n`);
    process.exitCode = 1;
  }
}
