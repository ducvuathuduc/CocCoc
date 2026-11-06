import { config } from '../config';
import { FileStore } from './file-store';
import { AppwriteStore } from './appwrite-store';
import type { CmsStore } from './port';

let store: CmsStore | undefined;

export function getStore(): CmsStore {
  if (store) return store;
  const c = config();
  store =
    c.mode === 'appwrite'
      ? new AppwriteStore(c.endpoint, c.projectId, c.apiKey, c.databaseId)
      : new FileStore(c.dataDir);
  return store;
}
