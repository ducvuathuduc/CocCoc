// Deterministic answer checking (SRS "Deterministic learning and reward rules", CONTENT_MODEL).
// Pure: no I/O, no clock, no LLM. The same authored key always gives the same verdict.
import { ServiceError } from '../../../shared/src/errors.js';
import type {
  Answer,
  Choice,
  Exercise,
  ExerciseType,
  GradingRule,
  Pair,
  Token,
} from '../content/types.js';

export interface GradeResult {
  correct: boolean;
  /** Display form of the authored answer (first accepted text, choice text, token sentence). */
  acceptedAnswer: string;
}

/** Which answer kind each exercise type takes. Speech types accept a typed transcript. */
const ANSWER_KIND: Record<ExerciseType, readonly Answer['kind'][]> = {
  textTranslation: ['text'],
  fillBlank: ['text'],
  dictation: ['text'],
  speakRepeat: ['text', 'speech'],
  dialogueTurn: ['text', 'speech'],
  choice: ['choice'],
  imageChoice: ['choice'],
  listenChoice: ['choice'],
  storyQuestion: ['choice'],
  wordBank: ['tokens'],
  sentenceOrder: ['tokens'],
  matchPairs: ['pairs'],
};

const PUNCTUATION = /[\p{P}\p{S}]/gu;
const COMBINING = /\p{M}/gu;
const QUOTES: Record<string, string> = {
  '\u2018': "'",
  '\u2019': "'",
  '\u02BC': "'",
  '\u201C': '"',
  '\u201D': '"',
};

/**
 * NFC, unify typographic quotes, trim, collapse whitespace; then the authored flags:
 * case fold (locale-aware), punctuation removal, diacritic removal. Diacritics are significant
 * unless the rule explicitly says ignoreDiacritics (Vietnamese accents stay meaningful).
 */
export function normalizeText(value: string, rule: GradingRule, locale = 'en-US'): string {
  let text = value
    .normalize('NFC')
    .replace(/[\u2018\u2019\u02BC\u201C\u201D]/g, (c) => QUOTES[c] ?? c);
  if (rule.ignorePunctuation) text = text.replace(PUNCTUATION, ' ');
  text = text.replace(/\s+/gu, ' ').trim();
  if (!rule.caseSensitive) text = text.toLocaleLowerCase(locale);
  if (rule.ignoreDiacritics) {
    text = text
      .normalize('NFD')
      .replace(COMBINING, '')
      .replace(/đ/g, 'd')
      .replace(/Đ/g, 'D')
      .normalize('NFC');
  }
  return text;
}

function choices(exercise: Exercise): Choice[] {
  const content = exercise.content as { choices?: Choice[] };
  return content.choices ?? [];
}
function tokens(exercise: Exercise): Token[] {
  return (exercise.content as { tokens?: Token[] }).tokens ?? [];
}
function pairs(exercise: Exercise): Pair[] {
  return (exercise.content as { pairs?: Pair[] }).pairs ?? [];
}

function invalid(reason: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { field: 'answer', reason } });
}

export function gradeAnswer(exercise: Exercise, answer: Answer): GradeResult {
  if (!ANSWER_KIND[exercise.type].includes(answer.kind)) invalid('ANSWER_KIND_MISMATCH');
  const rule = exercise.gradingRule;
  switch (answer.kind) {
    case 'text': {
      const accepted = rule.acceptedText ?? [];
      if (!accepted.length) invalid('NO_ANSWER_KEY');
      if (answer.text.length > 512) invalid('TOO_LONG');
      // vi and en share Unicode default case folding, so one locale serves both directions.
      const locale = 'en-US';
      const given = normalizeText(answer.text, rule, locale);
      if (!given) invalid('EMPTY');
      const correct = accepted.some((text) => normalizeText(text, rule, locale) === given);
      return { correct, acceptedAnswer: accepted[0] ?? '' };
    }
    case 'choice': {
      const options = choices(exercise);
      if (!options.some((c) => c.id === answer.choiceId)) invalid('UNKNOWN_CHOICE');
      const right = options.find((c) => c.id === rule.correctChoiceId);
      return {
        correct: answer.choiceId === rule.correctChoiceId,
        acceptedAnswer: right?.text ?? '',
      };
    }
    case 'tokens': {
      const bank = tokens(exercise);
      const byId = new Map(bank.map((t) => [t.id, t]));
      const seen = new Set<string>();
      for (const id of answer.tokenIds) {
        if (!byId.has(id)) invalid('UNKNOWN_TOKEN');
        if (seen.has(id)) invalid('DUPLICATE_TOKEN');
        seen.add(id);
      }
      if (!answer.tokenIds.length) invalid('EMPTY');
      // Repeated words carry distinct IDs; tokens with identical text are one identity class so
      // swapping two "the" chips is not a mistake. Distinct words still compare by ID class.
      const classOf = new Map<string, string>();
      const firstByText = new Map<string, string>();
      for (const token of bank) {
        const first = firstByText.get(token.text) ?? token.id;
        firstByText.set(token.text, first);
        classOf.set(token.id, first);
      }
      const expected = rule.correctTokenIds ?? [];
      const correct =
        expected.length === answer.tokenIds.length &&
        expected.every(
          (id, index) => classOf.get(id) === classOf.get(answer.tokenIds[index] ?? ''),
        );
      const sentence = expected.map((id) => byId.get(id)?.text ?? '').join(' ');
      return { correct, acceptedAnswer: sentence.replace(/\s+([.,!?])/g, '$1').slice(0, 512) };
    }
    case 'pairs': {
      const authored = pairs(exercise);
      const lefts = new Map(authored.map((p) => [p.left.id, p]));
      const rights = new Set(authored.map((p) => p.right.id));
      const usedLeft = new Set<string>();
      const usedRight = new Set<string>();
      for (const match of answer.matches) {
        if (!lefts.has(match.leftId) || !rights.has(match.rightId)) invalid('UNKNOWN_ENDPOINT');
        if (usedLeft.has(match.leftId) || usedRight.has(match.rightId)) invalid('REUSED_ENDPOINT');
        usedLeft.add(match.leftId);
        usedRight.add(match.rightId);
      }
      if (answer.matches.length !== authored.length) invalid('INCOMPLETE_PAIRS');
      const required = new Set(rule.correctPairIds ?? []);
      const correct = answer.matches.every((match) => {
        const pair = lefts.get(match.leftId);
        return !!pair && pair.right.id === match.rightId && required.has(pair.id);
      });
      const display = authored.map((p) => `${p.left.text} = ${p.right.text}`).join('; ');
      return { correct, acceptedAnswer: display.slice(0, 512) };
    }
    case 'speech':
      // Assessment-job linkage belongs to AI (P8). Until it exists the deterministic lesson takes
      // the typed transcript or the authored nonSpeechAlternative; never a fabricated verdict.
      return invalid('SPEECH_ASSESSMENT_UNAVAILABLE');
  }
}

/** The exercise actually graded: the authored capability substitute when substituted=true. */
export function gradedExercise(exercise: Exercise, substituted: boolean): Exercise {
  if (!substituted) return exercise;
  const alternative = exercise.nonSpeechAlternative ?? exercise.nonAudioAlternative;
  if (!alternative) invalid('NO_SUBSTITUTE');
  return alternative;
}
