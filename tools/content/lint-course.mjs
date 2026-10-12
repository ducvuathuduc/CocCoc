// `node tools/content/lint-course.mjs` — content lint for the v2 course (builds in memory; no writes).
// Fails (exit 1) on any error. Checks, beyond Learning's publish validator (validateCourse):
//   source tables  : unique vocabulary ids/headwords; no sentence/dialogue uses a word before the unit
//                    that introduces it; every level has enough sentences; English casing/punctuation;
//                    Vietnamese text carries diacritics; no duplicate sentences; one audio key per sentence
//   generated path : globally unique lesson/exercise ids; every vocabularyId was introduced earlier on the
//                    path (or by a new-word item earlier in the same lesson); every audio prompt key is in
//                    the audio catalog; choice/pair/token texts unambiguous; fillBlank has one blank
//   grading        : the real Learning grader (services/learning/src/domain/grading.ts) accepts the
//                    authored key and EVERY acceptedText variant, and rejects a wrong answer
//   schema         : every bundle + the manifest validate against OpenAPI LessonBundle/CourseManifest
//   coverage       : >= 2 sections, >= 12 units, >= 400 lessons, all 12 exercise types
//   determinism    : content/vi_en/source/v2/build-report.json equals the in-memory build (manifestSha256)
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { build } from 'esbuild';
import { root } from '../../content/tools/lib.mjs';
import { buildCourse } from './build-course.mjs';
import { tokenize } from './course-lib.mjs';

const errors = [];
const warnings = [];
const err = (where, msg) => errors.push(`${where}: ${msg}`);
const warn = (where, msg) => warnings.push(`${where}: ${msg}`);

const graderFile = path.join(root, '.cache/content-tools/grading.mjs');
await build({
  entryPoints: [path.join(root, 'services/learning/src/domain/grading.ts')],
  outfile: graderFile,
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  logLevel: 'warning',
});
const { gradeAnswer } = await import(`${pathToFileURL(graderFile).href}?t=${Date.now()}`);

const built = await buildCourse();
const { data, manifest, finished, placement, audioCatalog, report } = built;
for (const p of built.problems) err(p.where, `validator ${p.problem}`);
// Determinism / staleness: the committed build report must equal this in-memory build.
const reportPath = path.join(root, 'content/vi_en/source/v2/build-report.json');
if (
  !fs.existsSync(reportPath) ||
  fs.readFileSync(reportPath, 'utf8') !== `${JSON.stringify(report, null, 2)}\n`
)
  err('build-report.json', 'stale or missing; run node tools/content/build-course.mjs');

