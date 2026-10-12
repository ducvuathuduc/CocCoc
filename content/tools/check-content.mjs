// `node content/tools/check-content.mjs` — offline gate for committed course content:
// OpenAPI schema validation of every manifest/bundle (CourseManifest, LessonBundle), file sha256 vs
// the manifest index and publish.json, Ed25519 signatures (dev keyring, or COC_CONTENT_PUBLIC_KEYS),
// structural/answer-key validation and all 12 exercise types present. No network.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadContentTools, root } from './lib.mjs';

const tools = await loadContentTools();
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const ajv = new Ajv({ strict: false, allErrors: false });
formats(ajv);
ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
const schema = (name) =>
  ajv.compile({ $ref: `https://cocenglish.example.invalid/schema#/components/schemas/${name}` });
const validateManifest = schema('CourseManifest');
const validateBundle = schema('LessonBundle');
const keyring = process.env.COC_CONTENT_PUBLIC_KEYS
  ? tools.parseContentKeyring(process.env.COC_CONTENT_PUBLIC_KEYS)
  : tools.devContentKeyring();

const summary = [];
for (const courseDir of fs
  .readdirSync(path.join(root, 'content'))
  .filter((d) => fs.existsSync(path.join(root, 'content', d, 'dist')))) {
  for (const version of fs.readdirSync(path.join(root, 'content', courseDir, 'dist'))) {
    const dir = path.join(root, 'content', courseDir, 'dist', version);
    const publish = JSON.parse(fs.readFileSync(path.join(dir, 'publish.json'), 'utf8'));
    const read = (p) => fs.readFileSync(path.join(dir, p), 'utf8');
    for (const file of publish.files)
      assert.equal(tools.sha256(read(file.path)), file.sha256, `${file.path} sha256`);
    const manifestText = read('manifest.json');
    assert.equal(tools.sha256(manifestText), publish.manifestSha256);
    const manifest = JSON.parse(manifestText);
    assert.equal(tools.canonicalJson(manifest), manifestText, 'manifest is canonical JSON');
    assert.ok(validateManifest(manifest), JSON.stringify(validateManifest.errors?.slice(0, 3)));
    assert.ok(tools.verifyManifest(keyring, manifest), 'manifest signature/structure hash');
    const bundles = [];
    for (const index of [...manifest.bundles, manifest.placementBundle]) {
      const file = publish.files.find((f) => f.fileId === index.fileId);
      assert.ok(file, `${index.fileId} listed in publish.json`);
      const text = read(file.path);
      assert.equal(tools.sha256(text), index.sha256, `${index.lessonId} sha256 matches manifest`);
      const bundle = JSON.parse(text);
      assert.ok(
        validateBundle(bundle),
        `${index.lessonId}: ${JSON.stringify(validateBundle.errors?.slice(0, 3))}`,
      );
      assert.ok(tools.verifyBundle(keyring, bundle), `${index.lessonId} signature`);
      assert.equal(bundle.lessonVersion, index.lessonVersion);
      if (index !== manifest.placementBundle) bundles.push(bundle);
      else assert.deepEqual(tools.validateBundle(bundle), []);
    }
    const problems = tools.validateCourse(manifest, bundles);
    assert.deepEqual(problems, [], JSON.stringify(problems.slice(0, 10)));
    summary.push({
      courseId: manifest.courseId,
      version,
      lessons: bundles.length,
      nodes: manifest.nodes.length,
    });
  }
}
assert.ok(summary.length > 0, 'no content found');
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'offline content schema/hash/signature/answer-key check',
    courses: summary,
  }),
);
