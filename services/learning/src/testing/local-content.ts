// LOCAL DEV / TEST ONLY: read committed course versions from content/<course>/dist/<version>/
// (publish.json maps Storage file IDs to paths). Seeding goes through the real publish use case.
import fs from 'node:fs';
import path from 'node:path';
import type { ContentFileStore } from '../content/repository.js';

export interface LocalPublication {
  courseId: string;
  versionId: string;
  manifestFileId: string;
  manifestSha256: string;
}

export function loadLocalContent(root = process.cwd()): {
  files: ContentFileStore;
  publications: LocalPublication[];
} {
  const texts = new Map<string, string>();
  const publications: LocalPublication[] = [];
  const contentDir = path.join(root, 'content');
  for (const course of fs.existsSync(contentDir) ? fs.readdirSync(contentDir) : []) {
    const dist = path.join(contentDir, course, 'dist');
    if (!fs.existsSync(dist)) continue;
    for (const version of fs.readdirSync(dist).sort()) {
      const dir = path.join(dist, version);
      const publish = JSON.parse(
        fs.readFileSync(path.join(dir, 'publish.json'), 'utf8'),
      ) as LocalPublication & {
        files: { fileId: string; path: string }[];
      };
      for (const file of publish.files)
        texts.set(file.fileId, fs.readFileSync(path.join(dir, file.path), 'utf8'));
      publications.push({
        courseId: publish.courseId,
        versionId: publish.versionId,
        manifestFileId: publish.manifestFileId,
        manifestSha256: publish.manifestSha256,
      });
    }
  }
  return {
    files: { read: async (fileId) => texts.get(fileId) ?? null },
    publications,
  };
}