// ---------- source tables ----------
const VI_MARKS = /[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;
const headwords = new Map();
for (const v of data.allVocab) {
  const key = v.en.toLowerCase();
  if (headwords.has(key)) err(v.vocabularyId, `headword "${v.en}" also in ${headwords.get(key)}`);
  headwords.set(key, v.vocabularyId);
}
const seenEn = new Map();
const audioKeys = new Set();
for (const u of data.units) {
  if (u.vocab.length < 16) err(u.unitId, `only ${u.vocab.length} words`);
  for (let L = 1; L <= 5; L++) {
    const n = u.sentences.filter((s) => s.level === L).length;
    if (n < 3) err(`${u.unitId} level ${L}`, `only ${n} sentences (need >= 3)`);
    if (!u.vocab.some((v) => v.level === L)) err(`${u.unitId} level ${L}`, 'no new words');
  }
  if (u.story.questions.length < 6) err(u.unitId, 'story needs 6 questions');
  for (const q of u.story.questions)
    if (new Set(q.choices).size !== q.choices.length) err(u.unitId, `story choices repeat: ${q.q}`);
  const unitRank = data.unitIndex.get(u.unitId);
  for (const item of [...u.sentences, ...u.dialogues]) {
    const where = `${u.unitId}.${item.key}`;
    const later = item.vocab.filter((v) => data.unitIndex.get(v.unitId) > unitRank);
    if (later.length)
      err(
        where,
        `uses later words ${later.map((v) => v.vocabularyId).join(', ')} in "${item.en ?? item.reply}"`,
      );
    if (!item.vocab.some((v) => v.unitId === u.unitId) && item.en)
      warn(where, `no ${u.unitId} word in "${item.en}"`);
    if (audioKeys.has(item.audioKey)) err(where, 'duplicate audio key');
    audioKeys.add(item.audioKey);
  }
  for (const s of u.sentences) {
    const where = `${u.unitId}.${s.key}`;
    for (const en of [s.en, ...s.enAlts]) {
      if (!/^[A-Z0-9"]/.test(en) || !/[.?!]$/.test(en))
        err(where, `English casing/punctuation: "${en}"`);
      if (/\s{2,}|\s[,.?!]/.test(en)) err(where, `spacing: "${en}"`);
    }
    for (const vi of [s.vi, ...s.viAlts]) {
      if (!/[.?!]$/.test(vi)) err(where, `Vietnamese punctuation: "${vi}"`);
      if (tokenize(vi).length > 2 && !VI_MARKS.test(vi))
        warn(where, `Vietnamese without diacritics? "${vi}"`);
    }
    const key = s.en.toLowerCase();
    if (seenEn.has(key)) err(where, `duplicate sentence (also ${seenEn.get(key)}): "${s.en}"`);
    seenEn.set(key, where);
  }
}
const catalogKeys = new Set(audioCatalog.items.map((i) => `${i.key}`));
for (const u of data.units)
  for (const s of u.sentences)
    if (!catalogKeys.has(s.audioKey)) err(s.audioKey, 'sentence missing from audio catalog');

// ---------- generated path ----------
const ajv = new Ajv({ strict: false, allErrors: false });
formats(ajv);
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
const schema = (name) =>
  ajv.compile({ $ref: `https://cocenglish.example.invalid/schema#/components/schemas/${name}` });
const vManifest = schema('CourseManifest');
const vBundle = schema('LessonBundle');
if (!vManifest(manifest))
  err('manifest', `OpenAPI: ${JSON.stringify(vManifest.errors?.slice(0, 2))}`);

const allIds = new Set();
const introducedSoFar = new Set();
const say = (text) => ({ kind: 'text', text });
function correctAnswer(ex) {
  const r = ex.gradingRule;
  if (r.acceptedText) return say(r.acceptedText[0]);
  if (r.correctChoiceId) return { kind: 'choice', choiceId: r.correctChoiceId };
  if (r.correctTokenIds) return { kind: 'tokens', tokenIds: r.correctTokenIds };
  return {
    kind: 'pairs',
    matches: ex.content.pairs.map((p) => ({ leftId: p.left.id, rightId: p.right.id })),
  };
}
function wrongAnswer(ex) {
  const r = ex.gradingRule;
  if (r.acceptedText) return say('zzqx wrong answer');
  if (r.correctChoiceId)
    return {
      kind: 'choice',
      choiceId: ex.content.choices.find((c) => c.id !== r.correctChoiceId).id,
    };
  if (r.correctTokenIds) {
    const ids = [...r.correctTokenIds];
    return {
      kind: 'tokens',
      tokenIds:
        ids.length > 1
          ? [...ids.slice(1), ids[0]]
          : ex.content.tokens
              .filter((t) => t.id !== ids[0])
              .slice(0, 1)
              .map((t) => t.id),
    };
  }
  const ps = ex.content.pairs;
  return {
    kind: 'pairs',
    matches: ps.map((p, i) => ({ leftId: p.left.id, rightId: ps[(i + 1) % ps.length].right.id })),
  };
}
function checkExercise(ex, where, inLesson, isPlacement) {
  if (allIds.has(`${where}/${ex.id}`)) err(where, `duplicate exercise id ${ex.id}`);
  allIds.add(`${where}/${ex.id}`);
  // grading
  try {
    if (!gradeAnswer(ex, correctAnswer(ex)).correct)
      err(`${where}/${ex.id}`, 'authored key rejected by grader');
    if (gradeAnswer(ex, wrongAnswer(ex)).correct)
      err(`${where}/${ex.id}`, 'wrong answer accepted by grader');
    for (const t of ex.gradingRule.acceptedText ?? [])
      if (!gradeAnswer(ex, say(t)).correct) err(`${where}/${ex.id}`, `variant rejected: "${t}"`);
  } catch (e) {
    err(`${where}/${ex.id}`, `grader threw ${e.message}`);
  }
  const accepted = ex.gradingRule.acceptedText ?? [];
  const norm = new Set();
  for (const t of accepted) {
    const n = t
      .normalize('NFC')
      .toLowerCase()
      .replace(/[\p{P}\p{S}]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!n) err(`${where}/${ex.id}`, 'empty normalized answer');
    if (norm.has(n)) warn(`${where}/${ex.id}`, `duplicate variant "${t}"`);
    norm.add(n);
  }
  const c = ex.content;
  if (c.choices) {
    const texts = c.choices.map((x) => x.text.toLowerCase());
    if (new Set(texts).size !== texts.length)
      err(`${where}/${ex.id}`, `duplicate choice text ${JSON.stringify(texts)}`);
  }
  if (c.pairs) {
    const l = c.pairs.map((p) => p.left.text.toLowerCase());
    const r = c.pairs.map((p) => p.right.text.toLowerCase());
    if (new Set(l).size !== l.length || new Set(r).size !== r.length)
      err(`${where}/${ex.id}`, 'pair texts not unique');
    const vocabOrder = ex.vocabularyIds.map((id) =>
      data.allVocab.find((v) => v.vocabularyId === id)?.en.toLowerCase(),
    );
    if (vocabOrder.join('|') !== l.join('|'))
      err(`${where}/${ex.id}`, 'vocabularyIds not in pair order');
  }
  if (ex.type === 'fillBlank' && (ex.prompt.text.match(/___/g) ?? []).length !== 1)
    err(`${where}/${ex.id}`, 'fillBlank needs exactly one ___');
  if (ex.type === 'sentenceOrder' || ex.type === 'wordBank') {
    const byId = new Map(c.tokens.map((t) => [t.id, t.text]));
    const sentence = ex.gradingRule.correctTokenIds
      .map((id) => byId.get(id))
      .join(' ')
      .toLowerCase();
    if (!/[a-zà-ỹđ]/i.test(sentence)) err(`${where}/${ex.id}`, 'empty token sentence');
  }
  // audio keys
  const audio = ex.prompt.audioAssetId;
  if (audio && !catalogKeys.has(audio.replace(/\.(n|s)$/, '')))
    err(`${where}/${ex.id}`, `audio ${audio} not in catalog`);
  // vocabulary introduced before tested
  if (!isPlacement) {
    if (/^Từ mới!/.test(ex.prompt.text)) for (const id of ex.vocabularyIds) inLesson.add(id);
    for (const id of ex.vocabularyIds)
      if (!introducedSoFar.has(id) && !inLesson.has(id))
        err(`${where}/${ex.id}`, `tests ${id} before it is introduced`);
  }
  for (const alt of [ex.nonAudioAlternative, ex.nonSpeechAlternative].filter(Boolean))
    checkExercise(alt, `${where}/${ex.id}`, inLesson, isPlacement);
}
const lessonIds = new Set();
for (const f of finished) {
  const b = f.bundle;
  if (lessonIds.has(b.lessonId)) err(b.lessonId, 'duplicate lessonId');
  lessonIds.add(b.lessonId);
  if (!vBundle(b)) err(b.lessonId, `OpenAPI: ${JSON.stringify(vBundle.errors?.slice(0, 2))}`);
  if (b.exercises.length < 10 || b.exercises.length > 15)
    err(b.lessonId, `${b.exercises.length} exercises (want 10-15)`);
  const inLesson = new Set();
  for (const ex of b.exercises) checkExercise(ex, b.lessonId, inLesson, false);
  for (const id of inLesson) introducedSoFar.add(id);
}
if (!vBundle(placement.bundle))
  err('placement', `OpenAPI: ${JSON.stringify(vBundle.errors?.slice(0, 2))}`);
for (const ex of placement.bundle.exercises) checkExercise(ex, 'placement', new Set(), true);
for (const v of data.allVocab)
  if (!introducedSoFar.has(v.vocabularyId))
    err(v.vocabularyId, 'never introduced by a new-word item');

for (const id of report.ambiguousTiles)
  err(id, 'token exercise whose sentence has a same-tiles alternative');

// ---------- coverage ----------
if (report.sections < 2) err('course', 'needs >= 2 sections');
if (report.units < 12) err('course', 'needs >= 12 units');
if (report.lessons < 400) err('course', `needs >= 400 lessons (has ${report.lessons})`);
if (Object.keys(report.exerciseTypes).length !== 12)
  err('course', `types ${Object.keys(report.exerciseTypes)}`);

const limit = process.argv.includes('--all') ? Infinity : 60;
if (warnings.length)
  console.error(`${warnings.length} warnings\n${warnings.slice(0, limit).join('\n')}`);
if (errors.length) {
  console.error(`${errors.length} errors\n${errors.slice(0, limit).join('\n')}`);
  process.exit(1);
}
console.log(
  JSON.stringify({
    status: 'PASS',
    scope:
      'v2 content lint: source tables, introduction order, grader round-trip, OpenAPI schemas, coverage',
    lessons: report.lessons,
    exercises: report.exercises,
    warnings: warnings.length,
  }),
);
