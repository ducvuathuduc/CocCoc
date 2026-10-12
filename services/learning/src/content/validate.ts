// Publish-time content validation (FR-CONTENT-001). Rejects unknown exercise types, missing or
// inconsistent answer keys, media prompts without a text alternative, unknown assets and broken
// structure. Hash/signature checks live in integrity.ts and run beside this.
import { EXERCISE_TYPES, type CourseManifest, type Exercise, type LessonBundle } from './types.js';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const AUDIO_PROMPT_TYPES = new Set(['listenChoice', 'dictation']);
const SPEECH_TYPES = new Set(['speakRepeat', 'dialogueTurn']);
const TEXT_TYPES = new Set([
  'textTranslation',
  'fillBlank',
  'dictation',
  'speakRepeat',
  'dialogueTurn',
]);
const CHOICE_TYPES = new Set(['choice', 'imageChoice', 'listenChoice', 'storyQuestion']);
const TOKEN_TYPES = new Set(['wordBank', 'sentenceOrder']);

/** Mirrors OpenAPI CourseManifest/ContentSection/ContentUnit maxItems (scaled 2026-10-12). */
export const MANIFEST_LIMITS = {
  sections: 20,
  units: 120,
  nodes: 600,
  bundles: 1200,
  unitsPerSection: 30,
  nodesPerUnit: 30,
} as const;

export interface ContentProblem {
  where: string;
  problem: string;
}

function checkExercise(
  exercise: Exercise,
  where: string,
  assets: Set<string>,
  out: ContentProblem[],
  nested = false,
) {
  const add = (problem: string) => out.push({ where: `${where}/${exercise.id ?? '?'}`, problem });
  if (!ID.test(exercise.id ?? '')) add('INVALID_ID');
  if (!(EXERCISE_TYPES as readonly string[]).includes(exercise.type)) {
    add('UNKNOWN_EXERCISE_TYPE');
    return;
  }
  const rule = exercise.gradingRule;
  if (
    !rule ||
    typeof rule.caseSensitive !== 'boolean' ||
    typeof rule.ignorePunctuation !== 'boolean' ||
    typeof rule.ignoreDiacritics !== 'boolean'
  ) {
    add('GRADING_RULE_FLAGS');
    return;
  }
  if (!exercise.prompt?.text || !exercise.prompt.locale) add('PROMPT_TEXT_REQUIRED');
  if (!exercise.skillIds?.length) add('SKILL_REQUIRED');
  if (exercise.vocabularyIds.length > 20) add('TOO_MANY_VOCABULARY');
  const content = exercise.content as Record<string, unknown>;
  if (TEXT_TYPES.has(exercise.type)) {
    const accepted = rule.acceptedText ?? [];
    if (
      !accepted.length ||
      accepted.length > 20 ||
      accepted.some((t) => !t.trim() || t.length > 512)
    )
      add('ACCEPTED_TEXT');
  }
  if (CHOICE_TYPES.has(exercise.type)) {
    const choices =
      (content['choices'] as { id: string; imageAssetId?: string | null }[] | undefined) ?? [];
    if (choices.length < 2 || choices.length > 8) add('CHOICE_COUNT');
    if (new Set(choices.map((c) => c.id)).size !== choices.length) add('DUPLICATE_CHOICE_ID');
    if (!choices.some((c) => c.id === rule.correctChoiceId)) add('CORRECT_CHOICE_MISSING');
    if (
      exercise.type === 'imageChoice' &&
      choices.some((c) => !c.imageAssetId || !assets.has(c.imageAssetId))
    )
      add('IMAGE_ASSET_MISSING');
    if (exercise.type === 'storyQuestion' && !content['passage']) add('PASSAGE_REQUIRED');
  }
  if (TOKEN_TYPES.has(exercise.type)) {
    const tokens = (content['tokens'] as { id: string }[] | undefined) ?? [];
    const ids = new Set(tokens.map((t) => t.id));
    const correct = rule.correctTokenIds ?? [];
    if (ids.size !== tokens.length) add('DUPLICATE_TOKEN_ID');
    if (
      !correct.length ||
      correct.some((id) => !ids.has(id)) ||
      new Set(correct).size !== correct.length
    )
      add('CORRECT_TOKENS');
    if (exercise.type === 'sentenceOrder' && correct.length !== tokens.length)
      add('ORDER_USES_ALL_TOKENS');
  }
  if (exercise.type === 'matchPairs') {
    const pairs =
      (content['pairs'] as
        { id: string; left: { id: string }; right: { id: string } }[] | undefined) ?? [];
    const correct = new Set(rule.correctPairIds ?? []);
    if (pairs.length < 2) add('PAIR_COUNT');
    if (pairs.length !== correct.size || pairs.some((p) => !correct.has(p.id)))
      add('CORRECT_PAIRS');
    const endpoints = pairs.flatMap((p) => [p.left.id, p.right.id]);
    if (new Set(endpoints).size !== endpoints.length) add('DUPLICATE_PAIR_ENDPOINT');
  }
  if (SPEECH_TYPES.has(exercise.type)) {
    if (!content['referenceText'] || !content['locale']) add('SPEECH_CONTENT');
    if (!exercise.nonSpeechAlternative) add('NON_SPEECH_ALTERNATIVE_REQUIRED');
  }
  const audio = exercise.prompt?.audioAssetId;
  if (audio && !assets.has(audio)) add('AUDIO_ASSET_MISSING');
  if (AUDIO_PROMPT_TYPES.has(exercise.type) && !audio) add('AUDIO_PROMPT_REQUIRED');
  if (
    (audio || AUDIO_PROMPT_TYPES.has(exercise.type)) &&
    !exercise.nonAudioAlternative &&
    !SPEECH_TYPES.has(exercise.type)
  ) {
    add('NON_AUDIO_ALTERNATIVE_REQUIRED');
  }
  for (const alternative of [exercise.nonAudioAlternative, exercise.nonSpeechAlternative]) {
    if (!alternative) continue;
    if (nested) add('NESTED_ALTERNATIVE');
    if (
      alternative.prompt?.audioAssetId ||
      AUDIO_PROMPT_TYPES.has(alternative.type) ||
      SPEECH_TYPES.has(alternative.type)
    ) {
      add('ALTERNATIVE_NEEDS_MEDIA');
    }
    if (alternative.skillIds.join() !== exercise.skillIds.join()) add('ALTERNATIVE_SKILLS_DIFFER');
    checkExercise(alternative, `${where}/${exercise.id}`, assets, out, true);
  }
}

