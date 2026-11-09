// LOCAL DEV / TEST ONLY: read committed course versions from content/<course>/dist/<version>/
// (publish.json maps Storage file IDs to paths). Seeding goes through the real publish use case.
import fs from 'node:fs';
import path from 'node:path';
import type { MediaStat, MediaStore } from '../content/media.js';
import type { ContentFileStore } from '../content/repository.js';

export interface LocalPublication {
  courseId: string;
  versionId: string;
  manifestFileId: string;
  manifestSha256: string;
}

const MEDIA_EXTENSIONS = new Set(['.aac', '.wav', '.webp', '.png']);

/**
 * Committed media (content/<course>/media/{audio,images}/<fileId>.<ext>) as a MediaStore, so local
 * dev and tests run the same publish gate Storage does. Files here are always "complete" and
 * "public"; the object version is the size and mtime.
 */
export function localMediaStore(root: string): MediaStore {
  let index: Map<string, string> | undefined;
  const files = (): Map<string, string> => {
    if (index) return index;
    index = new Map();
    const contentDir = path.join(root, 'content');
    for (const course of fs.existsSync(contentDir) ? fs.readdirSync(contentDir) : []) {
      for (const kind of ['audio', 'images']) {
        const dir = path.join(contentDir, course, 'media', kind);
        if (!fs.existsSync(dir)) continue;
        for (const name of fs.readdirSync(dir)) {
          const ext = path.extname(name);
          if (MEDIA_EXTENSIONS.has(ext))
            index.set(name.slice(0, -ext.length), path.join(dir, name));
        }
      }
    }
    return index;
  };
  return {
    async stat(fileIds) {
      const out = new Map<string, MediaStat>();
      for (const fileId of fileIds) {
        const file = files().get(fileId);
        if (!file) continue;
        const info = fs.statSync(file);
        out.set(fileId, {
          bytes: info.size,
          version: `${info.size}:${info.mtimeMs}`,
          complete: true,
          publicRead: true,
        });
      }
      return out;
    },
    async readBytes(fileId) {
      const file = files().get(fileId);
      return file ? new Uint8Array(fs.readFileSync(file)) : null;
    },
  };
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
    files: { read: async (fileId) => texts.get(fileId) ?? null, ...localMediaStore(root) },
    publications,
  };
}
