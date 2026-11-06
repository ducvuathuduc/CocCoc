// Media proof: the CMS must ask for the same files the app asks for. Derive every unit's asset list
// from the authored tables (the way the editor does), then compare it against three things the repo
// already publishes: the built audio catalog, the asset list inside dist/v2/bundles, and the files
// under content/vi_en/media. The same bundles also say which drills the app received and which
// pictures it never shows, so the panel's tallies and unused flags are checked against an independent
// recount. Finally prove the preview route refuses to leave the course media tree.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const appRoot = path.resolve(import.meta.dirname, '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const courseId = 'vi_en';
const version = 'v2';
process.env.CMS_REPO_ROOT = repoRoot;

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/cms/media'; export * from '@/server/media-service'; export { tablesToUnit } from '@/cms/tables';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  // media-service now reaches the store for the course index; node-appwrite must stay outside the
  // bundle or its undici require chain breaks in ESM (same reason the other harnesses do this).
  external: ['node-appwrite'],
  alias: { '@': path.join(appRoot, 'src') },
});

const scratch = await mkdtemp(path.join(repoRoot, 'node_modules', '.media-'));
const bundleFile = path.join(scratch, 'cms.mjs');
writeFileSync(bundleFile, bundled.outputFiles[0].text, 'utf8');
const cms = await import(pathToFileURL(bundleFile).href);
await rm(scratch, { recursive: true, force: true });

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};

const toDraft = (unit) =>
  cms.tablesToUnit({
    theme: unit.theme,
    cefr: unit.cefr,
    title: unit.title,
    levels: unit.levels,
    guide: unit.guide,
    vocab: unit.vocab,
    sentences: unit.sentences,
    dialogues: unit.dialogues,
    storyTitle: unit.story.title,
    passage: unit.story.passage,
    questions: unit.story.questions,
  });

check('generator numbers units by position', cms.generatorUnitId(0) === 'u1' && cms.generatorUnitId(15) === 'u16');

const catalog = JSON.parse(
  readFileSync(path.join(repoRoot, 'content', courseId, 'dist', version, 'audio-catalog.json'), 'utf8'),
).items;
check('audio catalog loaded', catalog.length > 0, `${catalog.length} items`);

// Group by the bundle's own `unitId`, not by a regex on the fileId: word clips are keyed `a.w.<slug>`
// with no unit number in them, so only the bundle knows which unit ships them.
const bundlesDir = path.join(repoRoot, 'content', courseId, 'dist', version, 'bundles');
const declaredByUnit = new Map();
/** Drill counts per unit, once with the placement test and once without it. */
const typesAll = new Map();
const typesLessons = new Map();
const bump = (map, unitId, type) => {
  const tally = map.get(unitId) ?? {};
  tally[type] = (tally[type] ?? 0) + 1;
  map.set(unitId, tally);
};
/** Every picture id any built lesson carries, placement test included: the app shows it either way. */
const shippedImages = new Set();
for (const name of readdirSync(bundlesDir)) {
  const bundle = JSON.parse(readFileSync(path.join(bundlesDir, name), 'utf8'));
  if (!declaredByUnit.has(bundle.unitId)) declaredByUnit.set(bundle.unitId, new Set());
  for (const asset of bundle.assets ?? []) {
    declaredByUnit.get(bundle.unitId).add(asset.fileId);
    if (typeof asset.fileId === 'string' && asset.fileId.startsWith('i.')) shippedImages.add(asset.fileId);
  }
  for (const exercise of bundle.exercises ?? []) {
    bump(typesAll, bundle.unitId, exercise.type);
    // `build-course.mjs:1035` gives the placement test unit 1's number; it is not a lesson of unit 1.
    if (bundle.lessonId !== 'placement') bump(typesLessons, bundle.unitId, exercise.type);
  }
}
const flat = (tally) =>
  Object.entries(tally ?? {})
    .sort()
    .map(([type, count]) => `${type}=${count}`)
    .join(',');
const sum = (map) => [...map.values()].reduce((n, t) => n + Object.values(t).reduce((x, c) => x + c, 0), 0);
const declaredTotal = [...declaredByUnit.values()].reduce((n, s) => n + s.size, 0);
check(
  'bundles declare unit-scoped assets',
  declaredByUnit.size >= 16,
  `${declaredByUnit.size} units, ${declaredTotal} assets`,
);

const authored = JSON.parse(
  execFileSync(process.execPath, [path.join(appRoot, 'scripts', 'read-authored.mjs'), courseId, version], {
    cwd: repoRoot,
    maxBuffer: 32 * 1024 * 1024,
    encoding: 'utf8',
  }),
);
check('16 authored units read', authored.units.length === 16, `${authored.units.length}`);

