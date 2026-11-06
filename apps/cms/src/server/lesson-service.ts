import path from 'node:path';
import { readFile } from 'node:fs/promises';
import { generatorUnitId } from '@/cms/media';
import {
  parseLesson,
  staleWordIds,
  wordIndex,
  type BuiltLesson,
  type BuiltNode,
  type BuiltWordRef,
} from '@/cms/lessons';
import type { UnitRecord } from '@/cms/types';
import { assertSafeId } from './media-service';
import { config } from './config';
import { getStore } from './store';

export interface UnitLessonReport {
  courseId: string;
  unitId: string;
  /** The version the drafts are aimed at — the build directory is read from it, never guessed. */
  version: string;
  /** `uNN` the generator gave this unit by position, which is how the build names everything. */
  unitNumber: string;
  revision: number;
  manifestFound: boolean;
  nodes: BuiltNode[];
  lessons: BuiltLesson[];
  exerciseCount: number;
  /** Lesson ids the manifest lists but no bundle file answered. */
  missing: string[];
  /** Bundle files that exist but are not a lesson bundle, so the count cannot include them. */
  unreadable: string[];
  types: Record<string, number>;
  /** `uNN.<wordId>` the build asks about while no draft in the course owns it any more. */
  stale: string[];
  /** Which editor screen each `uNN` in the build belongs to, so a borrowed word links to its own unit. */
  unitIds: Record<string, string>;
}

interface ManifestShape {
  nodes?: { nodeId?: unknown; unitId?: unknown; title?: unknown; kind?: unknown; lessonIds?: unknown }[];
}

function nodesByUnit(manifest: ManifestShape): Map<string, BuiltNode[]> {
  const out = new Map<string, BuiltNode[]>();
  if (!Array.isArray(manifest.nodes)) return out;
  for (const node of manifest.nodes) {
    if (typeof node?.unitId !== 'string' || typeof node?.nodeId !== 'string') continue;
    const list = out.get(node.unitId) ?? [];
    list.push({
      nodeId: node.nodeId,
      title: typeof node.title === 'string' ? node.title : node.nodeId,
      kind: typeof node.kind === 'string' ? node.kind : 'lesson',
      lessonIds: Array.isArray(node.lessonIds)
        ? node.lessonIds.filter((id): id is string => typeof id === 'string')
        : [],
    });
    out.set(node.unitId, list);
  }
  return out;
}

function nodesOf(manifest: ManifestShape, unitNumber: string): BuiltNode[] {
  return nodesByUnit(manifest).get(unitNumber) ?? [];
}

/** The course-wide word index: `uNN.<wordId>` → the editor row that owns it, in whichever unit taught it. */
function courseIndex(units: UnitRecord[]): {
  words: Map<string, BuiltWordRef>;
  unitIds: Record<string, string>;
} {
  const words = new Map<string, BuiltWordRef>();
  const unitIds: Record<string, string> = {};
  for (const u of units) {
    const number = generatorUnitId(u.order);
    unitIds[number] = u.unitId;
    for (const [key, ref] of wordIndex(u.draft, number)) if (!words.has(key)) words.set(key, ref);
  }
  return { words, unitIds };
}

interface BundleRead {
  nodes: BuiltNode[];
  lessons: BuiltLesson[];
  exerciseCount: number;
  missing: string[];
  unreadable: string[];
  types: Record<string, number>;
}

/** One loop for both screens, so the checklist cannot count a unit differently from that unit's own page. */
async function readBundles(
  dist: string,
  nodes: BuiltNode[],
  words: Map<string, BuiltWordRef>,
): Promise<BundleRead> {
  const read: BundleRead = { nodes, lessons: [], exerciseCount: 0, missing: [], unreadable: [], types: {} };
  const nodeByLesson = new Map<string, BuiltNode>();
  for (const node of nodes) for (const lessonId of node.lessonIds) nodeByLesson.set(lessonId, node);

  for (const node of nodes) {
    for (const lessonId of node.lessonIds) {
      assertSafeId(lessonId, 'lessonId');
      let raw: unknown;
      try {
        raw = JSON.parse(await readFile(path.join(dist, 'bundles', `${lessonId}.json`), 'utf8'));
      } catch {
        read.missing.push(lessonId);
        continue;
      }
      const lesson = parseLesson(raw, nodeByLesson.get(lessonId), words);
      if (!lesson) {
        read.unreadable.push(lessonId);
        continue;
      }
      read.lessons.push(lesson);
      read.exerciseCount += lesson.exercises.length;
      for (const exercise of lesson.exercises)
        read.types[exercise.type] = (read.types[exercise.type] ?? 0) + 1;
    }
  }
  return read;
}

