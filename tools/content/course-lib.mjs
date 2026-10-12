// Shared helpers for the v2 course generator and lint (tools/content/*).
// Pure functions: parse the compact authored tables in content/vi_en/source/v2/units/*.mjs,
// expand accepted-answer variants (English contractions, Vietnamese pronoun register) and detect
// which course vocabulary a sentence uses. No I/O here.

/** Split on a separator, trim, drop empties. */
const splitTrim = (text, sep) =>
  text
    .split(sep)
    .map((x) => x.trim())
    .filter(Boolean);

/** Table lines: skip blanks and `//` comments. */
export function tableLines(text) {
  return text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('//'));
}

export const slug = (text) =>
  text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 20);

/**
 * Vocabulary line: `<level> <en>[, <enAlt>...] | <vi>[ / <viAlt>...] [| flags]`
 * flags (space separated): `img` (picturable → imageChoice), `forms=a,b` (extra inflections),
 * `id=x` (explicit id).
 */
export function parseVocab(unitId, text) {
  return tableLines(text).map((line) => {
    const m = /^([1-5])\s+(.+)$/.exec(line);
    if (!m) throw new Error(`${unitId}: bad vocab line "${line}"`);
    const [enPart, viPart, flagPart = ''] = splitTrim(m[2], '|');
    const [en, ...enAlts] = splitTrim(enPart, ',');
    const [vi, ...viAlts] = splitTrim(viPart, '/');
    const flags = flagPart.split(/\s+/).filter(Boolean);
    const flag = (name) => flags.find((f) => f === name || f.startsWith(`${name}=`));
    const forms = flag('forms') ? flag('forms').slice(6).split(',') : [];
    const id = flag('id') ? flag('id').slice(3) : slug(en);
    return {
      id,
      vocabularyId: `${unitId}.${id}`,
      unitId,
      level: Number(m[1]),
      en,
      enAlts,
      vi,
      viAlts,
      img: Boolean(flag('img')),
      forms,
    };
  });
}

/** Sentence line: `<en> [## <enAlt>...] = <vi> [## <viAlt>...]` */
export function parseSentences(unitId, text) {
  return tableLines(text).map((line, i) => {
    const [enSide, viSide] = line.split(' = ');
    if (!viSide) throw new Error(`${unitId}: sentence without " = ": "${line}"`);
    const [en, ...enAlts] = splitTrim(enSide, '##');
    const [vi, ...viAlts] = splitTrim(viSide, '##');
    return { key: `s${i + 1}`, unitId, en, enAlts, vi, viAlts };
  });
}

/** Dialogue line: `<line> => <reply> [## <replyAlt>...] = <vi of reply>` */
export function parseDialogues(unitId, text) {
  return tableLines(text).map((line, i) => {
    const [prompt, rest] = line.split(' => ');
    const [replySide, vi] = (rest ?? '').split(' = ');
    if (!replySide || !vi) throw new Error(`${unitId}: bad dialogue "${line}"`);
    const [reply, ...replyAlts] = splitTrim(replySide, '##');
    return { key: `d${i + 1}`, unitId, line: prompt.trim(), reply, replyAlts, vi: vi.trim() };
  });
}

/** Story question line: `<question> * <correct> | <wrong> | <wrong>` */
export function parseStoryQuestions(unitId, text) {
  return tableLines(text).map((line) => {
    const [q, answers] = line.split(' * ');
    if (!answers) throw new Error(`${unitId}: bad story question "${line}"`);
    const choices = splitTrim(answers, '|');
    return { q: q.trim(), correct: choices[0], choices };
  });
}

// ---------- English accepted-answer variants ----------
const CONTRACTIONS = [
  ['I am', "I'm"],
  ['you are', "you're"],
  ['we are', "we're"],
  ['they are', "they're"],
  ['he is', "he's"],
  ['she is', "she's"],
  ['it is', "it's"],
  ['that is', "that's"],
  ['there is', "there's"],
  ['what is', "what's"],
  ['where is', "where's"],
  ['who is', "who's"],
  ['how is', "how's"],
  ['is not', "isn't"],
  ['are not', "aren't"],
  ['was not', "wasn't"],
  ['were not', "weren't"],
  ['do not', "don't"],
  ['does not', "doesn't"],
  ['did not', "didn't"],
  ['cannot', "can't"],
  ['will not', "won't"],
  ['should not', "shouldn't"],
  ['I will', "I'll"],
  ['you will', "you'll"],
  ['we will', "we'll"],
  ['they will', "they'll"],
  ['he will', "he'll"],
  ['she will', "she'll"],
  ['it will', "it'll"],
  ['I would', "I'd"],
  ['let us', "let's"],
];
const PRONOUN_OBJECT = /^(it|he|she|they|you|we|I|me|him|her|them|us)$/i;

function matchCase(source, target) {
  return source[0] === source[0].toUpperCase() && source[0] !== source[0].toLowerCase()
    ? target[0].toUpperCase() + target.slice(1)
    : target;
}

