// `node tools/content/build-course.mjs [--check]` — generate the published Duolingo-style vi_en course
// (version v2) from the structured tables in content/vi_en/source/v2/ into the committed
// content/vi_en/dist/v2/ (manifest.json, bundles/*.json, publish.json, audio-catalog.json) and
// content/vi_en/source/v2/build-report.json (counts + manifestSha256). Canonical JSON + Ed25519
// signing + validateCourse (services/learning content tools). Deterministic: no clock, no randomness
// beyond sha256-seeded shuffles. --check rebuilds in memory and fails if the committed dist/v2 or the
// build report differ. Learning's local loader publishes every dist/ version (v2 is the only one).
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { course, sections, unitModules } from '../../content/vi_en/source/v2/course.mjs';
import { loadContentTools, root } from '../../content/tools/lib.mjs';
import {
  englishVariants,
  parseDialogues,
  parseSentences,
  parseStoryQuestions,
  parseVocab,
  tokenize,
  vietnameseVariants,
  vocabMatcher,
} from './course-lib.mjs';

export const VERSION = 'v2';
const GRADING_RULES_VERSION = 'g1';
const OUT_DIR = path.join(root, `content/${course.courseId}/dist/${VERSION}`);
const REPORT_PATH = path.join(
  root,
  `content/${course.courseId}/source/${VERSION}/build-report.json`,
);

// ---------- load + parse authored tables ----------
export function loadCourseData() {
  // COURSE_UNITS=n builds only the first n units (authoring aid; not used by gates).
  const limit = Number(process.env.COURSE_UNITS) || unitModules.length;
  const units = unitModules.slice(0, limit).map((m, index) => {
    const u = m.default;
    const unitId = `u${index + 1}`;
    const vocab = parseVocab(unitId, u.vocab);
    const sentences = parseSentences(unitId, u.sentences);
    const dialogues = parseDialogues(unitId, u.dialogues);
    const questions = parseStoryQuestions(unitId, u.story.questions);
    return {
      unitId,
      sectionId: sections.find((s) => s.units.includes(u.theme)).sectionId,
      theme: u.theme,
      title: u.title,
      cefr: u.cefr,
      levelTitles: u.levels,
      guide: u.guide.trim().replace(/\n\s*/g, '\n'),
      vocab,
      sentences,
      dialogues,
      story: {
        title: u.story.title,
        passage: u.story.passage.trim().replace(/\s+/g, ' '),
        questions,
      },
    };
  });
  const allVocab = units.flatMap((u) => u.vocab);
  const match = vocabMatcher(allVocab);
  const unitIndex = new Map(units.map((u, i) => [u.unitId, i]));
  // Sentence/dialogue level = latest (unit, level) of any vocabulary it uses.
  const rank = (v) => unitIndex.get(v.unitId) * 10 + v.level;
  for (const u of units) {
    for (const item of [...u.sentences, ...u.dialogues]) {
      const text = item.en ?? `${item.line} ${item.reply}`;
      item.vocab = match(text);
      const own = item.vocab.filter((v) => v.unitId === u.unitId);
      item.level = Math.max(1, ...own.map((v) => v.level));
      item.rank = Math.max(unitIndex.get(u.unitId) * 10 + 1, ...item.vocab.map(rank));
      item.homeRank = unitIndex.get(u.unitId) * 10 + item.level;
      item.audioKey = `a.${u.unitId}.${item.key}`;
    }
  }
  return { units, allVocab, match, unitIndex };
}

// ---------- deterministic helpers ----------
let tools;
const h = (text) => parseInt(tools.sha256(text).slice(0, 8), 16);
function shuffle(list, seed) {
  let x = h(seed) || 1;
  const next = () => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    return ((x >>> 0) % 1_000_000) / 1_000_000;
  };
  const out = [...list];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}
function uniqueBy(list, key) {
  const seen = new Set();
  return list.filter((x) => (seen.has(key(x)) ? false : (seen.add(key(x)), true)));
}
// Words that could be inserted into a correct answer without making it wrong: never distractors.
const OPTIONAL_WORDS = new Set(
  'please too very also really just yes no now today here there a an the some so well oh rất cũng nhé à ạ đã thì là một này'.split(
    ' ',
  ),
);
const TEXT_RULE = { caseSensitive: false, ignorePunctuation: true, ignoreDiacritics: false };
const KEY_RULE = { caseSensitive: false, ignorePunctuation: false, ignoreDiacritics: false };
const wc = (s) => tokenize(s).length;

function audioAssets(key, transcript, locale = 'en-US') {
  const n = wc(transcript);
  const make = (suffix, speed, perWord) => ({
    fileId: `${key}.${suffix}`,
    sha256: tools.sha256(`placeholder-audio:${key}.${suffix}:${transcript}`),
    mime: 'audio/aac',
    bytes: 4000 + n * 3000,
    durationMs: 600 + n * perWord,
    width: null,
    height: null,
    locale,
    voice: 'en-US-neutral-1',
    speed,
    provider: null,
    modelVersion: null,
    altText: transcript.slice(0, 256),
  });
  return [make('n', 1, 420), make('s', 0.75, 560)];
}
function imageAsset(v) {
  return {
    fileId: `i.${v.unitId}.${v.id}`,
    sha256: tools.sha256(`placeholder-image:${v.unitId}.${v.id}`),
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
    altText: `Hình minh họa: ${v.vi} (${v.en})`,
  };
}
const gloss = (vocab) =>
  vocab
    .slice(0, 4)
    .map((v) => `"${v.en}" = ${v.vi}`)
    .join('; ');
const vids = (vocab) => [...new Set(vocab.map((v) => v.vocabularyId))].slice(0, 20);
function alsoOk(list) {
  const extra = list.slice(1, 3);
  return extra.length ? ` Cũng đúng: ${extra.map((t) => `"${t}"`).join(', ')}.` : '';
}

