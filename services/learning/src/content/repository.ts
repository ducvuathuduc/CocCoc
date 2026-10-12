// Published content access. The l_courses pointer names the published version; l_content_versions
// pins the manifest file and its sha256. Files come from a ContentFileStore (Appwrite Storage when
// hosted, a local directory in dev/tests). Every file is verified (sha256 + Ed25519 signature)
// before use and cached per immutable version.
import { ServiceError } from '../../../shared/src/errors.js';
import { ids } from '../persistence/ids.js';
import type { LearningPersistence, Row } from '../persistence/port.js';
import { sha256, verifyBundle, verifyManifest, type ContentKeyring } from './integrity.js';
import type { BundleIndex, CourseManifest, LessonBundle } from './types.js';

export interface ContentFileStore {
  /** Raw file text, or null when the file does not exist. */
  read(fileId: string): Promise<string | null>;
}

export interface PublishedCourse {
  course: Row;
  manifest: CourseManifest;
}

export interface ContentRepository {
  keyring: ContentKeyring;
  files: ContentFileStore;
  published(courseId: string): Promise<PublishedCourse>;
  manifestVersion(courseId: string, versionId: string): Promise<CourseManifest>;
  bundle(
    manifest: CourseManifest,
    lessonId: string,
  ): Promise<{ bundle: LessonBundle; index: BundleIndex }>;
  /** Locate the immutable bundle a session was pinned to (survives later publishes). */
  bundleByLessonVersion(
    courseId: string,
    lessonId: string,
    lessonVersion: string,
  ): Promise<LessonBundle>;
  parseVerifiedManifest(text: string, expectedSha256: string): CourseManifest;
  parseVerifiedBundle(text: string, index: BundleIndex): LessonBundle;
}

export function createContentRepository(options: {
  persistence: LearningPersistence;
  files: ContentFileStore;
  keyring: ContentKeyring;
}): ContentRepository {
  const { persistence, files, keyring } = options;
  const manifests = new Map<string, CourseManifest>();
  const bundles = new Map<string, LessonBundle>();

  function corrupt(reason: string, details: Record<string, unknown> = {}): never {
    throw new ServiceError('STORAGE_UNAVAILABLE', { details: { reason, ...details } });
  }

  const repo: ContentRepository = {
    keyring,
    files,
    parseVerifiedManifest(text, expectedSha256) {
      if (sha256(text) !== expectedSha256) corrupt('MANIFEST_HASH_MISMATCH');
      const manifest = JSON.parse(text) as CourseManifest;
      if (!verifyManifest(keyring, manifest)) corrupt('MANIFEST_SIGNATURE_INVALID');
      return manifest;
    },
    parseVerifiedBundle(text, index) {
      if (sha256(text) !== index.sha256)
        corrupt('BUNDLE_HASH_MISMATCH', { lessonId: index.lessonId });
      const bundle = JSON.parse(text) as LessonBundle;
      if (!verifyBundle(keyring, bundle) || bundle.lessonVersion !== index.lessonVersion) {
        corrupt('BUNDLE_SIGNATURE_INVALID', { lessonId: index.lessonId });
      }
      return bundle;
    },
    async manifestVersion(courseId, versionId) {
      const cacheKey = `${courseId}\u0000${versionId}`;
      const cached = manifests.get(cacheKey);
      if (cached) return cached;
      const version = await persistence.read(
        'l_content_versions',
        ids.contentVersion(courseId, versionId),
      );
      if (!version)
        throw new ServiceError('NOT_FOUND', { details: { courseId, version: versionId } });
      if (version['retiredAt'])
        throw new ServiceError('CONTENT_VERSION_RETIRED', {
          details: { courseId, version: versionId },
        });
      const text = await files.read(String(version['manifestFileId']));
      if (text === null) corrupt('MANIFEST_FILE_MISSING');
      const manifest = repo.parseVerifiedManifest(text, String(version['manifestSha256']));
      if (manifest.courseId !== courseId || manifest.courseVersion !== versionId)
        corrupt('MANIFEST_PIN_MISMATCH');
      manifests.set(cacheKey, manifest);
      return manifest;
    },
    async published(courseId) {
      const course = await persistence.read('l_courses', ids.course(courseId));
      if (!course || course['status'] !== 'PUBLISHED')
        throw new ServiceError('NOT_FOUND', { details: { courseId } });
      return {
        course,
        manifest: await repo.manifestVersion(courseId, String(course['publishedVersion'])),
      };
    },
    async bundle(manifest, lessonId) {
      const index =
        manifest.bundles.find((b) => b.lessonId === lessonId) ??
        (manifest.placementBundle.lessonId === lessonId ? manifest.placementBundle : undefined);
      if (!index) throw new ServiceError('NOT_FOUND', { details: { lessonId } });
      const cached = bundles.get(index.sha256);
      if (cached) return { bundle: cached, index };
      const text = await files.read(index.fileId);
      if (text === null) corrupt('BUNDLE_FILE_MISSING', { lessonId });
      const bundle = repo.parseVerifiedBundle(text, index);
      bundles.set(index.sha256, bundle);
      return { bundle, index };
    },
    async bundleByLessonVersion(courseId, lessonId, lessonVersion) {
      const { manifest } = await repo.published(courseId);
      const pinned = (m: CourseManifest) =>
        [...m.bundles, m.placementBundle].some(
          (b) => b.lessonId === lessonId && b.lessonVersion === lessonVersion,
        );
      if (pinned(manifest)) return (await repo.bundle(manifest, lessonId)).bundle;
      const versions = await persistence.list('l_content_versions', {
        equal: { courseId },
        orderDesc: 'publishedAt',
        limit: 20,
      });
      for (const { row } of versions.items) {
        const older = await repo.manifestVersion(courseId, String(row['versionId']));
        if (pinned(older)) return (await repo.bundle(older, lessonId)).bundle;
      }
      throw new ServiceError('CONTENT_VERSION_RETIRED', { details: { lessonVersion } });
    },
  };
  return repo;
}
