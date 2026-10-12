// `node content/tools/build-content.mjs [--check]` — generate the signed vi_en course version from
// content/vi_en/source/curriculum.mjs into content/vi_en/dist/<version>/:
//   manifest.json, bundles/<lessonId>.json (canonical JSON), publish.json (file ids + sha256).
// --check rebuilds in memory and fails if dist differs (deterministic, no network).
// Signing key: COC_CONTENT_SIGNING_SEED_HEX + COC_CONTENT_SIGNING_KEY_ID, else the well-known
// DEV key (dev-content-1). Dev-signed content is trusted only by dev/test keyrings.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { course, nodePlan, sections, units } from '../vi_en/source/curriculum.mjs';
import { loadContentTools, root } from './lib.mjs';

const VERSION = 'v1';
const GRADING_RULES_VERSION = 'g1';
const tools = await loadContentTools();
const {
  canonicalJson,
  sha256,
  signText,
  manifestStructureHash,
  manifestSigningInput,
  bundleSigningInput,
} = tools;

const seedHex = process.env.COC_CONTENT_SIGNING_SEED_HEX;
const privateKey = seedHex
  ? tools.ed25519FromSeed(Buffer.from(seedHex, 'hex'))
  : tools.devContentPrivateKey();
const keyId = seedHex ? process.env.COC_CONTENT_SIGNING_KEY_ID : tools.DEV_CONTENT_KEY_ID;
assert.ok(keyId, 'COC_CONTENT_SIGNING_KEY_ID is required with a custom seed');

// ---------- deterministic helpers ----------
const at = (list, index) => list[((index % list.length) + list.length) % list.length];
function rng(seedText) {
  let h = parseInt(sha256(seedText).slice(0, 8), 16) || 1;
  return () => {
    h ^= h << 13;
    h ^= h >>> 17;
    h ^= h << 5;
    return ((h >>> 0) % 1_000_000) / 1_000_000;
  };
}
function shuffle(list, seedText) {
  const next = rng(seedText);
  const out = [...list];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}
const words = (sentence) =>
  sentence
    .replace(/[.,!?]/g, '')
    .split(/\s+/)
    .filter(Boolean);
const TEXT_RULE = { caseSensitive: false, ignorePunctuation: true, ignoreDiacritics: false };
const KEY_RULE = { caseSensitive: false, ignorePunctuation: false, ignoreDiacritics: false };

function audioAssets(unitId, key, transcript) {
  const n = words(transcript).length;
  const base = `a.${unitId}.${key}`;
  const make = (suffix, speed, perWord) => ({
    fileId: `${base}.${suffix}`,
    sha256: sha256(`placeholder-audio:${base}.${suffix}:${transcript}`),
    mime: 'audio/aac',
    bytes: 4000 + n * 3000,
    durationMs: 600 + n * perWord,
    width: null,
    height: null,
    locale: 'en-US',
    voice: 'en-US-neutral-1',
    speed,
    provider: null,
    modelVersion: null,
    altText: transcript.slice(0, 256),
  });
  return [make('n', 1, 420), make('s', 0.75, 560)];
}
function imageAsset(unitId, vocab) {
  return {
    fileId: `i.${unitId}.${vocab.id}`,
    sha256: sha256(`placeholder-image:${unitId}.${vocab.id}`),
    mime: 'image/webp',
    bytes: 18000,
    durationMs: null,
    width: 512,
    height: 512,
    locale: null,
    voice: null,
    speed: null,
    provider: null,
    modelVersion: null,
    altText: `Hình minh họa: ${vocab.vi} (${vocab.en})`,
  };
}

