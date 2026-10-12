// Hosted ContentFileStore: published files live in the `learning-assets` Storage bucket
// (appwrite/schema/foundation.json buckets). Integrity is verified by the repository, not here.
import { Client, Storage } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import type { ContentFileStore } from './repository.js';

/**
 * The SDK returns raw bytes for most files but a parsed object for files Storage serves as
 * application/json (published content is canonical JSON). Canonical JSON re-serializes to the same
 * bytes (no whitespace, stored key order); the repository's sha256 check rejects any difference.
 */
export function downloadText(data: unknown): string {
  if (typeof data === 'string') return data;
  if (data instanceof ArrayBuffer) return Buffer.from(data).toString('utf8');
  if (ArrayBuffer.isView(data)) {
    return Buffer.from(data.buffer, data.byteOffset, data.byteLength).toString('utf8');
  }
  if (data && typeof data === 'object') return JSON.stringify(data);
  throw new ServiceError('STORAGE_UNAVAILABLE');
}

export function createStorageContentFiles(
  config: { endpoint: string; projectId: string; apiKey: string; bucketId?: string },
  storage: Storage = new Storage(
    new Client().setEndpoint(config.endpoint).setProject(config.projectId).setKey(config.apiKey),
  ),
): ContentFileStore {
  const bucketId = config.bucketId ?? 'learning-assets';
  return {
    async read(fileId) {
      try {
        return downloadText(await storage.getFileDownload({ bucketId, fileId }));
      } catch (error) {
        if ((error as { code?: number } | null)?.code === 404) return null;
        throw new ServiceError('STORAGE_UNAVAILABLE');
      }
    },
  };
}