export function validateBundle(bundle: LessonBundle, where = bundle.lessonId): ContentProblem[] {
  const out: ContentProblem[] = [];
  if (bundle.schemaVersion !== 1) out.push({ where, problem: 'SCHEMA_VERSION' });
  if (!bundle.exercises.length || bundle.exercises.length > 20)
    out.push({ where, problem: 'EXERCISE_COUNT' });
  const assetIds = new Set(bundle.assets.map((a) => a.fileId));
  if (assetIds.size !== bundle.assets.length) out.push({ where, problem: 'DUPLICATE_ASSET' });
  for (const asset of bundle.assets) {
    if (!/^[a-f0-9]{64}$/.test(asset.sha256) || !asset.altText)
      out.push({ where: `${where}/${asset.fileId}`, problem: 'ASSET_METADATA' });
  }
  const ids = bundle.exercises.map((e) => e.id);
  if (new Set(ids).size !== ids.length) out.push({ where, problem: 'DUPLICATE_EXERCISE_ID' });
  for (const exercise of bundle.exercises) checkExercise(exercise, where, assetIds, out);
  return out;
}

export function validateManifestStructure(manifest: CourseManifest): ContentProblem[] {
  const out: ContentProblem[] = [];
  const add = (where: string, problem: string) => out.push({ where, problem });
  if (manifest.schemaVersion !== 1) add('manifest', 'SCHEMA_VERSION');
  if (
    manifest.sections.length > MANIFEST_LIMITS.sections ||
    manifest.units.length > MANIFEST_LIMITS.units ||
    manifest.nodes.length > MANIFEST_LIMITS.nodes ||
    manifest.bundles.length > MANIFEST_LIMITS.bundles
  ) {
    add('manifest', 'SIZE_LIMIT');
  }
  const units = new Map(manifest.units.map((u) => [u.unitId, u]));
  const nodes = new Map(manifest.nodes.map((n) => [n.nodeId, n]));
  const bundles = new Map(manifest.bundles.map((b) => [b.lessonId, b]));
  if (bundles.size !== manifest.bundles.length) add('manifest', 'DUPLICATE_BUNDLE');
  if (new Set(manifest.nodes.map((n) => n.order)).size !== manifest.nodes.length)
    add('manifest', 'DUPLICATE_NODE_ORDER');
  for (const section of manifest.sections) {
    if (section.unitIds.length > MANIFEST_LIMITS.unitsPerSection)
      add(section.sectionId, 'SIZE_LIMIT');
    for (const unitId of section.unitIds) {
      if (units.get(unitId)?.sectionId !== section.sectionId)
        add(section.sectionId, 'UNIT_SECTION_MISMATCH');
    }
  }
  for (const unit of manifest.units) {
    if (unit.nodeIds.length > MANIFEST_LIMITS.nodesPerUnit) add(unit.unitId, 'SIZE_LIMIT');
    for (const nodeId of unit.nodeIds) {
      const node = nodes.get(nodeId);
      if (!node || node.unitId !== unit.unitId || node.sectionId !== unit.sectionId)
        add(unit.unitId, 'NODE_UNIT_MISMATCH');
    }
  }
  const referenced = new Set<string>();
  for (const node of manifest.nodes) {
    if (!node.lessonIds.length || node.lessonIds.length > 2) add(node.nodeId, 'LESSON_COUNT');
    for (const lessonId of node.lessonIds) {
      if (!bundles.has(lessonId)) add(node.nodeId, 'BUNDLE_MISSING');
      referenced.add(lessonId);
    }
  }
  for (const bundle of manifest.bundles)
    if (!referenced.has(bundle.lessonId)) add(bundle.lessonId, 'UNREFERENCED_BUNDLE');
  if (bundles.has(manifest.placementBundle.lessonId)) add('placement', 'PLACEMENT_IS_PATH_LESSON');
  return out;
}

/** Cross-bundle checks: pinned identity, all 12 renderers present in the course. */
export function validateCourse(
  manifest: CourseManifest,
  bundles: readonly LessonBundle[],
): ContentProblem[] {
  const out = validateManifestStructure(manifest);
  const seen = new Set<string>();
  for (const bundle of bundles) {
    out.push(...validateBundle(bundle));
    if (bundle.courseId !== manifest.courseId || bundle.courseVersion !== manifest.courseVersion) {
      out.push({ where: bundle.lessonId, problem: 'COURSE_PIN_MISMATCH' });
    }
    if (bundle.manifestHash !== manifest.manifestHash)
      out.push({ where: bundle.lessonId, problem: 'MANIFEST_HASH_MISMATCH' });
    for (const exercise of bundle.exercises) seen.add(exercise.type);
  }
  for (const type of EXERCISE_TYPES)
    if (!seen.has(type)) out.push({ where: 'course', problem: `MISSING_TYPE_${type}` });
  return out;
}
