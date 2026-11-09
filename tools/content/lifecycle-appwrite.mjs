// `node tools/content/lifecycle-appwrite.mjs --action <list|unpublish|retire|rollback> --course <id> [--version <vN>] [--expect <vN>]`
// Drives the Learning service's admin lifecycle routes against an Appwrite project, the same way
// publish-appwrite.mjs drives the publish route: a durable Appwrite adapter fronts the real
// Learning router, so every command runs the genuine use case (CAS, integrity, maintainer guard)
// over the shared `l_courses` / `l_content_versions` tables. The CMS never writes `l_*` itself.
//
//   list     GET  /v1/admin/courses/{course}/content-versions
//   unpublish POST /v1/admin/courses/{course}/unpublish            { expectedPublishedVersion }
//   retire   POST /v1/admin/courses/{course}/content-versions/{version}/retire
//   rollback POST /v1/admin/courses/{course}/rollback              { targetVersionId, expectedPublishedVersion }
//   verify-media  read-only audit of the live (or --version) version's media in Storage; exit 1 on
//            any missing, corrupt or non-public asset. Run on a schedule against staging/production.
//
// `--expect` is the CAS token: the version the operator believes is live. When omitted for a write,
// it is read from `l_courses` first, but passing it explicitly (as the CMS UI does from its last
// known state) is what makes two admins unable to roll past each other.
// Env: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY (server key), COC_DATABASE_ID.
// Deploy action: run only against a project you are authorized to change.
import { randomUUID } from 'node:crypto';
import { Client, Storage, TablesDB } from 'node-appwrite';
import { loadKit, root } from '../../services/learning/test/helpers/kit.mjs';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : fallback;
};
const has = (name) => process.argv.includes(`--${name}`);
const action = arg('action', '');
const courseId = arg('course', '');
const versionId = arg('version', '');
const expectVersion = arg('expect', undefined);
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '6acc656d0025cc57bd81';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = process.env.COC_DATABASE_ID ?? 'cocenglish';
const bucketId = 'learning-assets';
if (!apiKey) throw new Error('APPWRITE_API_KEY is required');
if (!courseId) throw new Error('--course <courseId> is required');
if (!['list', 'unpublish', 'retire', 'rollback', 'verify-media'].includes(action))
  throw new Error('--action must be one of list|unpublish|retire|rollback|verify-media');
if ((action === 'retire' || action === 'rollback') && !versionId)
  throw new Error(`--action ${action} requires --version <versionId>`);

const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
const storage = new Storage(client);
const tables = new TablesDB(client);
const kit = await loadKit('lifecycle-appwrite');

const durable = kit.createAppwriteLearningPersistence(
  { endpoint, projectId, apiKey, databaseId, admittedForHosting: false },
  tables,
);
const persistence = new Proxy(durable, {
  get(target, prop) {
    const value = Reflect.get(target, prop, target);
    if (typeof value !== 'function') return value;
    return async (...args) => {
      try {
        return await value.apply(target, args);
      } catch (error) {
        console.error(
          `persistence.${String(prop)} failed:`,
          error?.code ?? '',
          error?.message,
          JSON.stringify(error?.details ?? {}),
          error?.cause?.message ?? '',
        );
        throw error;
      }
    };
  },
});
// Same Storage file store as the hosted function: rollback re-audits its target's media through it.
const files = kit.createStorageContentFiles({ endpoint, projectId, apiKey, bucketId }, storage);
const media = { deadlineMs: 300_000, ...kit.mediaPolicyFromEnv(process.env) };
const app = await kit.createTestApp({ persistence, files, media, seed: false });

const resolveExpect = async () => {
  if (expectVersion !== undefined) return expectVersion; // null or a version string
  const course = await persistence.read('l_courses', kit.ids.course(courseId));
  return course ? (course.publishedVersion ? String(course.publishedVersion) : null) : null;
};

let result;
if (action === 'verify-media') {
  // Read-only audit of a version's media in Storage (default: the live version). Run it on a
  // schedule to catch an asset deleted or replaced after publication; it changes nothing.
  const live = await resolveExpect();
  const target = versionId || live;
  if (!target)
    throw new Error(`course ${courseId} has no live version; pass --version <versionId>`);
  try {
    const e = await kit.verifyVersionMedia(app.deps, courseId, target);
    result = {
      status: 'PASS',
      action,
      courseId,
      versionId: target,
      live: target === live,
      assets: e.assets,
      references: e.references,
      bytes: e.bytes,
      statCalls: e.statCalls,
      readCalls: e.readCalls,
      cacheHits: e.cacheHits,
      elapsedMs: e.elapsedMs,
    };
  } catch (error) {
    console.log(
      JSON.stringify({
        status: 'FAIL',
        action,
        courseId,
        versionId: target,
        code: error?.code,
        details: error?.details,
      }),
    );
    process.exit(1);
  }
} else if (action === 'list') {
  const r = await app.call('GET', `/v1/admin/courses/${courseId}/content-versions`, {
    user: 'maintainer-1',
  });
  if (r.status !== 200) throw new Error(`list failed: ${r.status} ${JSON.stringify(r.body)}`);
  result = { status: 'PASS', action, courseId, ...r.body };
} else if (action === 'unpublish') {
  const expectedPublishedVersion = await resolveExpect();
  const r = await app.call('POST', `/v1/admin/courses/${courseId}/unpublish`, {
    user: 'maintainer-1',
    key: randomUUID(),
    body: { expectedPublishedVersion },
  });
  if (r.status !== 200) throw new Error(`unpublish failed: ${r.status} ${JSON.stringify(r.body)}`);
  result = { status: 'PASS', action, courseId, expectedPublishedVersion, ...r.body };
} else if (action === 'retire') {
  const expectedPublishedVersion = await resolveExpect();
  const r = await app.call(
    'POST',
    `/v1/admin/courses/${courseId}/content-versions/${versionId}/retire`,
    {
      user: 'maintainer-1',
      key: randomUUID(),
      body: { expectedPublishedVersion },
    },
  );
  if (r.status !== 200) throw new Error(`retire failed: ${r.status} ${JSON.stringify(r.body)}`);
  result = { status: 'PASS', action, courseId, versionId, expectedPublishedVersion, ...r.body };
} else {
  // rollback
  const expectedPublishedVersion = await resolveExpect();
  const r = await app.call('POST', `/v1/admin/courses/${courseId}/rollback`, {
    user: 'maintainer-1',
    key: randomUUID(),
    body: { targetVersionId: versionId, expectedPublishedVersion },
  });
  if (r.status !== 200) throw new Error(`rollback failed: ${r.status} ${JSON.stringify(r.body)}`);
  result = { status: 'PASS', action, courseId, versionId, expectedPublishedVersion, ...r.body };
}

console.log(JSON.stringify(result));
