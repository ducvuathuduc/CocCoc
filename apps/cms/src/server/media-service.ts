import path from 'node:path';
import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { generatorUnitId, unitMedia, type CatalogItem, type MediaKind, type MediaSpec } from '@/cms/media';
import type { UnitDraft } from '@/cms/types';
import { getStore } from './store';
import { config } from './config';

export interface UnitAsset extends MediaSpec {
  present: boolean;
  /**
   * `build-course.mjs:117` only takes sha/bytes/duration from `audio-manifest.json`, and ignores an
   * entry whose `text` no longer matches. So a clip can sit on disk and still build as a placeholder.
   */
  manifest: 'real' | 'stale' | 'none';
  /**
   * The built catalog quotes different words than the saved draft, so the clip on disk is an older
   * take of a line that has since changed. Only provable for sentences and dialogue lines, whose
   * catalog text `build-course.mjs:1119` copies straight out of the draft.
   */
  drift: boolean;
  /** The id came from the last build rather than the draft, so editing the draft cannot make it change. */
  fromBuild: boolean;
  /**
   * A picture the draft asks for that no built lesson carries: the file may sit in the repo finished,
   * yet nothing ships it. Only ever true once a build exists, and only for images.
   */
  unused: boolean;
  /**
   * This word actually appeared inside an `imageChoice` drill of the last build. `build-course.mjs:918-925`
   * silently swaps the drill for a text choice while fewer than four pictures have been introduced, so a
   * picture can be on disk, shipped, and still never be asked about. Only ever true for images.
   */
  drilledWithPicture: boolean;
}

export interface MediaPayload {
  body: Uint8Array<ArrayBuffer>;
  mime: string;
}

export interface ManifestEntry {
  text: string;
  voice: string;
  speed: number;
  provider: string;
  sha256: string;
  bytes: number;
  durationMs: number;
}

const SAFE_ID = /^[a-z0-9][a-z0-9_.-]*$/;

/** Asset ids come from authored text, so anything that could climb out of the media tree is refused. */
export function assertSafeId(value: string, what: string): string {
  if (!SAFE_ID.test(value) || value.includes('..')) throw new Error(`${what} không hợp lệ: ${value}`);
  return value;
}

const mediaRoot = (courseId: string): string =>
  path.join(config().repoRoot, 'content', assertSafeId(courseId, 'courseId'), 'media');

const EXTENSION: Record<MediaSpec['ext'], { mime: string; directory: 'audio' | 'images' }> = {
  aac: { mime: 'audio/aac', directory: 'audio' },
  webp: { mime: 'image/webp', directory: 'images' },
};

/**
 * Resolves one fileId (no extension) to the file the publisher would upload. The suffix is implied by
 * the key: `a.` clips are `.aac`, `i.` pictures are `.webp`, exactly like `publish-appwrite.mjs:97`.
 */
export function mediaFile(courseId: string, fileId: string): { file: string; mime: string } {
  const { file, mime } = mediaTarget(courseId, fileId);
  return { file, mime };
}

function mediaTarget(
  courseId: string,
  fileId: string,
  knownExt?: MediaSpec['ext'],
): { file: string; mime: string; ext: MediaSpec['ext'] } {
  assertSafeId(fileId, 'fileId');
  const ext = knownExt ?? (fileId.startsWith('i.') ? 'webp' : 'aac');
  const { mime, directory } = EXTENSION[ext];
  const root = mediaRoot(courseId);
  const file = path.resolve(root, directory, `${fileId}.${ext}`);
  if (!file.startsWith(path.resolve(root, directory))) throw new Error('Đường dẫn media ra ngoài khóa.');
  return { file, mime, ext };
}

/** `tools/content/generate-audio.mjs:286` owns this file; the CMS only reads it. */
async function audioManifest(courseId: string): Promise<Record<string, ManifestEntry>> {
  try {
    const raw = await readFile(path.join(mediaRoot(courseId), 'audio-manifest.json'), 'utf8');
    return (JSON.parse(raw).files ?? {}) as Record<string, ManifestEntry>;
  } catch {
    return {};
  }
}