/** True when an accepted alternative could be assembled from the primary answer's own tiles. */
export function orderAmbiguous(s, lang) {
  const bag = (t) => tokenize(t).map((w) => w.toLowerCase());
  const primary = bag(lang === 'vi' ? s.vi : s.en);
  const alts = (
    lang === 'vi' ? vietnameseVariants(s.vi, s.viAlts) : englishVariants(s.en, s.enAlts)
  ).slice(1);
  return alts.some((alt) => {
    const rest = [...primary];
    return bag(alt).every((w) => {
      const i = rest.indexOf(w);
      if (i < 0) return false;
      rest.splice(i, 1);
      return true;
    });
  });
}

// ---------- exercise factories (one per wire type / direction) ----------
function factories(ctx) {
  const { unit, assets, legendary } = ctx;
  const u = unit.unitId;
  const addAudio = (item, text) => {
    for (const a of audioAssets(item.audioKey, text)) assets.set(a.fileId, a);
    return `${item.audioKey}.n`;
  };
  const hintOf = (text) =>
    legendary ? 'Thử thách Huyền thoại: dùng gợi ý sẽ tính là có trợ giúp. ' + text : text;
  const grammar = `${u}.grammar`;
  const vocabSkill = `${u}.vocab`;

  const choiceVocab = (id, v, pool, enToVi, isNew) => {
    const distractors = shuffle(
      uniqueBy(pool, (x) => (enToVi ? x.vi : x.en).toLowerCase()).filter(
        (x) =>
          x.vocabularyId !== v.vocabularyId &&
          (enToVi ? x.vi !== v.vi : x.en.toLowerCase() !== v.en.toLowerCase()),
      ),
      `${id}:d`,
    ).slice(0, 3);
    const opts = shuffle([v, ...distractors], id);
    const choices = opts.map((o, k) => ({ id: `c${k + 1}`, text: enToVi ? o.vi : o.en }));
    return {
      id,
      type: 'choice',
      prompt: {
        text: enToVi
          ? `${isNew ? 'Từ mới! ' : ''}Chọn nghĩa đúng của "${v.en}"`
          : `${isNew ? 'Từ mới! ' : ''}"${v.vi}" trong tiếng Anh là gì?`,
        locale: 'vi-VN',
      },
      content: { choices },
      gradingRule: { ...KEY_RULE, correctChoiceId: choices[opts.indexOf(v)].id },
      hint: hintOf(`"${v.en}" nghĩa là "${v.vi}".`),
      explanation: `"${v.en}" = "${v.vi}".`,
      skillIds: [vocabSkill],
      vocabularyIds: [v.vocabularyId],
    };
  };

  return {
    newWord(id, v, known) {
      const imgPool = known.filter((x) => x.img && x.id !== v.id && x.en !== v.en);
      if (v.img && imgPool.length >= 3) return this.imageChoice(id, v, imgPool, true);
      return choiceVocab(id, v, known, true, true);
    },
    imageChoice(id, v, imgPool, isNew = false) {
      const distractors = shuffle(
        uniqueBy(imgPool, (x) => x.en.toLowerCase()).filter(
          (x) => x.vocabularyId !== v.vocabularyId && x.en !== v.en,
        ),
        `${id}:d`,
      ).slice(0, 3);
      const opts = shuffle([v, ...distractors], id);
      for (const o of opts) {
        const a = imageAsset(o);
        assets.set(a.fileId, a);
      }
      const choices = opts.map((o, k) => ({
        id: `c${k + 1}`,
        text: o.en,
        imageAssetId: `i.${o.unitId}.${o.id}`,
      }));
      return {
        id,
        type: 'imageChoice',
        prompt: { text: `${isNew ? 'Từ mới! ' : ''}Hình nào là "${v.vi}"?`, locale: 'vi-VN' },
        content: { choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: choices[opts.indexOf(v)].id },
        hint: hintOf(`"${v.vi}" là "${v.en}".`),
        explanation: `"${v.en}" = "${v.vi}".`,
        skillIds: [vocabSkill],
        vocabularyIds: [v.vocabularyId],
      };
    },
    choiceViEn(id, v, pool) {
      return choiceVocab(id, v, pool, false, false);
    },
    choiceEnVi(id, v, pool) {
      return choiceVocab(id, v, pool, true, false);
    },
    matchPairs(id, words) {
      const seenEn = new Set();
      const seenVi = new Set();
      const picked = [];
      for (const v of words) {
        if (seenEn.has(v.en.toLowerCase()) || seenVi.has(v.vi.toLowerCase())) continue;
        seenEn.add(v.en.toLowerCase());
        seenVi.add(v.vi.toLowerCase());
        picked.push(v);
        if (picked.length === 5) break;
      }
      // b-learning convention: vocabularyIds listed in pair order (word-list translations derive from it).
      const pairs = picked.map((v, k) => ({
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
        hint: hintOf(`Ví dụ: "${picked[0].en}" = "${picked[0].vi}".`),
        explanation: picked.map((v) => `${v.en} = ${v.vi}`).join('; '),
        skillIds: [vocabSkill],
        vocabularyIds: picked.map((v) => v.vocabularyId),
      };
    },
    translateViEn(id, s, skills = [grammar]) {
      const accepted = englishVariants(s.en, s.enAlts);
      return {
        id,
        type: 'textTranslation',
        prompt: { text: s.vi, locale: 'vi-VN' },
        content: { placeholder: 'Viết bằng tiếng Anh', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: accepted },
        hint: hintOf(
          s.vocab.length
            ? gloss(s.vocab)
            : `Bắt đầu bằng: "${tokenize(s.en).slice(0, 2).join(' ')} ..."`,
        ),
        explanation: `Đáp án: "${s.en}".${alsoOk(accepted)}`,
        skillIds: skills,
        vocabularyIds: vids(s.vocab),
      };
    },
    translateEnVi(id, s) {
      const accepted = vietnameseVariants(s.vi, s.viAlts);
      return {
        id,
        type: 'textTranslation',
        prompt: { text: s.en, locale: 'en-US' },
        content: { placeholder: 'Viết bằng tiếng Việt (có dấu)', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: accepted },
        hint: hintOf(s.vocab.length ? gloss(s.vocab) : 'Nhớ gõ đủ dấu tiếng Việt.'),
        explanation: `Đáp án: "${s.vi}".${alsoOk(accepted)}`,
        skillIds: [grammar],
        vocabularyIds: vids(s.vocab),
      };
    },
    wordBank(id, s, distractorSource, toVi = false) {
      const target = tokenize(toVi ? s.vi : s.en);
      const lower = new Set(
        [...target, ...(toVi ? s.viAlts : s.enAlts).flatMap((a) => tokenize(a))].map((t) =>
          t.toLowerCase(),
        ),
      );
      const pool = [
        ...new Set(
          distractorSource
            .filter((x) => x !== s)
            .flatMap((x) => tokenize(toVi ? x.vi : x.en))
            .filter((w) => !lower.has(w.toLowerCase()) && !OPTIONAL_WORDS.has(w.toLowerCase())),
        ),
      ];
      const distractors = shuffle(pool, `${id}:d`).slice(0, toVi ? 4 : 3);
      const all = shuffle(
        [
          ...target.map((text, k) => ({ key: `w${k}`, text })),
          ...distractors.map((text, k) => ({ key: `x${k}`, text })),
        ],
        id,
      );
      const tokens = all.map((t, k) => ({ id: `t${k + 1}`, text: t.text, key: t.key }));
      return {
        id,
        type: 'wordBank',
        prompt: toVi
          ? { text: `Dịch sang tiếng Việt: "${s.en}"`, locale: 'vi-VN' }
          : { text: `Dịch câu này: "${s.vi}"`, locale: 'vi-VN' },
        content: { tokens: tokens.map(({ id: tid, text }) => ({ id: tid, text })) },
        gradingRule: {
          ...KEY_RULE,
          correctTokenIds: target.map((_, k) => tokens.find((t) => t.key === `w${k}`).id),
        },
        hint: hintOf(s.vocab.length ? gloss(s.vocab) : `Từ đầu tiên là "${target[0]}".`),
        explanation: `Câu đúng: "${toVi ? s.vi : s.en}".`,
        skillIds: [grammar],
        vocabularyIds: vids(s.vocab),
      };
    },
    sentenceOrder(id, s, skills = [grammar], promptVi = null) {
      const target = tokenize(s.en);
      const order = shuffle(
        target.map((text, k) => ({ key: k, text })),
        id,
      );
      // Never present the tokens already in the answer order.
      if (order.every((t, k) => t.key === k) && order.length > 1) order.push(order.shift());
      const tokens = order.map((t, k) => ({ id: `t${k + 1}`, text: t.text, key: t.key }));
      return {
        id,
        type: 'sentenceOrder',
        prompt: { text: `Sắp xếp thành câu đúng: "${promptVi ?? s.vi}"`, locale: 'vi-VN' },
        content: { tokens: tokens.map(({ id: tid, text }) => ({ id: tid, text })) },
        gradingRule: {
          ...KEY_RULE,
          correctTokenIds: target.map((_, k) => tokens.find((t) => t.key === k).id),
        },
        hint: hintOf(`Câu bắt đầu bằng "${target[0]}".`),
        explanation: `Câu đúng: "${s.en}".`,
        skillIds: skills,
        vocabularyIds: vids(s.vocab),
      };
    },
    fillBlank(id, s, focusWords) {
      // Blank the first (preferably focus) vocabulary word that appears verbatim in the sentence.
      const words = tokenize(s.en);
      const candidates = [...focusWords, ...s.vocab].filter(
        (v) => s.vocab.includes(v) && !/\s/.test(v.en),
      );
      let blank = null;
      for (const v of candidates) {
        const idx = words.findIndex((w) => w.toLowerCase() === v.en.toLowerCase());
        if (idx >= 0) {
          blank = { v, word: words[idx] };
          break;
        }
      }
      if (!blank) {
        // Fall back to the longest word of the sentence.
        const word = [...words].sort((a, b) => b.length - a.length || (a < b ? -1 : 1))[0];
        blank = { v: null, word };
      }
      const re = new RegExp(
        `(^|[^A-Za-z'])${blank.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![A-Za-z'])`,
      );
      const text = s.en.replace(re, (m, pre) => `${pre}___`);
      return {
        id,
        type: 'fillBlank',
        prompt: { text: `${text} — "${s.vi}"`, locale: 'en-US' },
        content: { placeholder: 'Điền từ còn thiếu', maxChars: 40 },
        gradingRule: { ...TEXT_RULE, acceptedText: [blank.word] },
        hint: hintOf(
          blank.v
            ? `"${blank.v.vi}" trong tiếng Anh là "${blank.v.en[0]}..."`
            : `Từ bắt đầu bằng "${blank.word[0]}".`,
        ),
        explanation: `Từ đúng: "${blank.word}" → ${s.en}`,
        skillIds: [grammar],
        vocabularyIds: vids(blank.v ? [blank.v, ...s.vocab] : s.vocab),
      };
    },
    listenChoice(id, s, pool) {
      const others = shuffle(
        uniqueBy(pool, (x) => x.en.toLowerCase()).filter(
          (x) => x.en.toLowerCase() !== s.en.toLowerCase(),
        ),
        `${id}:d`,
      ).slice(0, 2);
      const opts = shuffle([s, ...others], id);
      const choices = opts.map((o, k) => ({ id: `c${k + 1}`, text: o.en }));
      const base = {
        content: { choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: choices[opts.indexOf(s)].id },
        hint: hintOf(`Câu có nghĩa: "${s.vi}"`),
        explanation: `Bạn nghe: "${s.en}" (${s.vi}).`,
        skillIds: ['listening', grammar],
        vocabularyIds: vids(s.vocab),
      };
      return {
        id,
        type: 'listenChoice',
        prompt: {
          text: 'Nghe và chọn câu bạn nghe được',
          locale: 'vi-VN',
          audioAssetId: addAudio(s, s.en),
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
    dictation(id, s) {
      const accepted = englishVariants(
        s.en,
        s.enAlts.filter((a) => wc(a) === wc(s.en)),
      );
      const alt = this.translateViEn(`${id}a`, s, ['listening', grammar]);
      return {
        id,
        type: 'dictation',
        prompt: {
          text: 'Nghe và viết lại bằng tiếng Anh',
          locale: 'vi-VN',
          audioAssetId: addAudio(s, s.en),
        },
        content: { placeholder: 'Viết những gì bạn nghe', maxChars: 200 },
        gradingRule: { ...TEXT_RULE, acceptedText: accepted },
        hint: hintOf(`Câu có ${wc(s.en)} từ. Nghĩa: "${s.vi}"`),
        explanation: `Bạn nghe: "${s.en}".`,
        skillIds: ['listening', grammar],
        vocabularyIds: vids(s.vocab),
        nonAudioAlternative: alt,
      };
    },
    speakRepeat(id, s) {
      const skills = ['speaking', grammar];
      return {
        id,
        type: 'speakRepeat',
        prompt: {
          text: `Nói câu sau: "${s.en}"`,
          locale: 'en-US',
          audioAssetId: addAudio(s, s.en),
        },
        content: {
          referenceText: s.en,
          locale: 'en-US',
          maxSeconds: Math.min(15, 4 + Math.ceil(wc(s.en) / 2)),
        },
        gradingRule: { ...TEXT_RULE, acceptedText: englishVariants(s.en, s.enAlts) },
        hint: hintOf(`Nghĩa: "${s.vi}"`),
        explanation: `Câu mẫu: "${s.en}".`,
        skillIds: skills,
        vocabularyIds: vids(s.vocab),
        nonSpeechAlternative: this.sentenceOrder(`${id}a`, s, skills),
      };
    },
    dialogueTurn(id, d, pool) {
      const skills = ['speaking', `${u}.dialogue`];
      const accepted = englishVariants(d.reply, d.replyAlts);
      const others = shuffle(
        uniqueBy(pool, (x) => x.reply.toLowerCase()).filter(
          (x) => x.reply.toLowerCase() !== d.reply.toLowerCase(),
        ),
        `${id}:d`,
      ).slice(0, 2);
      const opts = shuffle([d, ...others], id);
      const choices = opts.map((o, k) => ({ id: `c${k + 1}`, text: o.reply }));
      return {
        id,
        type: 'dialogueTurn',
        prompt: { text: d.line, locale: 'en-US', audioAssetId: addAudio(d, d.line) },
        content: { referenceText: d.reply, locale: 'en-US', maxSeconds: 12 },
        gradingRule: { ...TEXT_RULE, acceptedText: accepted },
        hint: hintOf(`Gợi ý trả lời: "${d.vi}"`),
        explanation: `Câu trả lời mẫu: "${d.reply}".${alsoOk(accepted)}`,
        skillIds: skills,
        vocabularyIds: vids(d.vocab),
        nonSpeechAlternative: {
          id: `${id}a`,
          type: 'choice',
          prompt: { text: `"${d.line}" — chọn câu trả lời phù hợp`, locale: 'vi-VN' },
          content: { choices },
          gradingRule: { ...KEY_RULE, correctChoiceId: choices[opts.indexOf(d)].id },
          hint: hintOf(`Gợi ý trả lời: "${d.vi}"`),
          explanation: `Câu trả lời mẫu: "${d.reply}".`,
          skillIds: skills,
          vocabularyIds: vids(d.vocab),
        },
      };
    },
    storyQuestion(id, q) {
      const opts = shuffle(q.choices, id);
      const choices = opts.map((text, k) => ({ id: `c${k + 1}`, text }));
      return {
        id,
        type: 'storyQuestion',
        prompt: { text: q.q, locale: 'en-US' },
        content: { passage: unit.story.passage, question: q.q, choices },
        gradingRule: { ...KEY_RULE, correctChoiceId: choices[opts.indexOf(q.correct)].id },
        hint: hintOf(`Đọc lại câu chuyện "${unit.story.title}".`),
        explanation: `Đáp án: "${q.correct}".`,
        skillIds: ['reading', `${u}.story`],
        vocabularyIds: [],
      };
    },
  };
}

// ---------- lesson recipes (Duolingo progression) ----------
// slot: [type, source]; source focus = this level's material, review = spaced repetition of older
// material, unit = anything introduced in this unit so far.
const RECIPES = {
  intro: [
    ['matchPairs', 'focus'],
    ['wordBank', 'focus'],
    ['listenChoice', 'focus'],
    ['choiceViEn', 'focus'],
    ['wordBankVi', 'focus'],
    ['sentenceOrder', 'focus'],
    ['fillBlank', 'focus'],
    ['translateViEn', 'focus'],
    ['wordBank', 'review'],
  ],
  practice: [
    ['choiceEnVi', 'focus'],
    ['wordBank', 'focus'],
    ['translateViEn', 'focus'],
    ['fillBlank', 'focus'],
    ['listenChoice', 'focus'],
    ['wordBankVi', 'focus'],
    ['translateEnVi', 'focus'],
    ['matchPairs', 'focus'],
    ['sentenceOrder', 'focus'],
    ['dictation', 'focus'],
    ['wordBank', 'review'],
    ['translateViEn', 'review'],
  ],
  listening: [
    ['listenChoice', 'focus'],
    ['dictation', 'focus'],
    ['listenChoice', 'focus'],
    ['wordBank', 'focus'],
    ['dictation', 'focus'],
    ['matchPairs', 'focus'],
    ['fillBlank', 'focus'],
    ['listenChoice', 'unit'],
    ['dictation', 'unit'],
    ['translateViEn', 'focus'],
    ['listenChoice', 'review'],
    ['dictation', 'review'],
  ],
  speaking: [
    ['speakRepeat', 'focus'],
    ['dialogueTurn', 'focus'],
    ['wordBank', 'focus'],
    ['speakRepeat', 'focus'],
    ['choiceViEn', 'focus'],
    ['dialogueTurn', 'unit'],
    ['fillBlank', 'focus'],
    ['speakRepeat', 'unit'],
    ['translateViEn', 'focus'],
    ['sentenceOrder', 'focus'],
    ['speakRepeat', 'review'],
    ['translateEnVi', 'review'],
  ],
  story1: [
    ['storyQuestion', 0],
    ['storyQuestion', 1],
    ['choiceViEn', 'unit'],
    ['sentenceOrder', 'unit'],
    ['storyQuestion', 2],
    ['wordBank', 'unit'],
    ['fillBlank', 'unit'],
    ['translateViEn', 'unit'],
    ['matchPairs', 'unit'],
    ['listenChoice', 'review'],
    ['speakRepeat', 'unit'],
  ],
  story2: [
    ['storyQuestion', 3],
    ['storyQuestion', 4],
    ['wordBankVi', 'unit'],
    ['dialogueTurn', 'unit'],
    ['storyQuestion', 5],
    ['dictation', 'unit'],
    ['translateEnVi', 'unit'],
    ['sentenceOrder', 'unit'],
    ['matchPairs', 'unit'],
    ['translateViEn', 'review'],
    ['imageChoice', 'unit'],
  ],
  review: [
    ['translateViEn', 'unit'],
    ['wordBank', 'unit'],
    ['fillBlank', 'unit'],
    ['dictation', 'unit'],
    ['sentenceOrder', 'unit'],
    ['translateEnVi', 'unit'],
    ['listenChoice', 'unit'],
    ['dialogueTurn', 'unit'],
    ['storyQuestion', -1],
    ['imageChoice', 'unit'],
    ['matchPairs', 'unit'],
    ['choiceViEn', 'unit'],
    ['speakRepeat', 'unit'],
    ['wordBankVi', 'unit'],
    ['translateViEn', 'review'],
  ],
  legendary: [
    ['translateViEn', 'unit'],
    ['dictation', 'unit'],
    ['translateViEn', 'unit'],
    ['translateEnVi', 'unit'],
    ['fillBlank', 'unit'],
    ['dictation', 'unit'],
    ['sentenceOrder', 'unit'],
    ['translateViEn', 'unit'],
    ['speakRepeat', 'unit'],
    ['dialogueTurn', 'unit'],
    ['translateEnVi', 'unit'],
    ['dictation', 'unit'],
    ['listenChoice', 'unit'],
    ['fillBlank', 'unit'],
    ['translateViEn', 'review'],
  ],
};

// Unit path (Duolingo-style): 5 level nodes with 4-6 lessons each (the level's new words are taught in
// its first lesson; later lessons practise, listen and speak), a story after level 3, the unit review
// and the Legendary challenge. 8 nodes and 32 lessons per unit.
export const LEVEL_LESSONS = [
  ['intro', 'practice', 'listening', 'speaking'],
  ['intro', 'practice', 'listening', 'speaking', 'practice'],
  ['intro', 'practice', 'listening', 'speaking', 'practice'],
  ['intro', 'practice', 'listening', 'speaking', 'practice', 'listening'],
  ['intro', 'practice', 'listening', 'speaking', 'practice', 'speaking'],
];
export function unitPlan(unit) {
  const nodes = [];
  for (let L = 1; L <= 5; L++) {
    nodes.push({
      kind: 'lesson',
      level: L,
      title: unit.levelTitles[L - 1],
      lessons: LEVEL_LESSONS[L - 1],
    });
    if (L === 3)
      nodes.push({
        kind: 'story',
        level: 3,
        title: `Truyện: ${unit.story.title}`,
        lessons: ['story1', 'story2'],
      });
  }
  nodes.push({ kind: 'mastery', level: 5, title: 'Ôn tập cửa ải', lessons: ['review', 'review'] });
  nodes.push({
    kind: 'mastery',
    level: 5,
    title: 'Huyền thoại',
    lessons: ['legendary', 'legendary'],
    legendary: true,
  });
  return nodes;
}

// ---------- build ----------
export async function buildCourse() {
  tools = await loadContentTools();
  const data = loadCourseData();
  const { units } = data;
  const useCount = new Map();
  const bump = (item) => useCount.set(item, (useCount.get(item) ?? 0) + 1);
  const pick = (pool, seed, avoid, ok = () => true) => {
    const fitting = pool.filter(ok);
    const fresh = fitting.filter((x) => !avoid.has(x));
    const list = fresh.length ? fresh : fitting;
    if (!list.length) return null;
    const best = [...list].sort(
      (a, b) =>
        (useCount.get(a) ?? 0) - (useCount.get(b) ?? 0) ||
        h(`${seed}:${a.unitId}.${a.key ?? a.id}`) - h(`${seed}:${b.unitId}.${b.key ?? b.id}`),
    )[0];
    bump(best);
    avoid.add(best);
    return best;
  };

  const ambiguousTiles = []; // token exercises whose sentence has a same-tiles alternative (lint: must be empty)
  const introduced = []; // vocab, in introduction order
  const seenSentences = [];
  const seenDialogues = [];
  const nodes = [];
  const drafts = [];
  const manifestUnits = [];
  let order = 0;

  for (const unit of units) {
    const nodeIds = [];
    unitPlan(unit).forEach((plan, n) => {
      const nodeId = `${unit.unitId}n${n + 1}`;
      nodeIds.push(nodeId);
      const lessonIds = plan.lessons.map((_, l) => `${nodeId}l${l + 1}`);
      nodes.push({
        nodeId,
        unitId: unit.unitId,
        sectionId: unit.sectionId,
        order,
        title: plan.title,
        kind: plan.kind,
        lessonIds,
      });
      plan.lessons.forEach((recipeName, l) => {
        const lessonId = lessonIds[l];
        const assets = new Map();
        const L = plan.level;
        const newWords = recipeName === 'intro' ? unit.vocab.filter((v) => v.level === L) : [];
        for (const v of newWords) introduced.push(v);
        const knownIds = new Set(introduced.map((v) => v.vocabularyId));
        const knows = (item) => item.vocab.every((v) => knownIds.has(v.vocabularyId));
        const unitRankMax = data.unitIndex.get(unit.unitId) * 10 + L;
        const ownSentences = unit.sentences.filter((s) => s.homeRank <= unitRankMax && knows(s));
        for (const s of ownSentences) if (!seenSentences.includes(s)) seenSentences.push(s);
        const ownDialogues = unit.dialogues.filter((d) => d.homeRank <= unitRankMax && knows(d));
        for (const d of ownDialogues) if (!seenDialogues.includes(d)) seenDialogues.push(d);
        const focusS = ownSentences.filter((s) => s.level === L);
        const unitS = ownSentences;
        const reviewS = seenSentences.filter((s) => s.unitId !== unit.unitId || s.level < L);
        const focusW = unit.vocab.filter((v) => v.level === L && knownIds.has(v.vocabularyId));
        const unitW = unit.vocab.filter((v) => knownIds.has(v.vocabularyId));
        const reviewW = introduced.filter((v) => v.unitId !== unit.unitId || v.level < L);
        const focusD = ownDialogues.filter((d) => d.level === L);
        const ctx = { unit, assets, legendary: Boolean(plan.legendary) };
        const f = factories(ctx);
        const exercises = [];
        const avoid = new Set();
        const nextId = () => `${lessonId}-e${String(exercises.length + 1).padStart(2, '0')}`;
        for (const v of newWords) exercises.push(f.newWord(nextId(), v, [...introduced]));
        const pools = {
          sentences: {
            focus: focusS.length ? focusS : unitS,
            unit: unitS,
            review: reviewS.length ? reviewS : unitS,
          },
          words: {
            focus: focusW.length >= 2 ? focusW : unitW,
            unit: unitW,
            review: reviewW.length >= 4 ? reviewW : introduced,
          },
          dialogues: {
            focus: focusD.length ? focusD : ownDialogues,
            unit: ownDialogues,
            review: seenDialogues,
          },
        };
        for (const [type, source] of RECIPES[recipeName]) {
          const id = nextId();
          const seed = `${lessonId}:${exercises.length}`;
          const sPool = pools.sentences[source] ?? unitS;
          const wPool = pools.words[source] ?? unitW;
          let ex = null;
          switch (type) {
            case 'storyQuestion': {
              const qs = unit.story.questions;
              const q = source === -1 ? qs[h(lessonId) % qs.length] : qs[source % qs.length];
              ex = f.storyQuestion(id, q);
              break;
            }
            case 'matchPairs': {
              const words = [
                ...shuffle(wPool, seed),
                ...shuffle(unitW, `${seed}u`),
                ...shuffle(introduced, `${seed}i`),
              ];
              ex = f.matchPairs(id, words);
              break;
            }
            case 'choiceViEn':
            case 'choiceEnVi': {
              const v = pick(wPool, seed, avoid);
              ex = f[type](id, v, [...unitW, ...introduced]);
              break;
            }
            case 'imageChoice': {
              const imgs = introduced.filter((v) => v.img);
              const own = unitW.filter((v) => v.img);
              const v = pick(own.length ? own : imgs, seed, avoid);
              ex =
                v && imgs.length >= 4
                  ? f.imageChoice(id, v, imgs)
                  : f.choiceViEn(id, pick(unitW, seed, avoid), introduced);
              break;
            }
            case 'dialogueTurn': {
              const dPool = pools.dialogues[source]?.length
                ? pools.dialogues[source]
                : seenDialogues;
              // A dialogue turn needs 3 distinct replies to choose from (its non-speech form); early
              // in the course fall back to repeating one of this level's sentences.
              const replies = new Set(seenDialogues.map((x) => x.reply.toLowerCase()));
              if (replies.size >= 3) {
                const d = pick(dPool, seed, avoid);
                ex = f.dialogueTurn(id, d, seenDialogues);
              } else {
                const ok = (x) => !orderAmbiguous(x, 'en');
                const s = pick(sPool, seed, avoid, ok) ?? pick(unitS, seed, avoid, ok);
                ex = f.speakRepeat(id, s);
              }
              break;
            }
            default: {
              const tiles = {
                wordBank: 'en',
                sentenceOrder: 'en',
                speakRepeat: 'en',
                wordBankVi: 'vi',
              }[type];
              const ok = tiles ? (x) => !orderAmbiguous(x, tiles) : undefined;
              const s =
                pick(sPool, seed, avoid, ok) ??
                pick(unitS, seed, avoid, ok) ??
                pick(seenSentences, seed, avoid, ok) ??
                pick(sPool, seed, avoid);
              if (tiles && orderAmbiguous(s, tiles)) ambiguousTiles.push(id);
              const distractors = seenSentences;
              if (type === 'wordBank') ex = f.wordBank(id, s, distractors);
              else if (type === 'wordBankVi') ex = f.wordBank(id, s, distractors, true);
              else if (type === 'translateViEn') ex = f.translateViEn(id, s);
              else if (type === 'translateEnVi') ex = f.translateEnVi(id, s);
              else if (type === 'sentenceOrder') ex = f.sentenceOrder(id, s);
              else if (type === 'fillBlank') ex = f.fillBlank(id, s, focusW);
              else if (type === 'listenChoice')
                ex = f.listenChoice(id, s, [...unitS, ...seenSentences]);
              else if (type === 'dictation') ex = f.dictation(id, s);
              else if (type === 'speakRepeat') ex = f.speakRepeat(id, s);
              else throw new Error(`unknown slot ${type}`);
            }
          }
          exercises.push(ex);
        }
        const lessonNo = l + 1;
        drafts.push({
          schemaVersion: 1,
          courseId: course.courseId,
          courseVersion: VERSION,
          sectionId: unit.sectionId,
          unitId: unit.unitId,
          nodeId,
          order,
          lessonId,
          lessonVersion: `${VERSION}.${lessonId}`,
          rewardIdentity: `${VERSION}.${lessonId}`,
          title: `${plan.title} · Bài ${lessonNo}`.slice(0, 120),
          skillIds: [...new Set(exercises.flatMap((e) => e.skillIds))].slice(0, 20),
          guideText: unit.guide,
          exercises,
          assets: [...assets.values()].sort((a, b) => (a.fileId < b.fileId ? -1 : 1)),
          gradingRulesVersion: GRADING_RULES_VERSION,
        });
      });
      order++;
    });
    manifestUnits.push({
      unitId: unit.unitId,
      sectionId: unit.sectionId,
      title: unit.title,
      guideText: unit.guide,
      nodeIds,
    });
  }

  // Placement: 10 items from unit 1 (pass >= 8 -> start at unit 2, Learning's rule).
  const u1 = units[0];
  const pAssets = new Map();
  const pf = factories({ unit: u1, assets: pAssets, legendary: false });
  const u1Words = u1.vocab;
  const u1S = u1.sentences;
  const pex = [];
  const pid = () => `placement-e${String(pex.length + 1).padStart(2, '0')}`;
  pex.push(pf.choiceEnVi(pid(), u1Words[3], u1Words));
  pex.push(pf.translateViEn(pid(), u1S[4]));
  pex.push(pf.wordBank(pid(), u1S[9], u1S));
  pex.push(pf.fillBlank(pid(), u1S[13], u1Words));
  pex.push(pf.matchPairs(pid(), u1Words.slice(8)));
  pex.push(pf.sentenceOrder(pid(), u1S[17]));
  pex.push(pf.choiceViEn(pid(), u1Words[14], u1Words));
  pex.push(pf.translateViEn(pid(), u1S[21]));
  pex.push(pf.storyQuestion(pid(), u1.story.questions[2]));
  const imgs = u1Words.filter((v) => v.img);
  pex.push(
    imgs.length >= 4
      ? pf.imageChoice(pid(), imgs[1], imgs)
      : pf.choiceViEn(pid(), u1Words[6], u1Words),
  );
  const placementDraft = {
    schemaVersion: 1,
    courseId: course.courseId,
    courseVersion: VERSION,
    sectionId: units[0].sectionId,
    unitId: 'u1',
    nodeId: 'placement',
    order: 0,
    lessonId: 'placement',
    lessonVersion: `${VERSION}.placement`,
    rewardIdentity: `${VERSION}.placement`,
    title: 'Kiểm tra trình độ',
    skillIds: [...new Set(pex.flatMap((e) => e.skillIds))],
    guideText: 'Trả lời đúng ít nhất 8/10 câu để bắt đầu từ Unit 2.',
    exercises: pex,
    assets: [...pAssets.values()].sort((a, b) => (a.fileId < b.fileId ? -1 : 1)),
    gradingRulesVersion: GRADING_RULES_VERSION,
  };

  const manifestSections = sections.map((s) => ({
    sectionId: s.sectionId,
    title: s.title,
    unitIds: units.filter((u) => u.sectionId === s.sectionId).map((u) => u.unitId),
  }));
  const structure = {
    schemaVersion: 1,
    courseId: course.courseId,
    courseVersion: VERSION,
    sourceLocale: course.sourceLocale,
    targetLocale: course.targetLocale,
    title: course.title,
    sections: manifestSections,
    units: manifestUnits,
    nodes,
  };
  const seedHex = process.env.COC_CONTENT_SIGNING_SEED_HEX;
  const privateKey = seedHex
    ? tools.ed25519FromSeed(Buffer.from(seedHex, 'hex'))
    : tools.devContentPrivateKey();
  const keyId = seedHex ? process.env.COC_CONTENT_SIGNING_KEY_ID : tools.DEV_CONTENT_KEY_ID;
  assert.ok(keyId, 'COC_CONTENT_SIGNING_KEY_ID is required with a custom seed');
  const manifestHash = tools.manifestStructureHash(structure);
  const fileIdOf = (lessonId) => `${course.courseId}.${VERSION}.${lessonId}`;
  const finish = (draft) => {
    const unsigned = { ...draft, manifestHash };
    const signed = {
      ...unsigned,
      signatureKeyId: keyId,
      signature: tools.signText(privateKey, tools.bundleSigningInput(unsigned)),
    };
    const text = tools.canonicalJson(signed);
    return {
      bundle: signed,
      text,
      index: {
        lessonId: draft.lessonId,
        lessonVersion: draft.lessonVersion,
        rewardIdentity: draft.rewardIdentity,
        fileId: fileIdOf(draft.lessonId),
        sha256: tools.sha256(text),
      },
    };
  };
  const finished = drafts.map(finish);
  const placement = finish(placementDraft);
  const unsignedManifest = {
    ...structure,
    bundles: finished.map((f) => f.index),
    placementBundle: placement.index,
    manifestHash,
  };
  const manifest = {
    ...unsignedManifest,
    signatureKeyId: keyId,
    signature: tools.signText(privateKey, tools.manifestSigningInput(unsignedManifest)),
  };
  const manifestText = tools.canonicalJson(manifest);
  const problems = tools.validateCourse(
    manifest,
    finished.map((f) => f.bundle),
  );
  problems.push(...tools.validateBundle(placement.bundle, 'placement'));

  // Audio catalog: one key per sentence and dialogue line (TTS production list, P7-AUDIO-001).
  const audioCatalog = {
    courseId: course.courseId,
    versionId: VERSION,
    locale: 'en-US',
    speeds: { n: 1, s: 0.75 },
    items: units.flatMap((u) => [
      ...u.sentences.map((s) => ({ key: s.audioKey, kind: 'sentence', text: s.en })),
      ...u.dialogues.map((d) => ({ key: d.audioKey, kind: 'dialogueLine', text: d.line })),
    ]),
  };
  const typeCounts = {};
  for (const f of finished)
    for (const e of f.bundle.exercises) typeCounts[e.type] = (typeCounts[e.type] ?? 0) + 1;
  const report = {
    courseId: course.courseId,
    versionId: VERSION,
    signatureKeyId: keyId,
    sections: manifestSections.length,
    units: manifestUnits.length,
    nodes: nodes.length,
    lessons: finished.length,
    exercises: finished.reduce((n, f) => n + f.bundle.exercises.length, 0),
    exerciseTypes: Object.fromEntries(Object.entries(typeCounts).sort()),
    nodeKinds: nodes.reduce((acc, n) => ({ ...acc, [n.kind]: (acc[n.kind] ?? 0) + 1 }), {}),
    vocabulary: data.allVocab.length,
    sentences: units.reduce((n, u) => n + u.sentences.length, 0),
    dialogues: units.reduce((n, u) => n + u.dialogues.length, 0),
    storyQuestions: units.reduce((n, u) => n + u.story.questions.length, 0),
    audioKeys: audioCatalog.items.length,
    assets: new Set(finished.flatMap((f) => f.bundle.assets.map((a) => a.fileId))).size,
    ambiguousTiles,
    maxBundleBytes: Math.max(...finished.map((f) => Buffer.byteLength(f.text))),
    unitsDetail: units.map((u) => ({
      unitId: u.unitId,
      sectionId: u.sectionId,
      cefr: u.cefr,
      title: u.title,
      vocab: u.vocab.length,
      sentences: u.sentences.length,
    })),
    manifestSha256: tools.sha256(manifestText),
  };
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
    manifestSha256: tools.sha256(manifestText),
    manifestHash,
    files: files.map((f) => ({
      fileId: f.fileId,
      path: f.path,
      sha256: tools.sha256(f.text),
      bytes: Buffer.byteLength(f.text),
    })),
  };
  return {
    data,
    manifest,
    finished,
    placement,
    files,
    publish,
    audioCatalog,
    report,
    problems,
    tools,
  };
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname);
if (isMain) {
  const built = await buildCourse();
  if (built.problems.length) {
    console.error(JSON.stringify(built.problems.slice(0, 40), null, 2));
    throw new Error(`${built.problems.length} content problems`);
  }
  const reportText = `${JSON.stringify(built.report, null, 2)}\n`;
  const all = [
    ...built.files,
    { path: 'publish.json', text: `${JSON.stringify(built.publish, null, 2)}\n` },
    { path: 'audio-catalog.json', text: `${JSON.stringify(built.audioCatalog, null, 1)}\n` },
  ];
  if (process.argv.includes('--check')) {
    // The committed build report and dist/v2 must match a fresh in-memory build byte for byte.
    assert.equal(
      fs.existsSync(REPORT_PATH) ? fs.readFileSync(REPORT_PATH, 'utf8') : null,
      reportText,
      'v2 build-report.json is stale; run node tools/content/build-course.mjs',
    );
    for (const file of all) {
      const p = path.join(OUT_DIR, file.path);
      assert.ok(
        fs.existsSync(p) && fs.readFileSync(p, 'utf8') === file.text,
        `dist/${VERSION}/${file.path} is stale; run node tools/content/build-course.mjs`,
      );
    }
    const expected = new Set(all.map((f) => f.path));
    const extra = fs
      .readdirSync(path.join(OUT_DIR, 'bundles'))
      .map((f) => `bundles/${f}`)
      .filter((f) => !expected.has(f));
    assert.deepEqual(extra, [], `dist/${VERSION} has stale files`);
  } else {
    fs.rmSync(OUT_DIR, { recursive: true, force: true });
    fs.mkdirSync(path.join(OUT_DIR, 'bundles'), { recursive: true });
    for (const file of all) fs.writeFileSync(path.join(OUT_DIR, file.path), file.text);
    if (!process.env.COURSE_UNITS) fs.writeFileSync(REPORT_PATH, reportText);
  }
  const { unitsDetail, ...summary } = built.report;
  console.log(
    JSON.stringify({
      status: 'PASS',
      mode: process.argv.includes('--check') ? 'check' : 'write',
      ...summary,
    }),
  );
}
