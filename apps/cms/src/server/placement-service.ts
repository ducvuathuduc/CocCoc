import path from 'node:path';
import { readFile } from 'node:fs/promises';
import { generatorUnitId } from '@/cms/media';
import {
  placementItems,
  placementState,
  type BuiltPlacementItem,
  type PlacementItem,
  type PlacementState,
} from '@/cms/placement';
import { config } from './config';
import { assertSafeId } from './media-service';
import { getStore } from './store';

export interface PlacementRow {
  item: PlacementItem;
  state: PlacementState;
  /** The item this draft would produce never made it into the app, or is not comparable. */
  built: BuiltPlacementItem | null;
}

export interface PlacementReport {
  courseId: string;
  version: string;
  /** The unit the generator harvests the test from — always the first one. */
  unitId: string;
  unitTitle: string;
  genUnitId: string;
  rows: PlacementRow[];
  /** `placement-eNN` whose row no longer exists: `build-course.mjs` throws before it can warn. */
  blockers: string[];
  /** `placement-eNN` the app answers differently than this draft would: the next build rewrites them. */
  changed: string[];
  counts: { vocab: number; sentences: number; questions: number; pictures: number };
  /** Whether `dist/<version>/bundles/placement.json` could be read at all. */
  hasBuild: boolean;
  /** What the app tells the learner about passing, straight out of the built lesson. */
  guideText: string;
}

/** The app's own placement lesson; `build-course.mjs:1030` writes it next to the unit lessons. */
async function builtPlacement(
  courseId: string,
  version: string,
): Promise<{ items: BuiltPlacementItem[]; guideText: string }> {
  const file = path.join(
    config().repoRoot,
    'content',
    assertSafeId(courseId, 'courseId'),
    'dist',
    assertSafeId(version, 'version'),
    'bundles',
    'placement.json',
  );
  let bundle: {
    guideText?: unknown;
    exercises?: { id?: unknown; type?: unknown; prompt?: { text?: unknown }; vocabularyIds?: unknown }[];
  };
  try {
    bundle = JSON.parse(await readFile(file, 'utf8'));
  } catch {
    return { items: [], guideText: '' };
  }
  const items: BuiltPlacementItem[] = [];
  for (const exercise of bundle.exercises ?? []) {
    if (typeof exercise?.id !== 'string' || typeof exercise.type !== 'string') continue;
    items.push({
      id: exercise.id,
      type: exercise.type,
      prompt: typeof exercise.prompt?.text === 'string' ? exercise.prompt.text : '',
      vocabularyIds: Array.isArray(exercise.vocabularyIds)
        ? exercise.vocabularyIds.filter((v): v is string => typeof v === 'string')
        : [],
    });
  }
  return { items, guideText: typeof bundle.guideText === 'string' ? bundle.guideText : '' };
}

/**
 * What the placement test will ask, and what the shipped app already asks. Content editors cannot open
 * this lesson in the CMS, but they can break it: the generator reads ten fixed rows out of the first
 * unit, so shortening or reordering that unit rewrites — or stops — the test.
 */
export async function placementReport(courseId: string): Promise<PlacementReport | null> {
  const store = getStore();
  const [course, units] = await Promise.all([store.getCourse(courseId), store.listUnits(courseId)]);
  if (!course || units.length === 0) return null;

  const first = units[0];
  const genUnitId = generatorUnitId(first.order);
  const items = placementItems(first.draft, genUnitId);
  const built = await builtPlacement(courseId, course.draft.version);
  const byId = new Map(built.items.map((item) => [item.id, item]));

  const rows: PlacementRow[] = items.map((item) => ({
    item,
    built: byId.get(item.id) ?? null,
    state: placementState(item, byId.get(item.id)),
  }));

  return {
    courseId,
    version: course.draft.version,
    unitId: first.unitId,
    unitTitle: first.draft.title,
    genUnitId,
    rows,
    blockers: rows.filter((r) => !r.item.present).map((r) => r.item.id),
    changed: rows.filter((r) => r.state === 'changed').map((r) => r.item.id),
    counts: {
      vocab: first.draft.vocab.length,
      sentences: first.draft.sentences.length,
      questions: first.draft.story.questions.length,
      pictures: first.draft.vocab.filter((row) => row.img).length,
    },
    hasBuild: built.items.length > 0,
    guideText: built.guideText,
  };
}