/** `python3 tools/content/lesson_art` writes images and `generate-audio.mjs` writes clips; either can be absent. */
async function directoryListing(courseId: string, directory: 'audio' | 'images'): Promise<Set<string>> {
  try {
    return new Set(await readdir(path.join(mediaRoot(courseId), directory)));
  } catch {
    return new Set();
  }
}

async function audioCatalog(courseId: string, version: string): Promise<CatalogItem[]> {
  const file = path.join(
    config().repoRoot,
    'content',
    assertSafeId(courseId, 'courseId'),
    'dist',
    assertSafeId(version, 'version'),
    'audio-catalog.json',
  );
  try {
    const parsed = JSON.parse(await readFile(file, 'utf8')) as { items?: CatalogItem[] };
    return parsed.items ?? [];
  } catch {
    return [];
  }
}

/** One asset a built lesson bundle hands the app. */
export interface BuiltAsset {
  fileId: string;
  kind: MediaKind;
  /** `altText` — the words the clip speaks, as the build recorded them. */
  text: string;
}

/**
 * Tap-to-hear word clips (`a.w.<slug>`) are keyed by the text printed on an exercise tile, which the
 * mobile app re-slugs at runtime (`build-course.mjs:166`). No authored field names them, so the only
 * honest source is the build itself: every lesson bundle lists the assets its unit ships with.
 *
 * The same bundles answer a question no authored field can: which exercise the app actually received.
 * `build-course.mjs:918-944` silently swaps `imageChoice` for a text choice when fewer than four
 * pictures have been introduced, and `dialogueTurn` for a repeat-the-sentence drill until three
 * distinct replies exist — the draft keeps asking for the picture exercise either way.
 */
async function builtAssets(
  courseId: string,
  version: string,
): Promise<{
  byUnit: Map<string, BuiltAsset[]>;
  unreadable: string[];
  types: Map<string, Record<string, number>>;
  shippedImages: Set<string>;
  pictureDrills: Set<string>;
}> {
  const directory = path.join(
    config().repoRoot,
    'content',
    assertSafeId(courseId, 'courseId'),
    'dist',
    assertSafeId(version, 'version'),
    'bundles',
  );
  const byUnit = new Map<string, Map<string, BuiltAsset>>();
  const types = new Map<string, Record<string, number>>();
  const shippedImages = new Set<string>();
  const pictureDrills = new Set<string>();
  const unreadable: string[] = [];
  let files: string[];
  try {
    files = await readdir(directory);
  } catch {
    return { byUnit: new Map(), unreadable, types: new Map(), shippedImages, pictureDrills };
  }
  for (const file of files.filter((name) => name.endsWith('.json')).sort()) {
    let bundle: {
      unitId?: unknown;
      lessonId?: unknown;
      assets?: { fileId?: unknown; mime?: unknown; altText?: unknown }[];
      exercises?: { type?: unknown; vocabularyIds?: unknown }[];
    };
    try {
      bundle = JSON.parse(await readFile(path.join(directory, file), 'utf8'));
    } catch {
      unreadable.push(file);
      continue;
    }
    if (typeof bundle.unitId !== 'string' || !Array.isArray(bundle.assets)) {
      unreadable.push(file);
      continue;
    }
    const seen = byUnit.get(bundle.unitId) ?? new Map<string, BuiltAsset>();
    byUnit.set(bundle.unitId, seen);
    for (const asset of bundle.assets) {
      if (typeof asset.fileId !== 'string' || !SAFE_ID.test(asset.fileId)) continue;
      seen.set(asset.fileId, {
        fileId: asset.fileId,
        kind: typeof asset.mime === 'string' && asset.mime.startsWith('image') ? 'image' : 'audio',
        text: typeof asset.altText === 'string' ? asset.altText : '',
      });
      if (asset.fileId.startsWith('i.')) shippedImages.add(asset.fileId);
    }
    // The placement test (`build-course.mjs:1035`) borrows unit 1's number but is not a unit lesson,
    // so counting it would make unit 1 look like it teaches exercises it never gives.
    if (!Array.isArray(bundle.exercises) || bundle.lessonId === 'placement') continue;
    const tally = types.get(bundle.unitId) ?? {};
    types.set(bundle.unitId, tally);
    for (const exercise of bundle.exercises) {
      if (typeof exercise?.type !== 'string') continue;
      tally[exercise.type] = (tally[exercise.type] ?? 0) + 1;
      // An `imageChoice` is the only drill that proves the app put the picture on screen: its tiles are
      // images. `vocabularyIds` names the word the drill asks about, in the same `uNN.<id>` shape the
      // picture file is named after, so a picture can be matched to the drill that used it.
      if (exercise.type === 'imageChoice' && Array.isArray(exercise.vocabularyIds))
        for (const vocabularyId of exercise.vocabularyIds)
          if (typeof vocabularyId === 'string') pictureDrills.add(vocabularyId);
    }
  }
  return {
    byUnit: new Map([...byUnit].map(([unit, assets]) => [unit, [...assets.values()]])),
    unreadable,
    types,
    shippedImages,
    pictureDrills,
  };
}