let derived = 0;
const wordNotPerUnit = [];
const notOnDisk = [];
const notInCatalog = [];
const typeMismatch = [];
const unusedMismatch = [];
const derivedAnywhere = new Set();
const draftOnly = new Set();
const unusedPictures = new Set();
const unusedReady = new Set();
/** `u1.hello` for every row the editor flagged as having a picture, taken from the same derivation the panel uses. */
const pictureWords = new Set();
const derivedImages = [];
let fromBuildRows = 0;
for (const { index, unit } of authored.units) {
  const gen = cms.generatorUnitId(index);
  const draft = toDraft(unit);
  const { assets, exerciseTypes } = await cms.unitAssets(courseId, version, index, draft);
  derived += assets.length;
  const ids = new Set(assets.map((a) => a.fileId));
  for (const fileId of ids) derivedAnywhere.add(fileId);
  for (const asset of assets) {
    if (asset.fromBuild) fromBuildRows++;
    else draftOnly.add(asset.fileId);
  }
  // What the app received is a fact about the build, so an independent recount of the same bundle
  // files must agree with the panel exactly — including the drills the generator silently swapped.
  if (flat(exerciseTypes) !== flat(typesLessons.get(gen)))
    typeMismatch.push(`${gen}: CMS ${flat(exerciseTypes)} / bundles ${flat(typesLessons.get(gen))}`);
  for (const asset of assets) {
    if (asset.kind !== 'image') continue;
    pictureWords.add(asset.fileId.slice(2));
    derivedImages.push({ gen, fileId: asset.fileId, drilled: asset.drilledWithPicture });
    const shown = shippedImages.has(asset.fileId);
    if (asset.unused === shown)
      unusedMismatch.push(`${gen} ${asset.fileId} unused=${asset.unused} shown=${shown}`);
    if (asset.unused) {
      unusedPictures.add(asset.fileId);
      if (asset.present) unusedReady.add(asset.fileId);
    }
  }

  // Word clips carry no unit number, so only the build says which unit plays them. The panel and
  // `--only` have to agree with the build here or the file that unit needs stays invisible.
  for (const fileId of declaredByUnit.get(gen) ?? []) {
    if (fileId.startsWith('a.w.') && !ids.has(fileId)) wordNotPerUnit.push(`${gen} ${fileId}`);
  }
  for (const asset of assets) if (!asset.present) notOnDisk.push(`${gen} ${asset.fileId}`);

  const keyed = catalog.filter((i) => i.key.startsWith(`a.${gen}.`) && i.kind !== 'word');
  for (const item of keyed) {
    if (!ids.has(`${item.key}.n`)) notInCatalog.push(`${gen} ${item.key}.n`);
    if (!ids.has(`${item.key}.s`)) notInCatalog.push(`${gen} ${item.key}.s`);
  }
  check(`u${index + 1} has ${keyed.length} catalog keys and ${draft.sentences.length} + ${draft.dialogues.length} rows`,
    keyed.length === draft.sentences.length + draft.dialogues.length,
    `catalog ${keyed.length} vs rows ${draft.sentences.length + draft.dialogues.length}`);
}

// `a.u5.night.n` and `i.u3.apple` turn up inside u10's review lesson: the file belongs to the unit
// that introduces the word, so the only honest course-wide claim is "some unit of the CMS lists it".
const shipped = new Set();
for (const assets of declaredByUnit.values()) for (const fileId of assets) shipped.add(fileId);
const notShipped = [...shipped].filter((fileId) => !derivedAnywhere.has(fileId));
const wordShipped = [...shipped].filter((fileId) => fileId.startsWith('a.w.')).length;

check(
  `every one of the ${shipped.size} assets the app bundles is listed by the CMS`,
  notShipped.length === 0,
  `${notShipped.length} absent: ${notShipped.slice(0, 6).join(', ')}`,
);
check(
  `the ${wordShipped} tap-to-hear word clips the build ships are all listed`,
  wordShipped > 400,
  `${wordShipped} word clips`,
);
check('the word clip ids only the build knows are attributed to the unit that plays them', wordNotPerUnit.length === 0, wordNotPerUnit.slice(0, 4).join(', '));
const buildOnly = [...shipped].filter((fileId) => !draftOnly.has(fileId));
check(
  `${buildOnly.length} of the shipped ids exist only in the build, and the panels list them`,
  buildOnly.length > 0 && fromBuildRows > 0,
  `${buildOnly.length} ids, ${fromBuildRows} rows`,
);
check('every derived asset sits in content/vi_en/media', notOnDisk.length === 0, `${notOnDisk.length} missing: ${notOnDisk.slice(0, 6).join(', ')}`);
check('catalog keys all have their two clips derived', notInCatalog.length === 0, notInCatalog.slice(0, 4).join(', '));
check('derivation covers the whole course', derived > 1500, `${derived} assets`);

