import {
  courseEntries,
  repeatedSentences,
  repeatedWords,
  repeatsInsideUnit,
  searchEntries,
  type RepeatGroup,
  type SearchHit,
} from '@/cms/search';
import { getStore } from './store';

/** A 16-unit course has thousands of strings; a page that lists them all is not an answer. */
export const HIT_LIMIT = 200;

export interface CourseSearchReport {
  courseId: string;
  query: string;
  unitCount: number;
  /** Strings the search actually looked at, so "no results" can say what it covered. */
  entryCount: number;
  hits: SearchHit[];
  truncated: boolean;
  limit: number;
  /** Headwords taught in more than one unit. */
  words: RepeatGroup[];
  /** Headwords repeated inside a single unit — a different fix from the one above. */
  insideUnit: RepeatGroup[];
  /** English sentences that appear more than once anywhere, same unit or not. */
  sentences: RepeatGroup[];
}

/**
 * Everything the search screen shows, from the drafts only. The duplicate lists come back whether or
 * not there is a query, because "what have I already taught" is the question that has no search box.
 */
export async function courseSearch(
  courseId: string,
  query: string,
): Promise<CourseSearchReport | null> {
  const units = await getStore().listUnits(courseId);
  if (units.length === 0) return null;
  const entries = courseEntries(units);
  const hits = searchEntries(entries, query, HIT_LIMIT);
  return {
    courseId,
    query,
    unitCount: units.length,
    entryCount: entries.length,
    hits,
    truncated: hits.length >= HIT_LIMIT,
    limit: HIT_LIMIT,
    words: repeatedWords(units),
    insideUnit: repeatsInsideUnit(units),
    sentences: repeatedSentences(units),
  };
}
