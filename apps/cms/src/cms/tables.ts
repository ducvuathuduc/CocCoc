import type {
  DialogueRow,
  SentenceRow,
  StoryQuestionRow,
  UnitDraft,
  VocabRow,
} from './types';

const splitTrim = (text: string, sep: string): string[] =>
  text
    .split(sep)
    .map((x) => x.trim())
    .filter(Boolean);

export const slug = (text: string): string =>
  text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 20);

function tableLines(text: string): string[] {
  return text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('//'));
}

export function parseVocab(text: string): VocabRow[] {
  return tableLines(text).map((line) => {
    const m = /^([1-5])\s+(.+)$/.exec(line);
    if (!m) throw new Error(`Vocab line needs a level 1-5 at the start: "${line}"`);
    const [enPart = '', viPart = '', flagPart = ''] = splitTrim(m[2], '|');
    const [en = '', ...enAlts] = splitTrim(enPart, ',');
    const [vi = '', ...viAlts] = splitTrim(viPart, '/');
    const flags = flagPart.split(/\s+/).filter(Boolean);
    const flag = (name: string) => flags.find((f) => f === name || f.startsWith(`${name}=`));
    const formsFlag = flag('forms');
    const idFlag = flag('id');
    return {
      level: Number(m[1]) as VocabRow['level'],
      en,
      enAlts,
      vi,
      viAlts,
      img: Boolean(flag('img')),
      forms: formsFlag ? formsFlag.slice(6).split(',') : [],
      id: idFlag ? idFlag.slice(3) : slug(en),
    };
  });
}

export function renderVocab(rows: VocabRow[]): string {
  return rows
    .map((r) => {
      const flags: string[] = [];
      if (r.img) flags.push('img');
      if (r.forms.length) flags.push(`forms=${r.forms.join(',')}`);
      if (r.id && r.id !== slug(r.en)) flags.push(`id=${r.id}`);
      const en = [r.en, ...r.enAlts].filter(Boolean).join(', ');
      const vi = [r.vi, ...r.viAlts].filter(Boolean).join(' / ');
      return `${r.level} ${en} | ${vi}${flags.length ? ` | ${flags.join(' ')}` : ''}`;
    })
    .join('\n');
}

export function parseSentences(text: string): SentenceRow[] {
  return tableLines(text).map((line) => {
    const [enSide, viSide] = line.split(' = ');
    if (!viSide) throw new Error(`Sentence needs " = " between English and Vietnamese: "${line}"`);
    const [en = '', ...enAlts] = splitTrim(enSide, '##');
    const [vi = '', ...viAlts] = splitTrim(viSide, '##');
    return { en, enAlts, vi, viAlts };
  });
}

export function renderSentences(rows: SentenceRow[]): string {
  return rows
    .map((r) => `${[r.en, ...r.enAlts].filter(Boolean).join(' ## ')} = ${[r.vi, ...r.viAlts].filter(Boolean).join(' ## ')}`)
    .join('\n');
}

export function parseDialogues(text: string): DialogueRow[] {
  return tableLines(text).map((line) => {
    const [prompt, rest] = line.split(' => ');
    const [replySide, vi] = (rest ?? '').split(' = ');
    if (!replySide || !vi) throw new Error(`Dialogue needs " => " and " = ": "${line}"`);
    const [reply = '', ...replyAlts] = splitTrim(replySide, '##');
    return { line: prompt.trim(), reply, replyAlts, vi: vi.trim() };
  });
}

export function renderDialogues(rows: DialogueRow[]): string {
  return rows
    .map(
      (r) =>
        `${r.line} => ${[r.reply, ...r.replyAlts].filter(Boolean).join(' ## ')} = ${r.vi}`,
    )
    .join('\n');
}

export function parseStoryQuestions(text: string): StoryQuestionRow[] {
  return tableLines(text).map((line) => {
    const [q, answers] = line.split(' * ');
    if (!answers) throw new Error(`Story question needs " * " before the choices: "${line}"`);
    const choices = splitTrim(answers, '|');
    return { q: q.trim(), correct: choices[0] ?? '', wrongs: choices.slice(1) };
  });
}

export function renderStoryQuestions(rows: StoryQuestionRow[]): string {
  return rows
    .map((r) => `${r.q} * ${[r.correct, ...r.wrongs].filter(Boolean).join(' | ')}`)
    .join('\n');
}

export interface ParsedUnit {
  theme: string;
  cefr: UnitDraft['cefr'];
  title: string;
  levels: string[];
  guide: string;
  vocab: string;
  sentences: string;
  dialogues: string;
  storyTitle: string;
  passage: string;
  questions: string;
}

export function unitToTables(unit: UnitDraft): ParsedUnit {
  return {
    theme: unit.theme,
    cefr: unit.cefr,
    title: unit.title,
    levels: unit.levels,
    guide: unit.guide,
    vocab: renderVocab(unit.vocab),
    sentences: renderSentences(unit.sentences),
    dialogues: renderDialogues(unit.dialogues),
    storyTitle: unit.story.title,
    passage: unit.story.passage,
    questions: renderStoryQuestions(unit.story.questions),
  };
}

export function tablesToUnit(t: ParsedUnit): UnitDraft {
  return {
    theme: t.theme,
    cefr: t.cefr,
    title: t.title,
    levels: t.levels,
    guide: t.guide,
    vocab: parseVocab(t.vocab),
    sentences: parseSentences(t.sentences),
    dialogues: parseDialogues(t.dialogues),
    story: {
      title: t.storyTitle,
      passage: t.passage,
      questions: parseStoryQuestions(t.questions),
    },
  };
}