// ---------- exercise generators ----------
function makeGenerators(unit, bundleAssets) {
  const u = unit.unitId;
  const vocabId = (v) => `${u}.${v}`;
  const sentenceVocab = (s) => s.vocab.map(vocabId);
  const addAssets = (list) => list.forEach((a) => bundleAssets.set(a.fileId, a));
  const sentenceAudio = (s) => {
    const list = audioAssets(u, s.id, s.en);
    addAssets(list);
    return list[0].fileId;
  };
  const choiceSet = (correct, pool, count, seed) => {
    const distractors = pool.filter((x) => x !== correct).slice(0, count - 1);
    return shuffle([correct, ...distractors], seed);
  };
  const others = (list, item, offset) =>
    [...list.slice(offset), ...list.slice(0, offset)].filter((x) => x !== item);

  return {
    choice(id, i) {
      const v = at(unit.vocab, i);
      const enToVi = i % 2 === 0;
      const pool = others(unit.vocab, v, i + 1).map((x) => (enToVi ? x.vi : x.en));
      const texts = choiceSet(enToVi ? v.vi : v.en, pool, 4, id);
      const choices = texts.map((text, k) => ({ id: `c${k + 1}`, text }));
      const correct = choices.find((c) => c.text === (enToVi ? v.vi : v.en));
      return {
        id,
        type: 'choice',
        prompt: enToVi
          ? { text: `Chọn nghĩa đúng của "${v.en}"`, locale: 'vi-VN' }
          : { text: `"${v.vi}" trong tiếng Anh là gì?`, locale: 'vi-VN' },
        content: { choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: correct.id },
        hint: `"${v.en}" nghĩa là "${v.vi}".`,
        explanation: `"${v.en}" = "${v.vi}".`,
        skillIds: [`${u}.vocab`],
        vocabularyIds: [vocabId(v.id)],
      };
    },
    matchPairs(id, i) {
      const items = [0, 1, 2, 3, 4].map((k) => at(unit.vocab, i + k * 2));
      const unique = [...new Map(items.map((v) => [v.id, v])).values()].slice(0, 5);
      const pairs = unique.map((v, k) => ({
        id: `p${k + 1}`,
        left: { id: `p${k + 1}l`, text: v.en },
        right: { id: `p${k + 1}r`, text: v.vi },
      }));
      return {
        id,
        type: 'matchPairs',
        prompt: { text: 'Nối các cặp từ tương ứng', locale: 'vi-VN' },
        content: { pairs },
        gradingRule: { ...KEY_RULE, correctPairIds: pairs.map((p) => p.id) },
        hint: `Ví dụ: "${unique[0].en}" = "${unique[0].vi}".`,
        explanation: unique.map((v) => `${v.en} = ${v.vi}`).join('; '),
        skillIds: [`${u}.vocab`],
        vocabularyIds: unique.map((v) => vocabId(v.id)),
      };
    },
    textTranslation(id, i) {
      const s = at(unit.sentences, i);
      return {
        id,
        type: 'textTranslation',
        prompt: { text: s.vi, locale: 'vi-VN' },
        content: { placeholder: 'Viết bằng tiếng Anh', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: [s.en, ...s.enAlts] },
        hint: `Bắt đầu bằng: "${words(s.en).slice(0, 2).join(' ')} ..."`,
        explanation: `Đáp án: "${s.en}".`,
        skillIds: [`${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
      };
    },
    textTranslationEnVi(id, i) {
      const s = at(unit.sentences, i + 3);
      return {
        id,
        type: 'textTranslation',
        prompt: { text: s.en, locale: 'en-US' },
        content: { placeholder: 'Viết bằng tiếng Việt (có dấu)', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: [s.vi, ...s.viAlts] },
        hint: 'Nhớ gõ đủ dấu tiếng Việt.',
        explanation: `Đáp án: "${s.vi}".`,
        skillIds: [`${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
      };
    },
    wordBank(id, i) {
      const s = at(unit.sentences, i + 1);
      const target = words(s.en);
      const distractorPool = unit.sentences
        .filter((x) => x !== s)
        .flatMap((x) => words(x.en))
        .filter((w) => !target.map((t) => t.toLowerCase()).includes(w.toLowerCase()));
      const distractors = [...new Set(shuffle(distractorPool, `${id}:d`))].slice(0, 3);
      const all = shuffle(
        [
          ...target.map((text, k) => ({ key: `w${k}`, text })),
          ...distractors.map((text, k) => ({ key: `x${k}`, text })),
        ],
        id,
      );
      const tokens = all.map((t, k) => ({ id: `t${k + 1}`, text: t.text, key: t.key }));
      const correctTokenIds = target.map((_, k) => tokens.find((t) => t.key === `w${k}`).id);
      return {
        id,
        type: 'wordBank',
        prompt: { text: `Dịch câu này: "${s.vi}"`, locale: 'vi-VN' },
        content: { tokens: tokens.map(({ id: tid, text }) => ({ id: tid, text })) },
        gradingRule: { ...KEY_RULE, correctTokenIds },
        hint: `Từ đầu tiên là "${target[0]}".`,
        explanation: `Câu đúng: "${s.en}".`,
        skillIds: [`${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
      };
    },
    sentenceOrder(id, i, extra = {}) {
      const s = at(unit.sentences, i + 2);
      const target = words(s.en);
      const order = shuffle(
        target.map((text, k) => ({ key: k, text })),
        id,
      );
      const tokens = order.map((t, k) => ({ id: `t${k + 1}`, text: t.text, key: t.key }));
      return {
        id,
        type: 'sentenceOrder',
        prompt: { text: `Sắp xếp thành câu đúng: "${s.vi}"`, locale: 'vi-VN' },
        content: { tokens: tokens.map(({ id: tid, text }) => ({ id: tid, text })) },
        gradingRule: {
          ...KEY_RULE,
          correctTokenIds: target.map((_, k) => tokens.find((t) => t.key === k).id),
        },
        hint: `Câu bắt đầu bằng "${target[0]}".`,
        explanation: `Câu đúng: "${s.en}".`,
        skillIds: [`${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
        ...extra,
      };
    },
    fillBlank(id, i) {
      const f = at(unit.fills, i);
      return {
        id,
        type: 'fillBlank',
        prompt: { text: f.text, locale: 'en-US' },
        content: { placeholder: 'Điền từ còn thiếu', maxChars: 40 },
        gradingRule: { ...TEXT_RULE, acceptedText: [f.answer, ...f.alts] },
        hint: `Nghĩa của câu: "${f.vi}"`,
        explanation: `Từ đúng: "${f.answer}" → ${f.text.replace('___', f.answer)}`,
        skillIds: [`${u}.grammar`],
        vocabularyIds: f.vocab.map(vocabId),
      };
    },
    imageChoice(id, i) {
      const withImages = unit.vocab.filter((v) => v.img);
      const v = at(withImages, i);
      const options = choiceSet(v, others(withImages, v, i + 1), 4, id);
      options.forEach((o) => bundleAssets.set(`i.${u}.${o.id}`, imageAsset(u, o)));
      const choices = options.map((o, k) => ({
        id: `c${k + 1}`,
        text: o.en,
        imageAssetId: `i.${u}.${o.id}`,
      }));
      return {
        id,
        type: 'imageChoice',
        prompt: { text: `Hình nào là "${v.vi}"?`, locale: 'vi-VN' },
        content: { choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: choices[options.indexOf(v)].id },
        hint: `"${v.vi}" là "${v.en}".`,
        explanation: `"${v.en}" = "${v.vi}".`,
        skillIds: [`${u}.vocab`],
        vocabularyIds: [vocabId(v.id)],
      };
    },
    listenChoice(id, i) {
      const s = at(unit.sentences, i + 4);
      const texts = choiceSet(
        s.en,
        others(unit.sentences, s, i + 5).map((x) => x.en),
        3,
        id,
      );
      const choices = texts.map((text, k) => ({ id: `c${k + 1}`, text }));
      const correctChoiceId = choices.find((c) => c.text === s.en).id;
      const base = {
        content: { choices },
        gradingRule: { ...KEY_RULE, correctChoiceId },
        hint: `Câu có nghĩa: "${s.vi}"`,
        explanation: `Bạn nghe: "${s.en}" (${s.vi}).`,
        skillIds: ['listening', `${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
      };
      return {
        id,
        type: 'listenChoice',
        prompt: {
          text: 'Nghe và chọn câu bạn nghe được',
          locale: 'vi-VN',
          audioAssetId: sentenceAudio(s),
        },
        ...base,
        nonAudioAlternative: {
          id: `${id}a`,
          type: 'choice',
          prompt: { text: `Chọn câu tiếng Anh có nghĩa: "${s.vi}"`, locale: 'vi-VN' },
          ...base,
        },
      };
    },
    dictation(id, i) {
      const s = at(unit.sentences, i + 6);
      return {
        id,
        type: 'dictation',
        prompt: {
          text: 'Nghe và viết lại bằng tiếng Anh',
          locale: 'vi-VN',
          audioAssetId: sentenceAudio(s),
        },
        content: { placeholder: 'Viết những gì bạn nghe', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: [s.en, ...s.enAlts] },
        hint: `Câu có ${words(s.en).length} từ.`,
        explanation: `Bạn nghe: "${s.en}".`,
        skillIds: ['listening', `${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
        nonAudioAlternative: {
          id: `${id}a`,
          type: 'textTranslation',
          prompt: { text: s.vi, locale: 'vi-VN' },
          content: { placeholder: 'Viết bằng tiếng Anh', maxChars: 200 },
          gradingRule: { ...TEXT_RULE, acceptedText: [s.en, ...s.enAlts] },
          hint: `Câu có ${words(s.en).length} từ.`,
          explanation: `Đáp án: "${s.en}".`,
          skillIds: ['listening', `${u}.grammar`],
          vocabularyIds: sentenceVocab(s),
        },
      };
    },
    speakRepeat(id, i) {
      const s = at(unit.sentences, i + 5);
      const alternative = this.sentenceOrder(`${id}a`, i + 3);
      const forced = at(unit.sentences, i + 5);
      // Alternative orders the same sentence as the spoken one.
      const target = words(forced.en);
      const order = shuffle(
        target.map((text, k) => ({ key: k, text })),
        `${id}a`,
      );
      const tokens = order.map((t, k) => ({ id: `t${k + 1}`, text: t.text, key: t.key }));
      return {
        id,
        type: 'speakRepeat',
        prompt: { text: `Nói câu sau: "${s.en}"`, locale: 'en-US', audioAssetId: sentenceAudio(s) },
        content: { referenceText: s.en, locale: 'en-US', maxSeconds: 10 },
        gradingRule: { ...TEXT_RULE, acceptedText: [s.en, ...s.enAlts] },
        hint: `Nghĩa: "${s.vi}"`,
        explanation: `Câu mẫu: "${s.en}".`,
        skillIds: ['speaking', `${u}.grammar`],
        vocabularyIds: sentenceVocab(s),
        nonSpeechAlternative: {
          ...alternative,
          prompt: { text: `Sắp xếp thành câu đúng: "${s.vi}"`, locale: 'vi-VN' },
          content: { tokens: tokens.map(({ id: tid, text }) => ({ id: tid, text })) },
          gradingRule: {
            ...KEY_RULE,
            correctTokenIds: target.map((_, k) => tokens.find((t) => t.key === k).id),
          },
          explanation: `Câu đúng: "${s.en}".`,
          hint: `Câu bắt đầu bằng "${target[0]}".`,
          skillIds: ['speaking', `${u}.grammar`],
          vocabularyIds: sentenceVocab(s),
        },
      };
    },
    dialogueTurn(id, i) {
      const d = at(unit.dialogues, i);
      const list = audioAssets(u, d.id, d.line);
      addAssets(list);
      const replies = choiceSet(
        d.reply,
        others(unit.dialogues, d, i + 1).map((x) => x.reply),
        3,
        id,
      );
      const choices = replies.map((text, k) => ({ id: `c${k + 1}`, text }));
      return {
        id,
        type: 'dialogueTurn',
        prompt: { text: d.line, locale: 'en-US', audioAssetId: list[0].fileId },
        content: { referenceText: d.reply, locale: 'en-US', maxSeconds: 12 },
        gradingRule: { ...TEXT_RULE, acceptedText: [d.reply, ...d.replyAlts] },
        hint: `Gợi ý trả lời: "${d.vi}"`,
        explanation: `Câu trả lời mẫu: "${d.reply}".`,
        skillIds: ['speaking', `${u}.dialogue`],
        vocabularyIds: d.vocab.map(vocabId),
        nonSpeechAlternative: {
          id: `${id}a`,
          type: 'choice',
          prompt: { text: `"${d.line}" — chọn câu trả lời phù hợp`, locale: 'vi-VN' },
          content: { choices },
          gradingRule: { ...KEY_RULE, correctChoiceId: choices.find((c) => c.text === d.reply).id },
          hint: `Gợi ý trả lời: "${d.vi}"`,
          explanation: `Câu trả lời mẫu: "${d.reply}".`,
          skillIds: ['speaking', `${u}.dialogue`],
          vocabularyIds: d.vocab.map(vocabId),
        },
      };
    },
    storyQuestion(id, i) {
      const q = at(unit.story.questions, i);
      const choices = q.choices.map((text, k) => ({ id: `c${k + 1}`, text }));
      return {
        id,
        type: 'storyQuestion',
        prompt: { text: q.q, locale: 'en-US' },
        content: { passage: unit.story.passage, question: q.q, choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: choices[q.correct].id },
        hint: `Đọc lại câu chuyện "${unit.story.title}".`,
        explanation: `Đáp án: "${q.choices[q.correct]}".`,
        skillIds: ['reading', `${u}.story`],
        vocabularyIds: [],
      };
    },
  };
}

const LESSON_TYPES = {
  lesson: [
    'choice',
    'matchPairs',
    'textTranslation',
    'wordBank',
    'fillBlank',
    'imageChoice',
    'sentenceOrder',
    'textTranslationEnVi',
    'listenChoice',
    'dictation',
  ],
  listening: [
    'listenChoice',
    'dictation',
    'choice',
    'listenChoice',
    'wordBank',
    'dictation',
    'matchPairs',
    'listenChoice',
    'textTranslation',
    'dictation',
  ],
  story: [
    'storyQuestion',
    'storyQuestion',
    'choice',
    'sentenceOrder',
    'storyQuestion',
    'wordBank',
    'fillBlank',
    'storyQuestion',
    'textTranslation',
    'matchPairs',
  ],
  speaking: [
    'speakRepeat',
    'dialogueTurn',
    'wordBank',
    'speakRepeat',
    'choice',
    'dialogueTurn',
    'fillBlank',
    'speakRepeat',
    'dialogueTurn',
    'textTranslation',
  ],
  mastery: [
    'textTranslation',
    'wordBank',
    'fillBlank',
    'dictation',
    'sentenceOrder',
    'textTranslationEnVi',
    'listenChoice',
    'dialogueTurn',
    'storyQuestion',
    'imageChoice',
  ],
  placement: [
    'choice',
    'textTranslation',
    'wordBank',
    'fillBlank',
    'matchPairs',
    'sentenceOrder',
    'choice',
    'textTranslation',
    'storyQuestion',
    'imageChoice',
  ],
};

function generateExercises(unit, kind, lessonId, seed, assets) {
  const gens = makeGenerators(unit, assets);
  const counts = {};
  return LESSON_TYPES[kind].map((type, j) => {
    counts[type] = (counts[type] ?? 0) + 1;
    const id = `${lessonId}-e${String(j + 1).padStart(2, '0')}`;
    const index =
      seed * 3 + counts[type] - 1 + (kind === 'story' && type === 'storyQuestion' ? -seed * 3 : 0);
    return gens[type].call(gens, id, index);
  });
}

// ---------- assemble ----------
const nodes = [];
const bundleDrafts = [];
let order = 0;
const manifestUnits = units.map((unit, unitIndex) => {
  const section = sections.find((s) => s.unitIds.includes(unit.unitId));
  const nodeIds = [];
  nodePlan[unitIndex].forEach((kind, n) => {
    const nodeId = `${unit.unitId}n${n + 1}`;
    nodeIds.push(nodeId);
    const lessonIds = [1, 2].map((l) => `${nodeId}l${l}`);
    nodes.push({
      nodeId,
      unitId: unit.unitId,
      sectionId: section.sectionId,
      order,
      title: unit.nodeTitles[n],
      kind,
      lessonIds,
    });
    lessonIds.forEach((lessonId, l) => {
      const assets = new Map();
      const exercises = generateExercises(unit, kind, lessonId, n * 2 + l, assets);
      bundleDrafts.push({
        schemaVersion: 1,
        courseId: course.courseId,
        courseVersion: VERSION,
        sectionId: section.sectionId,
        unitId: unit.unitId,
        nodeId,
        order,
        lessonId,
        lessonVersion: `${VERSION}.${lessonId}`,
        rewardIdentity: lessonId,
        title: `${unit.nodeTitles[n]} · Bài ${l + 1}`,
        skillIds: [...new Set(exercises.flatMap((e) => e.skillIds))].slice(0, 20),
        guideText: unit.guideText,
        exercises,
        assets: [...assets.values()].sort((a, b) => (a.fileId < b.fileId ? -1 : 1)),
        gradingRulesVersion: GRADING_RULES_VERSION,
      });
    });
    order++;
  });
  return {
    unitId: unit.unitId,
    sectionId: section.sectionId,
    title: unit.title,
    guideText: unit.guideText,
    nodeIds,
  };
});
const placementAssets = new Map();
const placementExercises = generateExercises(
  units[0],
  'placement',
  'placement',
  7,
  placementAssets,
);
const placementDraft = {
  schemaVersion: 1,
  courseId: course.courseId,
  courseVersion: VERSION,
  sectionId: 'sec1',
  unitId: 'u1',
  nodeId: 'placement',
  order: 0,
  lessonId: 'placement',
  lessonVersion: `${VERSION}.placement`,
  rewardIdentity: 'placement',
  title: 'Kiểm tra trình độ',
  skillIds: [...new Set(placementExercises.flatMap((e) => e.skillIds))],
  guideText: 'Trả lời đúng ít nhất 8/10 câu để bắt đầu từ Unit 2.',
  exercises: placementExercises,
  assets: [...placementAssets.values()],
  gradingRulesVersion: GRADING_RULES_VERSION,
};

const structure = {
  schemaVersion: 1,
  courseId: course.courseId,
  courseVersion: VERSION,
  sourceLocale: course.sourceLocale,
  targetLocale: course.targetLocale,
  title: course.title,
  sections,
  units: manifestUnits,
  nodes,
};
const manifestHash = manifestStructureHash(structure);
const fileIdOf = (lessonId) => `${course.courseId}.${VERSION}.${lessonId}`;
function finishBundle(draft) {
  const unsigned = { ...draft, manifestHash };
  const signed = {
    ...unsigned,
    signatureKeyId: keyId,
    signature: signText(privateKey, bundleSigningInput(unsigned)),
  };
  const text = canonicalJson(signed);
  return {
    bundle: signed,
    text,
    index: {
      lessonId: draft.lessonId,
      lessonVersion: draft.lessonVersion,
      rewardIdentity: draft.rewardIdentity,
      fileId: fileIdOf(draft.lessonId),
      sha256: sha256(text),
    },
  };
}
const finished = bundleDrafts.map(finishBundle);
const placement = finishBundle(placementDraft);
const unsignedManifest = {
  ...structure,
  bundles: finished.map((f) => f.index),
  placementBundle: placement.index,
  manifestHash,
};
const manifest = {
  ...unsignedManifest,
  signatureKeyId: keyId,
  signature: signText(privateKey, manifestSigningInput(unsignedManifest)),
};
const manifestText = canonicalJson(manifest);

const problems = tools.validateCourse(manifest, [...finished.map((f) => f.bundle)]);
problems.push(...tools.validateBundle(placement.bundle, 'placement'));
if (problems.length) {
  console.error(JSON.stringify(problems.slice(0, 40), null, 2));
  throw new Error(`${problems.length} content problems`);
}

const outDir = path.join(root, `content/${course.courseId}/dist/${VERSION}`);
const files = [
  { fileId: `${course.courseId}.${VERSION}.manifest`, path: 'manifest.json', text: manifestText },
  ...[...finished, placement].map((f) => ({
    fileId: f.index.fileId,
    path: `bundles/${f.bundle.lessonId}.json`,
    text: f.text,
  })),
];
const publish = {
  courseId: course.courseId,
  versionId: VERSION,
  signatureKeyId: keyId,
  manifestFileId: files[0].fileId,
  manifestSha256: sha256(manifestText),
  manifestHash,
  files: files.map((f) => ({
    fileId: f.fileId,
    path: f.path,
    sha256: sha256(f.text),
    bytes: Buffer.byteLength(f.text),
  })),
};
const publishText = `${JSON.stringify(publish, null, 2)}\n`;
const typeCounts = {};
for (const f of finished)
  for (const e of f.bundle.exercises) typeCounts[e.type] = (typeCounts[e.type] ?? 0) + 1;

if (process.argv.includes('--check')) {
  for (const file of files) {
    const current = fs.readFileSync(path.join(outDir, file.path), 'utf8');
    assert.equal(
      current,
      file.text,
      `${file.path} is stale; run node content/tools/build-content.mjs`,
    );
  }
  assert.equal(fs.readFileSync(path.join(outDir, 'publish.json'), 'utf8'), publishText);
} else {
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(path.join(outDir, 'bundles'), { recursive: true });
  for (const file of files) fs.writeFileSync(path.join(outDir, file.path), file.text);
  fs.writeFileSync(path.join(outDir, 'publish.json'), publishText);
}
console.log(
  JSON.stringify({
    status: 'PASS',
    mode: process.argv.includes('--check') ? 'check' : 'write',
    courseId: course.courseId,
    versionId: VERSION,
    signatureKeyId: keyId,
    sections: sections.length,
    units: manifestUnits.length,
    nodes: nodes.length,
    lessons: finished.length,
    placementExercises: placement.bundle.exercises.length,
    exercises: finished.reduce((n, f) => n + f.bundle.exercises.length, 0),
    exerciseTypes: typeCounts,
    assets: new Set(finished.flatMap((f) => f.bundle.assets.map((a) => a.fileId))).size,
    manifestSha256: publish.manifestSha256,
  }),
);
