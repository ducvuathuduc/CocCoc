// Hosted ContentFileStore: published files live in the `learning-assets` Storage bucket
// (appwrite/schema/foundation.json buckets). Integrity is verified by the repository, not here.
import { Client, Storage } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import type { ContentFileStore } from './repository.js';

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
        const data = await storage.getFileDownload({ bucketId, fileId });
        return Buffer.from(data).toString('utf8');
      } catch (error) {
        if ((error as { code?: number } | null)?.code === 404) return null;
        throw new ServiceError('STORAGE_UNAVAILABLE');
      }
    },
  };
}