/** Everything a course's asset list is derived from, read once instead of once per unit. */
export interface MediaContext {
  catalog: CatalogItem[];
  audio: Set<string>;
  images: Set<string>;
  manifest: Record<string, ManifestEntry>;
  /** Assets per generator unit number (`u1`), as the last build handed them to the app. */
  built: Map<string, BuiltAsset[]>;
  /** Exercise types the last build actually emitted per unit — what the app shows, not what was asked. */
  builtTypes: Map<string, Record<string, number>>;
  /** Picture ids any built lesson carries; a draft picture outside this set is never shown. */
  shippedImages: Set<string>;
  /** `uNN.<vocabId>` for every word an `imageChoice` of the last build asked about. */
  pictureDrills: Set<string>;
  /** Bundle files that exist but could not be read, so the report can say so instead of looking clean. */
  unreadableBundles: string[];
}

async function loadMediaContext(courseId: string, version: string): Promise<MediaContext> {
  const [catalog, audio, images, manifest, built] = await Promise.all([
    audioCatalog(courseId, version),
    directoryListing(courseId, 'audio'),
    directoryListing(courseId, 'images'),
    audioManifest(courseId),
    builtAssets(courseId, version),
  ]);
  return {
    catalog,
    audio,
    images,
    manifest,
    built: built.byUnit,
    builtTypes: built.types,
    shippedImages: built.shippedImages,
    pictureDrills: built.pictureDrills,
    unreadableBundles: built.unreadable,
  };
}

/** The `.n`/`.s` suffix is a speed, not part of the catalog key. */
const baseKey = (fileId: string): string => fileId.replace(/\.[ns]$/, '');

/** A word clip is the one family the draft cannot name, so it is the only one taken from the build. */
const WORD_CLIP = /^a\.w\.[a-z0-9][a-z0-9_.-]*\.[ns]$/;

/**
 * What this unit asks the app to show or play, and whether the file is actually sitting in the repo.
 * Keys follow the generator (position, not the CMS `NN-theme` id), so a renumbered unit needs the clips
 * under its new number — the same rule `check:export` proves for text. Word clips come from the last
 * build, because their key is a slug of tile text (`build-course.mjs:166`), not of the vocab row id.
 */
