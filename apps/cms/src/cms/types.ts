export type Cefr = 'A1' | 'A2' | 'B1' | 'B2';

export interface VocabRow {
  level: 1 | 2 | 3 | 4 | 5;
  en: string;
  enAlts: string[];
  vi: string;
  viAlts: string[];
  img: boolean;
  forms: string[];
  id: string;
}

export interface SentenceRow {
  en: string;
  enAlts: string[];
  vi: string;
  viAlts: string[];
}

export interface DialogueRow {
  line: string;
  reply: string;
  replyAlts: string[];
  vi: string;
}

export interface StoryQuestionRow {
  q: string;
  correct: string;
  wrongs: string[];
}

export interface StoryBlock {
  title: string;
  passage: string;
  questions: StoryQuestionRow[];
}

export interface UnitDraft {
  theme: string;
  cefr: Cefr;
  title: string;
  levels: string[];
  guide: string;
  vocab: VocabRow[];
  sentences: SentenceRow[];
  dialogues: DialogueRow[];
  story: StoryBlock;
}

export interface CourseMeta {
  courseId: string;
  title: string;
  sourceLocale: string;
  targetLocale: string;
  status: 'DRAFT' | 'ACTIVE' | 'RETIRED';
}

export interface SectionDraft {
  sectionId: string;
  title: string;
  units: string[];
}

export interface CourseDraft {
  course: CourseMeta;
  sections: SectionDraft[];
  version: string;
}

export interface UnitRecord {
  courseId: string;
  unitId: string;
  order: number;
  revision: number;
  updatedAt: string;
  updatedBy: string;
  draft: UnitDraft;
}

export interface CourseRecord {
  courseId: string;
  revision: number;
  updatedAt: string;
  updatedBy: string;
  draft: CourseDraft;
}

export interface BuildRun {
  runId: string;
  courseId: string;
  versionId: string;
  kind: 'GATES' | 'PUBLISH';
  status: 'RUNNING' | 'SUCCEEDED' | 'FAILED';
  message: string;
  log: string[];
  actorId: string;
  createdAt: string;
}

export interface AuditEntry {
  entryId: string;
  actorId: string;
  operation: string;
  targetId: string;
  beforeJson: string;
  afterJson: string;
  requestId: string;
  createdAt: string;
}
