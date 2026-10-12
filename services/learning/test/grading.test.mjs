// P5-LESSON-001: deterministic grading — NFC, diacritics, curated alternatives, token IDs, pairs.
import test from 'node:test';
import assert from 'node:assert/strict';
import { loadKit } from './helpers/kit.mjs';

const kit = await loadKit('grading');
const { gradeAnswer, gradedExercise, normalizeText } = kit;
const base = {
  prompt: { text: 'p', locale: 'vi-VN' },
  hint: '',
  explanation: 'e',
  skillIds: ['s'],
  vocabularyIds: [],
};
const rule = (extra = {}) => ({
  caseSensitive: false,
  ignorePunctuation: true,
  ignoreDiacritics: false,
  ...extra,
});
const text = (acceptedText, extra = {}) => ({
  ...base,
  id: 'x1',
  type: 'textTranslation',
  content: { placeholder: '', maxChars: 200 },
  gradingRule: rule({ acceptedText, ...extra }),
});
const say = (t) => ({ kind: 'text', text: t });

test('text: NFC-equivalent input matches (decomposed Vietnamese == precomposed)', () => {
  const ex = text(['Tôi là sinh viên.']);
  const decomposed = 'To\u0302i la\u0300 sinh vie\u0302n'; // combining marks, no final period
  assert.notEqual(decomposed, 'Tôi là sinh viên');
  assert.equal(gradeAnswer(ex, say(decomposed)).correct, true);
});

test('text: Vietnamese diacritics stay significant unless the rule says ignoreDiacritics', () => {
  const strict = text(['Tôi là sinh viên.']);
  assert.equal(gradeAnswer(strict, say('Toi la sinh vien')).correct, false);
  assert.equal(
    gradeAnswer(strict, say('Tôi là sinh vien')).correct,
    false,
    'one missing mark is wrong',
  );
  const lenient = text(['Tôi là sinh viên.'], { ignoreDiacritics: true });
  assert.equal(gradeAnswer(lenient, say('toi la sinh vien')).correct, true);
  assert.equal(
    gradeAnswer(text(['đi học'], { ignoreDiacritics: true }), say('di hoc')).correct,
    true,
    'đ folds to d',
  );
});

test('text: curated alternatives, case, whitespace, punctuation and typographic apostrophes', () => {
  const ex = text(["I'm a student.", 'I am a student.']);
  assert.equal(gradeAnswer(ex, say('  i   AM a student ')).correct, true);
  assert.equal(
    gradeAnswer(ex, say('I\u2019m a student!')).correct,
    true,
    'curly apostrophe == straight',
  );
  assert.equal(gradeAnswer(ex, say('I is a student')).correct, false, 'no fuzzy/semantic match');
  assert.equal(gradeAnswer(ex, say('I am a student')).acceptedAnswer, "I'm a student.");
  const punctuationMatters = text(['Hello.'], { ignorePunctuation: false });
  assert.equal(gradeAnswer(punctuationMatters, say('Hello')).correct, false);
  const caseMatters = text(['Hanoi'], { caseSensitive: true });
  assert.equal(gradeAnswer(caseMatters, say('hanoi')).correct, false);
  assert.equal(normalizeText('Ａ', rule()), 'ａ', 'no compatibility (NFKC) folding beyond NFC');
});

test('text: empty or over-long answers are invalid input, not wrong answers', () => {
  const ex = text(['hello']);
  assert.throws(() => gradeAnswer(ex, say('   ')), { code: 'VALIDATION_ERROR' });
  assert.throws(() => gradeAnswer(ex, say('a'.repeat(513))), { code: 'VALIDATION_ERROR' });
});

test('choice: exact authored ID; unknown choice and wrong answer kind rejected', () => {
  const ex = {
    ...base,
    id: 'c',
    type: 'choice',
    content: {
      choices: [
        { id: 'c1', text: 'mẹ' },
        { id: 'c2', text: 'bố' },
      ],
    },
    gradingRule: rule({ correctChoiceId: 'c2' }),
  };
  assert.deepEqual(gradeAnswer(ex, { kind: 'choice', choiceId: 'c2' }), {
    correct: true,
    acceptedAnswer: 'bố',
  });
  assert.equal(gradeAnswer(ex, { kind: 'choice', choiceId: 'c1' }).correct, false);
  assert.throws(() => gradeAnswer(ex, { kind: 'choice', choiceId: 'c9' }), {
    code: 'VALIDATION_ERROR',
  });
  assert.throws(() => gradeAnswer(ex, say('bố')), { code: 'VALIDATION_ERROR' });
});