export function deriveAssets(context: MediaContext, order: number, draft: UnitDraft): UnitAsset[] {
  const genUnitId = generatorUnitId(order);
  const specs = unitMedia(genUnitId, draft, context.catalog);
  // Without a build there is nothing to compare the draft against: every picture would look unused.
  const hasBuild = context.built.size > 0;
  const transcript = new Map(context.catalog.map((item) => [item.key, item.text]));
  const known = new Set(specs.map((spec) => spec.fileId));
  const builtIds = new Set<string>();
  for (const built of context.built.get(genUnitId) ?? []) {
    // A built sentence/dialogue/image clip the draft no longer asks for is a leftover of an older take,
    // not something the app still needs — only `a.w.*` is genuinely undiscoverable from the draft.
    if (!WORD_CLIP.test(built.fileId) || known.has(built.fileId)) continue;
    known.add(built.fileId);
    builtIds.add(built.fileId);
    const key = baseKey(built.fileId);
    const text = transcript.get(key) ?? built.text;
    specs.push({
      fileId: built.fileId,
      kind: built.kind,
      ext: built.kind === 'audio' ? 'aac' : 'webp',
      group: 'word',
      label: built.kind === 'audio' ? `Từ "${built.text}"` : `Ảnh "${built.text}"`,
      text,
      draft: text,
      inCatalog: transcript.has(key),
      speed: built.fileId.endsWith('.s') ? 0.75 : 1,
    });
  }
  return specs.map((spec) => {
    const present = (spec.kind === 'audio' ? context.audio : context.images).has(
      `${spec.fileId}.${spec.ext}`,
    );
    return {
      ...spec,
      present,
      manifest: manifestState(spec, present, context.manifest[spec.fileId]),
      drift: spec.kind === 'audio' && spec.inCatalog && spec.text !== spec.draft,
      fromBuild: builtIds.has(spec.fileId),
      unused: hasBuild && spec.kind === 'image' && !context.shippedImages.has(spec.fileId),
      // `i.u1.hello` is the picture of the word the build names `u1.hello`, so the two agree by id.
      drilledWithPicture:
        hasBuild && spec.kind === 'image' && context.pictureDrills.has(spec.fileId.slice(2)),
    };
  });
}

export async function unitAssets(
  courseId: string,
  version: string,
  order: number,
  draft: UnitDraft,
): Promise<{
  assets: UnitAsset[];
  catalogSize: number;
  exerciseTypes: Record<string, number>;
  /** False until a build exists, so the panel never claims a picture went unused with nothing to compare. */
  hasBuild: boolean;
}> {
  const context = await loadMediaContext(courseId, version);
  return {
    assets: deriveAssets(context, order, draft),
    catalogSize: context.catalog.length,
    exerciseTypes: context.builtTypes.get(generatorUnitId(order)) ?? {},
    hasBuild: context.built.size > 0,
  };
}

/**
 * A picture is trusted from its own bytes, so `present` is the whole story. A clip is not: the bundle
 * takes sha/duration from the manifest and ignores an entry whose transcript changed, so a file sitting
 * on disk with no matching entry still builds as a placeholder.
 */
function manifestState(
  spec: MediaSpec,
  present: boolean,
  entry: ManifestEntry | undefined,
): UnitAsset['manifest'] {
  if (spec.kind !== 'audio') return present ? 'real' : 'none';
  if (!entry) return 'none';
  return entry.text === spec.text ? 'real' : 'stale';
}

/**
 * Every asset id the units of this course ask the app for, keyed by fileId. Upload only writes ids from
 * this index, so a request cannot plant an arbitrary file name in the media tree — and a clip whose
 * number changed by a reorder is only accepted under its new number, the same rule the generator uses.
 * Word clips are in here because the build says the app asks for them, which is also what makes them
 * uploadable from the panel.
 */
export async function courseAssets(courseId: string): Promise<Map<string, UnitAsset>> {
  const store = getStore();
  const course = await store.getCourse(courseId);
  if (!course) return new Map();
  const [units, context] = await Promise.all([
    store.listUnits(courseId),
    loadMediaContext(courseId, course.draft.version),
  ]);
  const index = new Map<string, UnitAsset>();
  units.forEach((unit, position) => {
    for (const asset of deriveAssets(context, unit.order ?? position, unit.draft))
      if (!index.has(asset.fileId)) index.set(asset.fileId, asset);
  });
  return index;
}

export type MediaGapState = 'missing' | 'unmanifested' | 'drift';