async function openBuild(courseId: string): Promise<{
  version: string;
  dist: string;
  manifest: ManifestShape | null;
  words: Map<string, BuiltWordRef>;
  unitIds: Record<string, string>;
} | null> {
  const store = getStore();
  const units = await store.listUnits(courseId);
  const course = await store.getCourse(courseId);
  if (!course) return null;
  const version = course.draft.version;
  const safeCourse = assertSafeId(courseId, 'courseId');
  const safeVersion = assertSafeId(version, 'version');
  const dist = path.join(config().repoRoot, 'content', safeCourse, 'dist', safeVersion);
  return {
    version,
    dist,
    manifest: await readManifest(path.join(dist, 'manifest.json')),
    ...courseIndex(units),
  };
}

async function readManifest(file: string): Promise<ManifestShape | null> {
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch {
    return null;
  }
}

/**
 * The unit's lessons as the last build handed them to the app. Read-only on purpose: the bundles are the
 * frozen input the phone plays, so the screen that answers "what will the learner be asked" must read them
 * rather than re-derive them from a draft.
 */
export async function unitLessons(
  courseId: string,
  unitId: string,
): Promise<(UnitLessonReport & { unit: UnitRecord }) | null> {
  const unit = (await getStore().listUnits(courseId)).find((u) => u.unitId === unitId);
  if (!unit) return null;
  const build = await openBuild(courseId);
  const unitNumber = generatorUnitId(unit.order);
  const report: UnitLessonReport = {
    courseId,
    unitId,
    version: build?.version ?? 'v2',
    unitNumber,
    revision: unit.revision,
    manifestFound: false,
    nodes: [],
    lessons: [],
    exerciseCount: 0,
    missing: [],
    unreadable: [],
    types: {},
    stale: [],
    unitIds: build?.unitIds ?? {},
  };
  if (!build) return { ...report, unit };
  if (!build.manifest) return { ...report, unit };

  report.manifestFound = true;
  const read = await readBundles(build.dist, nodesOf(build.manifest, unitNumber), build.words);
  report.stale = staleWordIds(read.lessons);
  return { ...report, ...read, unit };
}

export interface StaleUnit {
  unitId: string;
  /** `uNN` the build gave this unit by position, which is what its lesson screen prints. */
  unitNumber: string;
  ids: string[];
}

export interface CourseLessonDrift {
  courseId: string;
  version: string;
  manifestFound: boolean;
  unitIds: Record<string, string>;
  lessonCount: number;
  exerciseCount: number;
  missing: string[];
  unreadable: string[];
  /** Every unit whose build asks about a word no draft in the course owns any more. */
  stale: StaleUnit[];
}

/**
 * The same reading, for every unit at once: the course-level question is not "what does unit 9 ask" but
 * "is the build the app has still in sync with the drafts". Each unit's own number comes from the same loop
 * the unit screen uses, so the two cannot drift apart.
 */
export async function courseLessonDrift(courseId: string): Promise<CourseLessonDrift | null> {
  const build = await openBuild(courseId);
  if (!build) return null;
  const drift: CourseLessonDrift = {
    courseId,
    version: build.version,
    manifestFound: false,
    unitIds: build.unitIds,
    lessonCount: 0,
    exerciseCount: 0,
    missing: [],
    unreadable: [],
    stale: [],
  };
  if (!build.manifest) return drift;
  drift.manifestFound = true;

  for (const [unitNumber, nodes] of nodesByUnit(build.manifest)) {
    const read = await readBundles(build.dist, nodes, build.words);
    const ids = staleWordIds(read.lessons);
    drift.lessonCount += read.lessons.length;
    drift.exerciseCount += read.exerciseCount;
    drift.missing.push(...read.missing);
    drift.unreadable.push(...read.unreadable);
    const unitId = build.unitIds[unitNumber];
    if (ids.length && unitId) drift.stale.push({ unitId, unitNumber, ids });
  }
  drift.stale.sort((a, b) => a.unitNumber.localeCompare(b.unitNumber, 'en', { numeric: true }));
  return drift;
}

