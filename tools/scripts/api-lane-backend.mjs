// `node tools/scripts/api-lane-backend.mjs [--port 4181] [--state <file>]`
// Learning backend for the Flutter API-mode lane (apps/mobile/test_api, run by
// tools/scripts/mobile-api-lane.mjs). It is the real Learning router and use cases over the in-memory
// adapter, on 127.0.0.1 only, so the app's generated clients and parsers meet real responses
// without a cloud project, Appwrite or any credential.
//
// Fixtures (all valid, signed with the well-known dev content key, media verified by the same
// publish gate production uses):
//   vi_en        committed v2 with its real 1,760 media files, published at startup (the only
//                course a fresh install sees).
//   vi_en_mini   v1 and v2 built in memory and NOT published: the tests publish, roll back and
//                unpublish them through the real admin routes as `maintainer-1`. Its lesson ids
//                (u1n1l1 ...) collide with vi_en's on purpose.
// Auth is the test router's stub: `Authorization: Bearer user-<userId>`; `maintainer-1` may publish.
// Production identity (Appwrite JWT) is covered by the local Appwrite lane, not here.
//
// Fault control for error-path tests: POST /__lane/faults {"missingMedia":bool,"storageOutage":bool}.
// These routes exist only in this test server; hosted code has no such path.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCourse } from '../content/build-course.mjs';
import { loadKit, root } from '../../services/learning/test/helpers/kit.mjs';
import {
  layeredMedia,
  withFixtureMedia,
} from '../../services/learning/test/helpers/media-course.mjs';
import { toFunctionContext } from './dev-services.mjs';

const MAX_BODY_BYTES = 1_000_000;
const SECOND = 'vi_en_mini';

const arg = (name, fallback) => {
  const index = process.argv.indexOf(`--${name}`);
  return index > 0 ? process.argv[index + 1] : fallback;
};

export async function startApiLaneBackend({ port = 4181, statePath } = {}) {
  const kit = await loadKit(`api-lane-${process.pid}`);
  const local = kit.loadLocalContent(root);
  const viEnMedia = kit.localMediaStore(root);

  const texts = new Map();
  const served = new Map();
  const fixtures = {};
  for (const version of ['v1', 'v2']) {
    const built = await withFixtureMedia(
      kit,
      await buildCourse({ courseId: SECOND, version }),
      viEnMedia,
    );
    if (built.problems.length) throw new Error(`fixture ${SECOND} ${version} is invalid`);
    fixtures[version] = {
      courseId: built.publish.courseId,
      versionId: built.publish.versionId,
      manifestFileId: built.publish.manifestFileId,
      manifestSha256: built.publish.manifestSha256,
    };
    for (const file of built.files) texts.set(file.fileId, file.text);
    for (const [fileId, bytes] of built.served) served.set(fileId, bytes);
  }

  const faults = { missingMedia: false, storageOutage: false };
  const layered = layeredMedia(viEnMedia, served);
  const hidden = [...served.keys()].sort()[0];
  const outage = () =>
    new kit.ServiceError('STORAGE_UNAVAILABLE', {
      details: { reason: kit.MEDIA_REASONS.unavailable },
    });
  const files = {
    read: async (fileId) => {
      if (faults.storageOutage) throw outage();
      return texts.get(fileId) ?? local.files.read(fileId);
    },
    async stat(ids) {
      if (faults.storageOutage) throw outage();
      const found = await layered.stat(ids);
      if (faults.missingMedia) found.delete(hidden);
      return found;
    },
    async readBytes(id) {
      if (faults.storageOutage) throw outage();
      return faults.missingMedia && id === hidden ? null : layered.readBytes(id);
    },
  };
  const app = await kit.createTestApp({ root, files });

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
        if (req.url?.startsWith('/__lane/faults') && req.method === 'POST') {
          const next = JSON.parse(bodyText ?? '{}');
          for (const key of Object.keys(faults))
            if (typeof next[key] === 'boolean') faults[key] = next[key];
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ faults }));
          return;
        }
        await app.handler(toFunctionContext(req, bodyText, res));
      } catch (error) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { code: 'INTERNAL_ERROR', message: String(error) } }));
      }
    });
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });

  const state = {
    url: `http://127.0.0.1:${server.address().port}`,
    learnerToken: 'user-lane-learner',
    maintainerToken: 'user-maintainer-1',
    shippedCourse: { courseId: 'vi_en', versionId: 'v2' },
    fixtures: { [SECOND]: fixtures },
  };
  if (statePath) {
    fs.mkdirSync(path.dirname(statePath), { recursive: true });
    fs.writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`);
  }
  return { state, close: () => new Promise((resolve) => server.close(resolve)) };
}

const invoked = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  const statePath = path.resolve(arg('state', path.join(root, '.cache/api-lane/state.json')));
  const running = await startApiLaneBackend({
    port: Number(arg('port', process.env.COC_API_LANE_PORT ?? 4181)),
    statePath,
  });
  // One machine-readable line; the orchestrator waits for it.
  console.log(JSON.stringify({ status: 'READY', url: running.state.url, state: statePath }));
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      await running.close();
      process.exit(0);
    });
  }
}
