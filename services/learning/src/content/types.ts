// Internal content model. Structurally identical to the OpenAPI wire DTOs (docs/api/openapi.yaml:
// Exercise, LessonBundle, CourseManifest, Answer). The generated union types type `content` as
// Record<string, never>, so Learning keeps a precise local model and validates at its boundaries.

export const EXERCISE_TYPES = [
  'textTranslation',
  'choice',
  'wordBank',
  'sentenceOrder',
  'fillBlank',
  'matchPairs',
  'imageChoice',
  'listenChoice',
  'dictation',
  'speakRepeat',
  'dialogueTurn',
  'storyQuestion',
] as const;
export type ExerciseType = (typeof EXERCISE_TYPES)[number];

export const SESSION_MODES = ['LESSON', 'REVIEW', 'MASTERY', 'PLACEMENT'] as const;
export type SessionMode = (typeof SESSION_MODES)[number];

export interface Prompt {
  text: string;
  locale: string;
  audioAssetId?: string | null;
}
export interface Choice {
  id: string;
  text: string;
  imageAssetId?: string | null;
  audioAssetId?: string | null;
}
export interface Token {
  id: string;
  text: string;
}
export interface Pair {
  id: string;
  left: Choice;
  right: Choice;
}
export interface GradingRule {
  caseSensitive: boolean;
  ignorePunctuation: boolean;
  ignoreDiacritics: boolean;
  acceptedText?: string[];
  correctChoiceId?: string | null;
  correctTokenIds?: string[];
  correctPairIds?: string[];
}
export type ExerciseContent =
  | { placeholder: string; maxChars: number }
  | { choices: Choice[] }
  | { tokens: Token[] }
  | { pairs: Pair[] }
  | { referenceText: string; locale: string; maxSeconds: number }
  | { passage: string; question: string; choices: Choice[] };

export interface Exercise {
  id: string;
  type: ExerciseType;
  prompt: Prompt;
  content: ExerciseContent;
  gradingRule: GradingRule;
  hint: string;
  explanation: string;
  skillIds: string[];
  vocabularyIds: string[];
  nonAudioAlternative?: Exercise;
  nonSpeechAlternative?: Exercise;
}

export interface Asset {
  fileId: string;
  sha256: string;
  mime: 'audio/wav' | 'audio/aac' | 'image/webp' | 'image/png';
  bytes: number;
  durationMs?: number | null;
  width?: number | null;
  height?: number | null;
  locale?: string | null;
  voice?: string | null;
  speed?: number | null;
  provider?: string | null;
  modelVersion?: string | null;
  altText: string;
}

export interface LessonBundle {
  schemaVersion: 1;
  courseId: string;
  courseVersion: string;
  sectionId: string;
  unitId: string;
  nodeId: string;
  order: number;
  lessonId: string;
  lessonVersion: string;
  rewardIdentity: string;
  title: string;
  skillIds: string[];
  guideText?: string;
  exercises: Exercise[];
  assets: Asset[];
  gradingRulesVersion: string;
  manifestHash: string;
  signature: string;
  signatureKeyId: string;
}

export type NodeKind = 'lesson' | 'story' | 'listening' | 'speaking' | 'mastery';
export interface ContentSection {
  sectionId: string;
  title: string;
  unitIds: string[];
}
export interface ContentUnit {
  unitId: string;
  sectionId: string;
  title: string;
  guideText: string;
  nodeIds: string[];
}
export interface ContentNode {
  nodeId: string;
  unitId: string;
  sectionId: string;
  order: number;
  title: string;
  kind: NodeKind;
  lessonIds: string[];
}
export interface BundleIndex {
  lessonId: string;
  lessonVersion: string;
  rewardIdentity: string;
  fileId: string;
  sha256: string;
}
export interface CourseManifest {
  schemaVersion: 1;
  courseId: string;
  courseVersion: string;
  sourceLocale: string;
  targetLocale: string;
  title: string;
  sections: ContentSection[];
  units: ContentUnit[];
  nodes: ContentNode[];
  bundles: BundleIndex[];
  placementBundle: BundleIndex;
  manifestHash: string;
  signatureKeyId: string;
  signature: string;
}

export type Answer =
  | { kind: 'text'; text: string }
  | { kind: 'choice'; choiceId: string }
  | { kind: 'tokens'; tokenIds: string[] }
  | { kind: 'pairs'; matches: { leftId: string; rightId: string }[] }
  | { kind: 'speech'; assessmentJobId: string };