const lessonDrills = sum(typesLessons);
const allDrills = sum(typesAll);
check(
  `the ${lessonDrills} drills the 16 unit lessons ship are tallied per unit exactly as the bundles count them`,
  typeMismatch.length === 0 && lessonDrills > 1000,
  `${typeMismatch.length} mismatched units: ${typeMismatch.slice(0, 3).join(' | ')}`,
);
check(
  'the placement test is not mistaken for unit 1 lessons',
  allDrills > lessonDrills && flat(typesAll.get('u1')) !== flat(typesLessons.get('u1')),
  `${allDrills} drills counting placement vs ${lessonDrills} without it; u1 [${flat(typesAll.get('u1'))}] vs [${flat(typesLessons.get('u1'))}]`,
);
check(
  `the ${unusedPictures.size} pictures no built lesson carries are flagged, and no other picture is`,
  unusedMismatch.length === 0 && unusedReady.size === unusedPictures.size,
  `${unusedMismatch.length} wrong flags: ${unusedMismatch.slice(0, 4).join(', ')} / ${unusedReady.size} of ${unusedPictures.size} on disk`,
);

// A picture drill can only show a picture that exists. `build-course.mjs:918-925` keeps that true by
// downgrading `imageChoice` to a text choice, so the honest reading of the shipped course is which
// picture words the app actually gets to see.
const imageChoiceWords = new Set();
const pictureless = [];
for (const name of readdirSync(bundlesDir)) {
  const bundle = JSON.parse(readFileSync(path.join(bundlesDir, name), 'utf8'));
  if (bundle.lessonId === 'placement') continue;
  for (const exercise of bundle.exercises ?? []) {
    if (exercise.type !== 'imageChoice') continue;
    for (const vocabularyId of exercise.vocabularyIds ?? []) {
      imageChoiceWords.add(vocabularyId);
      if (!pictureWords.has(vocabularyId)) pictureless.push(`${name} ${vocabularyId}`);
    }
  }
}
check(
  `${imageChoiceWords.size} picture words reach the app inside a real picture drill, and no picture drill points at a word without a file`,
  pictureless.length === 0 && imageChoiceWords.size > 0,
  `${pictureless.length} pictureless drills: ${pictureless.slice(0, 3).join(', ')}`,
);
const neverShown = [...pictureWords].filter((word) => !imageChoiceWords.has(word));
check(
  `the ${neverShown.length} picture words the app only ever drills as text are a gap only the build can reveal`,
  neverShown.length < pictureWords.size,
  `${pictureWords.size} picture words taught, ${imageChoiceWords.size} drilled with a picture: ${neverShown.slice(0, 6).join(', ')}`,
);
const drillFlagMismatch = derivedImages.filter(
  ({ fileId, drilled }) => drilled !== imageChoiceWords.has(fileId.slice(2)),
);
check(
  `${derivedImages.filter((image) => image.drilled).length} of the ${derivedImages.length} picture rows the panels show are marked as quizzed by a real picture drill, flag by flag`,
  drillFlagMismatch.length === 0,
  `${drillFlagMismatch.length} flags disagree: ${drillFlagMismatch
    .slice(0, 4)
    .map(({ gen, fileId, drilled }) => `${gen} ${fileId} drilled=${drilled}`)
    .join(', ')}`,
);

const toPosix = (p) => p.replace(/\\/g, '/');
const resolve = (fileId) => {
  try {
    return toPosix(cms.mediaFile(courseId, fileId).file);
  } catch {
    return null;
  }
};
check(
  'picture key resolves inside the course media tree',
  resolve('i.u1.friend') ===
    toPosix(path.join(repoRoot, 'content', courseId, 'media', 'images', 'i.u1.friend.webp')),
  String(resolve('i.u1.friend')),
);
check('clip key gets the .aac suffix', resolve('a.u1.s1.n')?.endsWith('/media/audio/a.u1.s1.n.aac') === true);
check('traversal in fileId refused', resolve('../../package.json') === null);
check('empty or dot-prefixed fileId refused', resolve('.bashrc') === null && resolve('a..n') === null);
check(
  'traversal in courseId refused',
  (() => {
    try {
      cms.mediaFile('../../etc', 'passwd');
      return false;
    } catch {
      return true;
    }
  })(),
);

const served = await cms.readMedia(courseId, 'i.u1.friend');
check(
  'preview route reads the real bytes',
  served?.body.byteLength === statSync(path.join(repoRoot, 'content', courseId, 'media', 'images', 'i.u1.friend.webp')).size &&
    served?.mime === 'image/webp',
  `${served?.body.byteLength} bytes ${served?.mime}`,
);
check('unknown fileId is a clean miss', (await cms.readMedia(courseId, 'i.u1.not_a_word')) === null);

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} media checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: the media the CMS shows is the media the app bundles (${derived} rows, ${derivedAnywhere.size} distinct ids covering the ${shipped.size} the build ships; ${buildOnly.length} of them exist only in the build), the ${lessonDrills} drills of the unit lessons are tallied the way the bundles count them, and of the ${pictureWords.size} words the editor gave a picture only ${imageChoiceWords.size} ever meet a picture drill — ${neverShown.length} are shipped and silently drilled as text, ${unusedPictures.size} are carried by no lesson at all.`,
);