/** One-step rewrites of `text` (contract or expand one occurrence pattern everywhere). */
function rewrites(text) {
  const out = [];
  for (const [full, short] of CONTRACTIONS) {
    const affirmativeBe = !/not$/.test(full) && full !== 'cannot' && full !== 'let us';
    // contract: full -> short (not at clause end for affirmative forms: "Yes, I am." stays)
    const fullRe = new RegExp(`\\b${full.replace(' ', '\\s+')}\\b(?=([\\s,.!?]*)(\\S*))`, 'gi');
    let changed = false;
    const contracted = text.replace(fullRe, (m, gap, next, offset, all) => {
      const rest = all.slice(offset + m.length);
      if (affirmativeBe) {
        if (/^\s*[.!?,]|^\s*$/.test(rest)) return m; // clause-final "I am." / "there is,"
        const nextWord = rest.trim().split(/[\s.,!?]+/)[0] ?? '';
        const tail = rest.trim().slice(nextWord.length).trim();
        if (/^(wh|how)/i.test(full) && PRONOUN_OBJECT.test(nextWord) && /^[.!?]?$/.test(tail))
          return m; // "Where is it?" -> not "Where's it?"
      }
      changed = true;
      return matchCase(m, short);
    });
    if (changed) out.push(contracted);
    // expand: short -> full
    const shortRe = new RegExp(`(^|[^A-Za-z])${short.replace("'", "['\u2019]")}(?![A-Za-z])`, 'gi');
    if (shortRe.test(text)) {
      out.push(text.replace(shortRe, (m, pre) => pre + matchCase(m.slice(pre.length), full)));
    }
  }
  return out;
}

export function normalizeLoose(text) {
  return text
    .normalize('NFC')
    .replace(/[\u2018\u2019\u02BC]/g, "'")
    .replace(/[\p{P}\p{S}]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

/** Authored English answer + authored alternatives + contraction/expansion closure (≤ max). */
export function englishVariants(primary, alts = [], max = 20) {
  const seen = new Map();
  const add = (t) => {
    const key = normalizeLoose(t);
    if (key && !seen.has(key) && seen.size < max) seen.set(key, t);
  };
  add(primary);
  alts.forEach(add);
  const queue = [...seen.values()];
  while (queue.length && seen.size < max) {
    const next = queue.shift();
    for (const variant of rewrites(next)) {
      const before = seen.size;
      add(variant);
      if (seen.size > before) queue.push(variant);
    }
  }
  return [...seen.values()];
}

/** Vietnamese: authored answer + alternatives, with the casual first person "mình" for "tôi". */
export function vietnameseVariants(primary, alts = [], max = 20) {
  const seen = new Map();
  const add = (t) => {
    const key = normalizeLoose(t);
    if (key && !seen.has(key) && seen.size < max) seen.set(key, t);
  };
  for (const t of [primary, ...alts]) {
    add(t);
  }
  for (const t of [primary, ...alts]) {
    if (/(^|[^\p{L}])[Tt]ôi(?![\p{L}])/u.test(t))
      add(
        t.replace(
          /(^|[^\p{L}])(T|t)ôi(?![\p{L}])/gu,
          (m, pre, c) => `${pre}${c === 'T' ? 'M' : 'm'}ình`,
        ),
      );
  }
  // The past marker "đã" is optional in Vietnamese ("Hôm qua tôi đã đi chợ" = "Hôm qua tôi đi chợ").
  for (const t of [...seen.values()]) {
    if (/(^|\s)đã\s/u.test(t))
      add(
        t
          .replace(/(^|\s)đã\s/gu, '$1')
          .replace(/^\p{Ll}/u, (c) => (/^Đã/.test(t) ? c.toUpperCase() : c)),
      );
  }
  return [...seen.values()];
}

// ---------- vocabulary detection ----------
function autoForms(word) {
  if (/\s/.test(word)) return [word];
  const w = word.toLowerCase();
  const forms = new Set([w, `${w}s`, `${w}es`, `${w}ed`, `${w}d`, `${w}ing`]);
  if (w.endsWith('e')) forms.add(`${w.slice(0, -1)}ing`);
  if (/[^aeiou]y$/.test(w)) {
    forms.add(`${w.slice(0, -1)}ies`);
    forms.add(`${w.slice(0, -1)}ied`);
  }
  return [...forms];
}

/** Build a matcher: sentence text -> list of vocabularyIds it contains (whole-word, case-insensitive). */
export function vocabMatcher(allVocab) {
  const entries = allVocab.map((v) => {
    // Inflections are generated for the headword only (an alternative like "hi" must not become "his").
    const all = [...new Set([...autoForms(v.en), ...v.enAlts, ...v.forms])].map((f) =>
      f.toLowerCase(),
    );
    const re = new RegExp(
      `(^|[^a-z'])(${all
        .sort((a, b) => b.length - a.length)
        .map((f) => f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+'))
        .join('|')})(?![a-z])`,
      'i',
    );
    return { v, re };
  });
  return (text) => entries.filter((e) => e.re.test(text.toLowerCase())).map((e) => e.v);
}

/** Tokens for word-bank / ordering (keeps apostrophes and hyphens, drops other punctuation). */
export function tokenize(sentence) {
  return sentence
    .replace(/[.,!?;:"“”()…]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}