/** One asset the app cannot get yet, with the same fields the unit panel shows, plus which unit asked. */
export interface MediaGap extends UnitAsset {
  /** `missing`: no file in the repo. `unmanifested`: file exists but the build still stubs the clip.
   *  `drift`: the built catalog itself is behind the draft, so no clip on disk can be right yet. */
  state: MediaGapState;
  unitId: string;
  genUnitId: string;
}

export interface UnitMediaSummary {
  unitId: string;
  title: string;
  genUnitId: string;
  order: number;
  total: number;
  audio: number;
  image: number;
  missing: number;
  unmanifested: number;
  drift: number;
  ready: number;
  /** Pictures the draft flags but no built lesson carries — on disk, correct, and never shown. */
  unused: number;
  /** Pictures no `imageChoice` of the last build asked about — shipped, but only ever drilled as text. */
  picturesWithoutDrill: number;
  /** Exercise types the last build emitted for this unit, e.g. `{ imageChoice: 3, choice: 43 }`. */
  exerciseTypes: Record<string, number>;
}

export interface CourseMediaReport {
  courseId: string;
  version: string;
  catalogSize: number;
  manifestSize: number;
  /** Bundle files under `dist/<version>/bundles/` the report could not read; empty in a clean build. */
  unreadableBundles: string[];
  /** Pictures on disk that no built lesson carries — owed by the content, not by the media tree. */
  unusedImages: string[];
  /** Pictures a lesson ships but no `imageChoice` ever asked about — the drills the generator downgraded. */
  picturesWithoutDrill: string[];
  units: UnitMediaSummary[];
  gaps: MediaGap[];
  totals: UnitMediaSummary;
}

/**
 * Course-wide view of the same derivation the unit panel uses, so whoever runs the generators can see
 * what the whole course still owes instead of opening 16 units. Gaps collapse by fileId: one clip is
 * one file to produce even if two units ask for it, and the command line takes the key once.
 */
export async function courseMediaReport(courseId: string): Promise<CourseMediaReport | null> {
  const store = getStore();
  const course = await store.getCourse(courseId);
  if (!course) return null;
  const [units, context] = await Promise.all([
    store.listUnits(courseId),
    loadMediaContext(courseId, course.draft.version),
  ]);

  const empty: UnitMediaSummary = {
    unitId: '',
    title: '',
    genUnitId: '',
    order: -1,
    total: 0,
    audio: 0,
    image: 0,
    missing: 0,
    unmanifested: 0,
    drift: 0,
    ready: 0,
    unused: 0,
    picturesWithoutDrill: 0,
    exerciseTypes: {},
  };
  const gaps = new Map<string, MediaGap>();
  const unusedImages = new Set<string>();
  const silentPictures = new Set<string>();
  const hasBuild = context.built.size > 0;
  const summaries = units.map((unit, position) => {
    const order = unit.order ?? position;
    const genUnitId = generatorUnitId(order);
    const summary: UnitMediaSummary = {
      ...empty,
      unitId: unit.unitId,
      title: unit.draft.title,
      genUnitId,
      order,
      exerciseTypes: context.builtTypes.get(genUnitId) ?? {},
    };
    for (const asset of deriveAssets(context, order, unit.draft)) {
      summary.total += 1;
      summary[asset.kind] += 1;
      if (asset.unused) {
        summary.unused += 1;
        unusedImages.add(asset.fileId);
      } else if (hasBuild && asset.kind === 'image' && !asset.drilledWithPicture) {
        summary.picturesWithoutDrill += 1;
        silentPictures.add(asset.fileId);
      }
      const state = gapState(asset);
      if (state) {
        summary[state] += 1;
        if (!gaps.has(asset.fileId))
          gaps.set(asset.fileId, { ...asset, state, unitId: unit.unitId, genUnitId: summary.genUnitId });
      } else summary.ready += 1;
    }
    return summary;
  });

  const exerciseTypes: Record<string, number> = {};
  for (const unit of summaries)
    for (const [type, count] of Object.entries(unit.exerciseTypes))
      exerciseTypes[type] = (exerciseTypes[type] ?? 0) + count;

  return {
    courseId,
    version: course.draft.version,
    catalogSize: context.catalog.length,
    manifestSize: Object.keys(context.manifest).length,
    unreadableBundles: context.unreadableBundles,
    unusedImages: [...unusedImages],
    picturesWithoutDrill: [...silentPictures],
    units: summaries,
    gaps: [...gaps.values()],
    totals: {
      ...summaries.reduce(
        (all, unit) => ({
          ...all,
          total: all.total + unit.total,
          audio: all.audio + unit.audio,
          image: all.image + unit.image,
          missing: all.missing + unit.missing,
          unmanifested: all.unmanifested + unit.unmanifested,
          drift: all.drift + unit.drift,
          ready: all.ready + unit.ready,
          unused: all.unused + unit.unused,
          picturesWithoutDrill: all.picturesWithoutDrill + unit.picturesWithoutDrill,
        }),
        { ...empty, total: 0 },
      ),
      exerciseTypes,
    },
  };
}

