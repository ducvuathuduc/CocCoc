// P4-LEARN-001: course list, manifest, bundle and maintainer publishing (FR-COURSE-001,
// FR-CONTENT-001, FR-ADMIN-001). Publishing validates every file before the pointer flips; the
// version row and the course pointer commit atomically with the receipt.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BundleIndex, CourseManifest, LessonBundle } from '../content/types.js';
import { validateCourse, validateBundle } from '../content/validate.js';
import { ids } from '../persistence/ids.js';
import { bumped, created, decodeCursor, encodeCursor, iso, type LearningDeps } from './deps.js';

export async function listCourses(deps: LearningDeps, cursor: string | undefined, limit: number) {
  const offset = decodeCursor(cursor);
  if (offset < 0) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
  const page = await deps.persistence.list('l_courses', {
    equal: { status: 'PUBLISHED' },
    orderAsc: 'courseId',
    limit,
    offset,
  });
  return {
    items: page.items.map(({ row }) => ({
      courseId: String(row['courseId']),
      title: String(row['title']),
      sourceLocale: String(row['sourceLocale']),
      targetLocale: String(row['targetLocale']),
      publishedVersion: String(row['publishedVersion']),
      available: row['status'] === 'PUBLISHED',
    })),
    nextCursor:
      offset + page.items.length < page.total ? encodeCursor(offset + page.items.length) : null,
    asOf: iso(deps.nowMs()),
  };
}

export async function getManifest(
  deps: LearningDeps,
  courseId: string,
  version: string | undefined,
): Promise<CourseManifest> {
  if (version) {
    await deps.content.published(courseId); // course must exist and be published
    return deps.content.manifestVersion(courseId, version);
  }
  return (await deps.content.published(courseId)).manifest;
}

export async function getBundle(
  deps: LearningDeps,
  lessonId: string,
  version: string | undefined,
): Promise<LessonBundle> {
  const courses = await deps.persistence.list('l_courses', {
    equal: { status: 'PUBLISHED' },
    limit: 100,
  });
  for (const { row } of courses.items) {
    const courseId = String(row['courseId']);
    const manifest = version
      ? await deps.content.manifestVersion(courseId, version).catch(() => null)
      : (await deps.content.published(courseId)).manifest;
    if (!manifest) continue;
    if ([...manifest.bundles, manifest.placementBundle].some((b) => b.lessonId === lessonId)) {
      return (await deps.content.bundle(manifest, lessonId)).bundle;
    }
  }
  throw new ServiceError('NOT_FOUND', { details: { lessonId } });
}

export interface PublishBody {
  courseId: string;
  versionId: string;
  manifestFileId: string;
  manifestSha256: string;
  expectedPublishedVersion: string | null;
}

/** Validate the whole version from storage; returns the verified manifest and bundles. */
export async function verifyPublication(deps: LearningDeps, body: PublishBody) {
  const text = await deps.content.files.read(body.manifestFileId);
  if (text === null)
    throw new ServiceError('NOT_FOUND', { details: { manifestFileId: body.manifestFileId } });
  let manifest: CourseManifest;
  try {
    manifest = deps.content.parseVerifiedManifest(text, body.manifestSha256);
  } catch {
    throw new ServiceError('VALIDATION_ERROR', {
      details: { field: 'manifest', reason: 'HASH_OR_SIGNATURE' },
    });
  }
  if (manifest.courseId !== body.courseId || manifest.courseVersion !== body.versionId) {
    throw new ServiceError('VALIDATION_ERROR', {
      details: { field: 'manifest', reason: 'PIN_MISMATCH' },
    });
  }
  const bundles: LessonBundle[] = [];
  const problems: { where: string; problem: string }[] = [];
  const load = async (index: BundleIndex) => {
    const bundleText = await deps.content.files.read(index.fileId);
    if (bundleText === null) {
      problems.push({ where: index.lessonId, problem: 'BUNDLE_FILE_MISSING' });
      return null;
    }
    try {
      return deps.content.parseVerifiedBundle(bundleText, index);
    } catch {
      problems.push({ where: index.lessonId, problem: 'BUNDLE_HASH_OR_SIGNATURE' });
      return null;
    }
  };
  for (const index of manifest.bundles) {
    const bundle = await load(index);
    if (bundle) bundles.push(bundle);
  }
  const placement = await load(manifest.placementBundle);
  if (placement) problems.push(...validateBundle(placement, 'placement'));
  problems.push(...validateCourse(manifest, bundles));
  if (problems.length) {
    const unknownType = problems.some((p) => p.problem === 'UNKNOWN_EXERCISE_TYPE');
    throw new ServiceError(unknownType ? 'UNKNOWN_EXERCISE_TYPE' : 'VALIDATION_ERROR', {
      details: { problems: problems.slice(0, 20), problemCount: problems.length },
    });
  }
  return { manifest, bundles };
}

export async function publishContent(
  deps: LearningDeps,
  userId: string,
  body: PublishBody,
  key: string,
  bodyHash: string,
  requestId: string,
  options: { system?: boolean } = {},
) {
  if (!options.system && !deps.maintainers.has(userId))
    throw new ServiceError('MAINTAINER_REQUIRED');
  const { manifest } = await verifyPublication(deps, body);
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'publishContent', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const courseRowId = ids.course(body.courseId);
      const course = await tx.get('l_courses', courseRowId);
      const current = course ? String(course['publishedVersion']) : null;
      if (current !== body.expectedPublishedVersion) {
        throw new ServiceError('REVISION_CONFLICT', { details: { publishedVersion: current } });
      }
      const versionRowId = ids.contentVersion(body.courseId, body.versionId);
      if (await tx.get('l_content_versions', versionRowId)) {
        throw new ServiceError('REVISION_CONFLICT', {
          details: { reason: 'VERSION_EXISTS', versionId: body.versionId },
        });
      }
      tx.put('l_content_versions', versionRowId, {
        courseId: body.courseId,
        versionId: body.versionId,
        manifestFileId: body.manifestFileId,
        manifestSha256: body.manifestSha256,
        schemaVersion: manifest.schemaVersion,
        publishedAt: iso(now),
        retiredAt: null,
        rewardMappingJson: '{}',
        ...created(now),
      });
      tx.put('l_courses', courseRowId, {
        courseId: body.courseId,
        sourceLocale: manifest.sourceLocale,
        targetLocale: manifest.targetLocale,
        title: manifest.title,
        publishedVersion: body.versionId,
        status: 'PUBLISHED',
        manifestFileId: body.manifestFileId,
        ...(course ? { createdAt: course['createdAt'], ...bumped(course, now) } : created(now)),
      });
      return { statusCode: 200, response: { operationId: key, status: 'accepted', requestId } };
    },
  );
}
