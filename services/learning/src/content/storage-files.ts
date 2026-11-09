// Hosted ContentFileStore: published files live in the `learning-assets` Storage bucket
// (appwrite/schema/foundation.json buckets). Integrity is verified by the repository, not here.
import { Client, Query, Storage } from 'node-appwrite';
import type { Models } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import { MEDIA_REASONS, type MediaStat } from './media.js';
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

const httpCode = (error: unknown): number | undefined => {
  const code = (error as { code?: unknown } | null)?.code;
  return typeof code === 'number' ? code : undefined;
};

/** A Storage failure while checking media, with a reason the publish gate reports and acts on. */
function mediaError(error: unknown): ServiceError {
  if (error instanceof ServiceError) return error;
  const code = httpCode(error);
  const reason =
    code === 401 || code === 403 ? MEDIA_REASONS.permissionDenied : MEDIA_REASONS.unavailable;
  return new ServiceError('STORAGE_UNAVAILABLE', {
    details: { reason, ...(code !== undefined ? { status: code } : {}) },
  });
}

/** Appwrite spells the public grant `read("any")`; any narrower role is not readable by Mobile. */
const PUBLIC_READ = /^read\("any"\)$/;

function toStat(file: Models.File): MediaStat {
  return {
    bytes: file.sizeOriginal,
    // The MD5 and update time change whenever the stored object is replaced.
    version: `${file.signature}:${file.$updatedAt}:${file.sizeOriginal}`,
    complete: file.chunksUploaded >= file.chunksTotal,
    publicRead: file.$permissions.some((p) => PUBLIC_READ.test(p)),
  };
}

function toBytes(data: unknown): Uint8Array {
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (ArrayBuffer.isView(data))
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  throw new ServiceError('STORAGE_UNAVAILABLE', {
    details: { reason: MEDIA_REASONS.unavailable },
  });
}

export function createStorageContentFiles(
  config: { endpoint: string; projectId: string; apiKey: string; bucketId?: string },
  storage: Storage = new Storage(
    new Client().setEndpoint(config.endpoint).setProject(config.projectId).setKey(config.apiKey),
  ),
): ContentFileStore {
  const bucketId = config.bucketId ?? 'learning-assets';

  /** Fallback when the server rejects the batched query: one metadata call per id, in order. */
  async function statEach(fileIds: readonly string[]): Promise<Map<string, MediaStat>> {
    const out = new Map<string, MediaStat>();
    for (const fileId of fileIds) {
      try {
        out.set(fileId, toStat(await storage.getFile({ bucketId, fileId })));
      } catch (error) {
        if (httpCode(error) !== 404) throw mediaError(error);
      }
    }
    return out;
  }

  return {
    async read(fileId) {
      try {
        return downloadText(await storage.getFileDownload({ bucketId, fileId }));
      } catch (error) {
        if ((error as { code?: number } | null)?.code === 404) return null;
        throw new ServiceError('STORAGE_UNAVAILABLE');
      }
    },

    async stat(fileIds) {
      if (!fileIds.length) return new Map();
      try {
        const list = await storage.listFiles({
          bucketId,
          queries: [Query.equal('$id', [...fileIds]), Query.limit(fileIds.length)],
          total: false,
        });
        return new Map(list.files.map((file) => [file.$id, toStat(file)]));
      } catch (error) {
        if (httpCode(error) === 400) return statEach(fileIds);
        throw mediaError(error);
      }
    },

    async readBytes(fileId) {
      try {
        return toBytes(await storage.getFileDownload({ bucketId, fileId }));
      } catch (error) {
        if (httpCode(error) === 404) return null;
        throw mediaError(error);
      }
    },
  };
}