test('tokens: stable IDs incl. repeated words; duplicates/unknown IDs rejected', () => {
  const ex = {
    ...base,
    id: 't',
    type: 'wordBank',
    content: {
      tokens: [
        { id: 't1', text: 'the' },
        { id: 't2', text: 'cat' },
        { id: 't3', text: 'sees' },
        { id: 't4', text: 'the' },
        { id: 't5', text: 'dog' },
        { id: 't6', text: 'a' },
      ],
    },
    gradingRule: rule({ correctTokenIds: ['t1', 't2', 't3', 't4', 't5'] }),
  };
  assert.equal(
    gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t1', 't2', 't3', 't4', 't5'] }).correct,
    true,
  );
  assert.equal(
    gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t4', 't2', 't3', 't1', 't5'] }).correct,
    true,
    'repeated "the" chips are interchangeable',
  );
  assert.equal(
    gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t1', 't5', 't3', 't4', 't2'] }).correct,
    false,
  );
  assert.equal(
    gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t6', 't2', 't3', 't4', 't5'] }).correct,
    false,
    'distractor is wrong',
  );
  assert.throws(() => gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t1', 't1'] }), {
    code: 'VALIDATION_ERROR',
  });
  assert.throws(() => gradeAnswer(ex, { kind: 'tokens', tokenIds: ['zz'] }), {
    code: 'VALIDATION_ERROR',
  });
  assert.equal(
    gradeAnswer(ex, { kind: 'tokens', tokenIds: ['t1'] }).acceptedAnswer,
    'the cat sees the dog',
  );
});

test('pairs: complete authored connection set; reused/unknown endpoints and partial sets rejected', () => {
  const pairs = [1, 2, 3].map((n) => ({
    id: `p${n}`,
    left: { id: `l${n}`, text: `en${n}` },
    right: { id: `r${n}`, text: `vi${n}` },
  }));
  const ex = {
    ...base,
    id: 'm',
    type: 'matchPairs',
    content: { pairs },
    gradingRule: rule({ correctPairIds: ['p1', 'p2', 'p3'] }),
  };
  const m = (list) => ({
    kind: 'pairs',
    matches: list.map(([l, r]) => ({ leftId: l, rightId: r })),
  });
  assert.equal(
    gradeAnswer(
      ex,
      m([
        ['l2', 'r2'],
        ['l1', 'r1'],
        ['l3', 'r3'],
      ]),
    ).correct,
    true,
    'order-free',
  );
  assert.equal(
    gradeAnswer(
      ex,
      m([
        ['l1', 'r2'],
        ['l2', 'r1'],
        ['l3', 'r3'],
      ]),
    ).correct,
    false,
  );
  assert.throws(
    () =>
      gradeAnswer(
        ex,
        m([
          ['l1', 'r1'],
          ['l2', 'r1'],
          ['l3', 'r3'],
        ]),
      ),
    { code: 'VALIDATION_ERROR' },
  );
  assert.throws(
    () =>
      gradeAnswer(
        ex,
        m([
          ['l1', 'r1'],
          ['l2', 'r2'],
        ]),
      ),
    { code: 'VALIDATION_ERROR' },
  );
  assert.throws(
    () =>
      gradeAnswer(
        ex,
        m([
          ['l1', 'r1'],
          ['l2', 'r2'],
          ['lx', 'r3'],
        ]),
      ),
    { code: 'VALIDATION_ERROR' },
  );
});

test('speech: typed transcript graded against key; assessment job IDs are not fabricated into verdicts', () => {
  const ex = {
    ...base,
    id: 's',
    type: 'speakRepeat',
    content: { referenceText: 'Hello', locale: 'en-US', maxSeconds: 5 },
    gradingRule: rule({ acceptedText: ['Hello'] }),
  };
  assert.equal(gradeAnswer(ex, say('hello!')).correct, true);
  assert.throws(() => gradeAnswer(ex, { kind: 'speech', assessmentJobId: 'job1' }), {
    code: 'VALIDATION_ERROR',
  });
});

test('substitution grades the authored alternative; none authored -> invalid', () => {
  const alt = {
    ...base,
    id: 'sa',
    type: 'choice',
    content: {
      choices: [
        { id: 'c1', text: 'a' },
        { id: 'c2', text: 'b' },
      ],
    },
    gradingRule: rule({ correctChoiceId: 'c1' }),
  };
  const ex = {
    ...base,
    id: 's',
    type: 'speakRepeat',
    content: { referenceText: 'a', locale: 'en-US', maxSeconds: 5 },
    gradingRule: rule({ acceptedText: ['a'] }),
    nonSpeechAlternative: alt,
  };
  assert.equal(gradedExercise(ex, false), ex);
  assert.equal(
    gradeAnswer(gradedExercise(ex, true), { kind: 'choice', choiceId: 'c1' }).correct,
    true,
  );
  assert.throws(() => gradedExercise(text(['x']), true), { code: 'VALIDATION_ERROR' });
});

test('golden fixtures: every committed exercise accepts its own authored key and rejects a wrong one', async () => {
  const { correctAnswer, wrongAnswer } = await import('./helpers/answers.mjs');
  const fs = await import('node:fs');
  const dir = 'content/vi_en/dist/v2/bundles';
  let checked = 0;
  for (const file of fs.readdirSync(dir)) {
    const bundle = JSON.parse(fs.readFileSync(`${dir}/${file}`, 'utf8'));
    for (const ex of bundle.exercises) {
      for (const candidate of [ex, ex.nonAudioAlternative, ex.nonSpeechAlternative].filter(
        Boolean,
      )) {
        assert.equal(gradeAnswer(candidate, correctAnswer(candidate)).correct, true, candidate.id);
        assert.equal(gradeAnswer(candidate, wrongAnswer(candidate)).correct, false, candidate.id);
        for (const alt of candidate.gradingRule.acceptedText ?? [])
          assert.equal(gradeAnswer(candidate, say(alt)).correct, true, `${candidate.id}: ${alt}`);
        checked++;
      }
    }
  }
  assert.ok(checked > 6000, `checked ${checked}`);
});
