import fs from 'node:fs';
import path from 'node:path';
import { config } from './config';

export interface RepoCourseSource {
  courseId: string;
  version: string;
}

/**
 * Courses that already have authoring tables in `content/<course>/source/<version>/course.mjs`.
 *
 * The import screen used to name `vi_en` in the markup, which meant a second authored course could
 * never be brought in without a code change. Reading the folder is the same information the builder
 * uses, so the list cannot disagree with what `read-authored.mjs` can actually parse.
 */
export function repoCourseSources(): RepoCourseSource[] {
  const contentDir = path.join(config().repoRoot, 'content');
  let courseIds: string[];
  try {
    courseIds = fs.readdirSync(contentDir);
  } catch {
    return [];
  }
  const found: RepoCourseSource[] = [];
  for (const courseId of courseIds.sort()) {
    const sourceDir = path.join(contentDir, courseId, 'source');
    if (!fs.existsSync(sourceDir)) continue;
    for (const version of fs.readdirSync(sourceDir).sort()) {
      if (fs.existsSync(path.join(sourceDir, version, 'course.mjs')))
        found.push({ courseId, version });
    }
  }
  return found;
}
