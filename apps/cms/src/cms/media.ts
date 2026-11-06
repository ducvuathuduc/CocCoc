import type { UnitDraft } from './types';

export type MediaKind = 'audio' | 'image';

export interface CatalogItem {
  key: string;
  kind: string;
  text: string;
}

/** What the app asks for by fileId; `ext` is the file name suffix used on disk and in the bucket. */
export interface MediaSpec {
  fileId: string;
  kind: MediaKind;
  ext: 'aac' | 'webp';
  group: 'sentence' | 'dialogue' | 'word';
  label: string;
  /** The transcript the built catalog claims, falling back to the draft when the key is not in it. */
  text: string;
  /** What the saved draft says right now; differs from `text` whenever `dist/` is behind. */
  draft: string;
  /** Whether `audio-catalog.json` has this key at all — `generate-audio.mjs` only walks that file. */
  inCatalog: boolean;
  speed: 1 | 0.75;
}

/** `build-course.mjs:39` numbers units by position, and every asset key inherits that number. */
export const generatorUnitId = (order: number): string => `u${order + 1}`;

function audioClip(
  key: string,
  group: MediaSpec['group'],
  label: string,
  drafted: string,
  transcript: string | undefined,
  slow: boolean,
): MediaSpec[] {
  const base = {
    kind: 'audio' as const,
    ext: 'aac' as const,
    group,
    label,
    draft: drafted,
    text: transcript ?? drafted,
    inCatalog: transcript !== undefined,
  };
  const clips: MediaSpec[] = [{ fileId: `${key}.n`, ...base, speed: 1 }];
  if (slow) clips.push({ fileId: `${key}.s`, ...base, speed: 0.75 });
  return clips;
}

/**
 * Lists the media a unit needs, derived the way the generator derives it: one clip per authored
 * sentence and per dialogue line (normal + the 0.75x turtle clip) and one picture per vocabulary row
 * flagged `img`. Transcript comes from the catalog, falling back to the draft, so a unit edited since
 * the last build still shows what it asks for. Tap-to-hear word clips are not in here — see the note in
 * the vocab loop; the caller adds them from the build.
 */
export function unitMedia(genUnitId: string, draft: UnitDraft, catalog: CatalogItem[]): MediaSpec[] {
  const transcript = new Map(catalog.map((item) => [item.key, item.text]));
  const out: MediaSpec[] = [];

  draft.sentences.forEach((sentence, index) => {
    const key = `a.${genUnitId}.s${index + 1}`;
    out.push(
      ...audioClip(
        key,
        'sentence',
        `Câu ${index + 1}`,
        sentence.en,
        transcript.get(key),
        true,
      ),
    );
  });

  draft.dialogues.forEach((dialogue, index) => {
    const key = `a.${genUnitId}.d${index + 1}`;
    out.push(
      ...audioClip(
        key,
        'dialogue',
        `Thoại ${index + 1} (bạn nói)`,
        dialogue.line,
        transcript.get(key),
        true,
      ),
    );
  });

  for (const row of draft.vocab) {
    if (row.img)
      out.push({
        fileId: `i.${genUnitId}.${row.id}`,
        kind: 'image',
        ext: 'webp',
        group: 'word',
        label: `Ảnh của "${row.en}"`,
        text: row.vi,
        draft: row.vi,
        inCatalog: false,
        speed: 1,
      });
    // No word clip here on purpose. `a.w.<slug>.n` is keyed by the text printed on an exercise tile
    // (`build-course.mjs:166`), which is not the row id and not derivable from any authored field, so
    // `media-service.ts` reads those ids from the built bundles instead of guessing them.
  }

  return out;
}
