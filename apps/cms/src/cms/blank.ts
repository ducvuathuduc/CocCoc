import type { UnitDraft } from './types';

export function blankVocabRow(level: 1 | 2 | 3 | 4 | 5 = 1) {
  return { level, en: '', enAlts: [], vi: '', viAlts: [], img: false, forms: [], id: '' };
}

export function blankUnit(theme: string, cefr: UnitDraft['cefr'] = 'A1'): UnitDraft {
  return {
    theme,
    cefr,
    title: '',
    levels: ['', '', '', '', ''],
    guide: '',
    vocab: [blankVocabRow()],
    sentences: [],
    dialogues: [],
    story: { title: '', passage: '', questions: [] },
  };
}