/** A picture is owed when the file is gone; a clip is owed until the catalog and manifest agree. */
function gapState(asset: UnitAsset): MediaGapState | null {
  if (asset.drift) return 'drift';
  if (!asset.present) return 'missing';
  return asset.kind === 'audio' && asset.manifest !== 'real' ? 'unmanifested' : null;
}

/**
 * The work list for `tools/content/generate-audio.mjs`, in the form its `--only` flag takes. Base keys
 * because the tool matches prefixes and makes `.n` + `.s` from one key. `drift` and `needsBuild` are the
 * two cases the tool cannot fix yet: the catalog quotes different words than the draft, or the key is not
 * in the catalog at all. Both need `build-course.mjs` first, because the tool only walks the catalog.
 */
export function audioTask(gaps: MediaGap[]): {
  keys: string[];
  needsBuild: string[];
  drift: string[];
} {
  const keys = new Set<string>();
  const needsBuild = new Set<string>();
  const drift = new Set<string>();
  for (const gap of gaps) {
    if (gap.kind !== 'audio') continue;
    const key = baseKey(gap.fileId);
    if (gap.state === 'drift') drift.add(key);
    else if (!gap.inCatalog) needsBuild.add(key);
    else keys.add(key);
  }
  return { keys: [...keys], needsBuild: [...needsBuild], drift: [...drift] };
}

/** Image keys the app asks for but cannot show yet — `lesson_art` names its output after these. */
export function imageTask(gaps: MediaGap[]): string[] {
  const keys = new Set<string>();
  for (const gap of gaps) if (gap.kind === 'image') keys.add(gap.fileId);
  return [...keys];
}

export interface MediaWrite {
  fileId: string;
  ext: MediaSpec['ext'];
  bytes: number;
  sha256: string;
  overwritten: boolean;
}

/** Drops one validated asset where `publish-appwrite.mjs` will find it. Never deletes anything. */
export async function writeMediaFile(
  courseId: string,
  spec: MediaSpec,
  body: Uint8Array,
  overwrite: boolean,
): Promise<MediaWrite> {
  const { file, ext } = mediaTarget(courseId, spec.fileId, spec.ext);
  const existing = await readFile(file).catch(() => null);
  if (existing && !overwrite)
    throw new Error(`File ${spec.fileId}.${ext} đã có trong kho media. Bấm “ghi đè” nếu muốn thay.`);
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, body);
  return {
    fileId: spec.fileId,
    ext,
    bytes: body.byteLength,
    sha256: createHash('sha256').update(body).digest('hex'),
    overwritten: Boolean(existing),
  };
}

/** Reads one media file for the admin preview route. */
export async function readMedia(courseId: string, fileId: string): Promise<MediaPayload | null> {
  const { file, mime } = mediaFile(courseId, fileId);
  try {
    const raw = await readFile(file);
    const body = new Uint8Array(raw.byteLength);
    body.set(raw);
    return { body, mime };
  } catch {
    return null;
  }
}
