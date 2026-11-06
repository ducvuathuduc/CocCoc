import { z } from 'zod';

const level = z.union([z.literal(1), z.literal(2), z.literal(3), z.literal(4), z.literal(5)]);

export const vocabRowSchema = z.object({
  level,
  en: z.string(),
  enAlts: z.array(z.string()),
  vi: z.string(),
  viAlts: z.array(z.string()),
  img: z.boolean(),
  forms: z.array(z.string()),
  id: z.string(),
});

export const sentenceRowSchema = z.object({
  en: z.string(),
  enAlts: z.array(z.string()),
  vi: z.string(),
  viAlts: z.array(z.string()),
});

export const dialogueRowSchema = z.object({
  line: z.string(),
  reply: z.string(),
  replyAlts: z.array(z.string()),
  vi: z.string(),
});

export const storyQuestionSchema = z.object({
  q: z.string(),
  correct: z.string(),
  wrongs: z.array(z.string()),
});

export const unitDraftSchema = z.object({
  theme: z.string().min(1).max(40),
  cefr: z.enum(['A1', 'A2', 'B1', 'B2']),
  // Empty title stays schema-legal; lintUnit is the one that tells the editor the lesson has no name.
  title: z.string().max(120),
  levels: z.array(z.string().max(80)).length(5),
  guide: z.string().max(8000),
  vocab: z.array(vocabRowSchema).max(200),
  sentences: z.array(sentenceRowSchema).max(200),
  dialogues: z.array(dialogueRowSchema).max(100),
  story: z.object({
    title: z.string().max(120),
    passage: z.string().max(6000),
    questions: z.array(storyQuestionSchema).max(20),
  }),
});

export const courseDraftSchema = z.object({
  course: z.object({
    courseId: z.string().min(1).max(40),
    title: z.string().min(1).max(120),
    sourceLocale: z.string().min(2).max(10),
    targetLocale: z.string().min(2).max(10),
    status: z.enum(['DRAFT', 'ACTIVE', 'RETIRED']),
  }),
  sections: z
    .array(
      z.object({
        sectionId: z.string().max(20),
        title: z.string().max(120),
        units: z.array(z.string().max(40)),
      }),
    )
    .max(20),
  version: z.string().min(1).max(10),
});

export type ParsedUnitDraft = z.infer<typeof unitDraftSchema>;

/**
 * A bulk find/replace arrives from a form, so its shape is checked at the boundary like any other input.
 * `to` may be empty — deleting a word from every sentence is a real edit — but `find` may not, because an
 * empty needle would match every cell in the course.
 */
export const replaceRequestSchema = z.object({
  find: z.string().min(1).max(200),
  to: z.string().max(2000),
  targets: z
    .array(
      z.object({
        list: z.enum(['vocab', 'sentences', 'dialogues', 'story', 'unit']),
        field: z.string().min(1).max(40),
      }),
    )
    .min(1)
    .max(40),
});
