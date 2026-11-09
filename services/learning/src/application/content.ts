// P4-LEARN-001: course list, manifest, bundle and maintainer publishing (FR-COURSE-001,
// FR-CONTENT-001, FR-ADMIN-001). Publishing validates every file before the pointer flips; the
// version row and the course pointer commit atomically with the receipt.
import { ServiceError } from '../../../shared/src/errors.js';
import type { MediaEvidence } from '../content/media.js';
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

/**
 * The course-scoped lesson read: the only way to name a lesson unambiguously.
 *
 * Every course numbers its nodes `u<n>n<m>l<k>`, so `u1n1l1` exists in every course that has a unit.
 * Resolving inside one manifest is therefore exact, and `version` pins the read to an immutable
 * version instead of whatever the course pointer says now.
 */
export async function getCourseBundle(
  deps: LearningDeps,
  courseId: string,
  lessonId: string,
  version: string | undefined,
): Promise<LessonBundle> {
  const manifest = await getManifest(deps, courseId, version);
  const listed = [...manifest.bundles, manifest.placementBundle].some(
    (b) => b.lessonId === lessonId,
  );
  if (!listed) throw new ServiceError('NOT_FOUND', { details: { courseId, lessonId } });
  return (await deps.content.bundle(manifest, lessonId)).bundle;
}

/**
 * Legacy read without a course. `lessonId` is only unique inside a course, so this can only answer
 * when exactly one published course has it: guessing would hand the app another course's lesson.
 * Ambiguity is reported as `LESSON_AMBIGUOUS` (409) with the candidate course ids, never resolved.
 */
export async function getBundle(
  deps: LearningDeps,
  lessonId: string,
  version: string | undefined,
): Promise<LessonBundle> {
  const matches: { manifest: CourseManifest; courseId: string }[] = [];
  for (let offset = 0; ;) {
    const page = await deps.persistence.list('l_courses', {
      equal: { status: 'PUBLISHED' },
      orderAsc: 'courseId',
      limit: 100,
      offset,
    });
    for (const { row } of page.items) {
      const courseId = String(row['courseId']);
      const manifest = version
        ? await deps.content.manifestVersion(courseId, version).catch(() => null)
        : (await deps.content.published(courseId)).manifest;
      if (!manifest) continue;
      if ([...manifest.bundles, manifest.placementBundle].some((b) => b.lessonId === lessonId))
        matches.push({ manifest, courseId });
    }
    offset += page.items.length;
    if (!page.items.length || offset >= page.total) break;
  }
  if (matches.length === 1)
    return (await deps.content.bundle(matches[0]!.manifest, lessonId)).bundle;
  if (matches.length > 1)
    throw new ServiceError('LESSON_AMBIGUOUS', {
      details: { lessonId, courseIds: matches.map((m) => m.courseId) },
    });
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
  const problems: { where: string; problem: string }[] = [];
  // Bounded parallel reads; results stay in manifest order so the reported problems are stable.
  const loaded = await mapLimit(
    [...manifest.bundles, manifest.placementBundle],
    deps.content.media.policy.concurrency,
    async (index: BundleIndex) => {
      const bundleText = await deps.content.files.read(index.fileId);
      if (bundleText === null) {
        return { problem: { where: index.lessonId, problem: 'BUNDLE_FILE_MISSING' } };
      }
      try {
        return { bundle: deps.content.parseVerifiedBundle(bundleText, index) };
      } catch {
        return { problem: { where: index.lessonId, problem: 'BUNDLE_HASH_OR_SIGNATURE' } };
      }
    },
  );
  const bundles: LessonBundle[] = [];
  const placementResult = loaded[loaded.length - 1];
  for (const result of loaded.slice(0, -1)) {
    if (result.problem) problems.push(result.problem);
    else if (result.bundle) bundles.push(result.bundle);
  }
  if (placementResult?.problem) problems.push(placementResult.problem);
  const placement = placementResult?.bundle;
  if (placement) problems.push(...validateBundle(placement, 'placement'));
  problems.push(...validateCourse(manifest, bundles));
  if (problems.length) {
    const unknownType = problems.some((p) => p.problem === 'UNKNOWN_EXERCISE_TYPE');
    throw new ServiceError(unknownType ? 'UNKNOWN_EXERCISE_TYPE' : 'VALIDATION_ERROR', {
      details: { problems: problems.slice(0, 20), problemCount: problems.length },
    });
  }
  // Every declared media file must be in Storage, whole, public and hash-true before the pointer
  // flips (content/media.ts). Structure is checked first so a broken course costs no Storage calls.
  const media = await deps.content.media.verify(placement ? [...bundles, placement] : bundles);
  return { manifest, bundles, media };
}

/** Bounded-concurrency map that keeps result order. */
async function mapLimit<T, R>(
  items: readonly T[],
  limit: number,
  work: (item: T) => Promise<R>,
): Promise<R[]> {
  const out = new Array<R>(items.length);
  let next = 0;
  const worker = async () => {
    for (let index = next++; index < items.length; index = next++) {
      out[index] = await work(items[index] as T);
    }
  };
  await Promise.all(Array.from({ length: Math.min(Math.max(1, limit), items.length) }, worker));
  return out;
}

/**
 * Media audit of a stored version: loads each bundle (hash + signature verified, cached) and runs
 * the same Storage gate publishing uses. Read-only; used before a rollback re-points the course at
 * an older version and by the lifecycle CLI to audit the live version.
 */
export async function verifyVersionMedia(
  deps: LearningDeps,
  courseId: string,
  versionId: string,
): Promise<MediaEvidence> {
  const manifest = await deps.content.manifestVersion(courseId, versionId);
  const bundles = await mapLimit(
    [...manifest.bundles, manifest.placementBundle],
    deps.content.media.policy.concurrency,
    async (index) => (await deps.content.bundle(manifest, index.lessonId)).bundle,
  );
  return deps.content.media.verify(bundles);
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
  const { manifest, media } = await verifyPublication(deps, body);
  // Metadata-only recheck as close to the commit as possible: media deleted, hidden or replaced
  // while the bytes were being verified must not go live. A delete after this point is a storage
  // retention concern (see docs/agent/RELEASE_BLOCKER_REMEDIATION_REPORT.md), not a gate failure.
  await deps.content.media.confirm(media);
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

/**
 * Publishing lifecycle (Phase 3). A content version's state is derived, not stored:
 *   LIVE     — versionId === l_courses.publishedVersion AND l_courses.status === PUBLISHED
 *   RETIRED  — l_content_versions.retiredAt is set (permanent; can never go live again)
 *   SUPERSEDED — exists, not retired, not live (older history, or a newer version is live)
 * Taking the course offline leaves history intact: `l_courses.status` becomes DRAFT and the live
 * pointer is cleared, so Mobile's `listCourses` (which filters PUBLISHED) stops serving it, and an
 * in-progress learner keeps the in-memory bundle they already fetched while new fetches degrade to
 * the local fixture. No row is ever deleted.
 */

export type VersionStatus = 'LIVE' | 'SUPERSEDED' | 'RETIRED';

/** Publish history for a course with derived per-version status. Read-only; maintainers only. */
export async function listContentVersions(
  deps: LearningDeps,
  userId: string,
  courseId: string,
): Promise<{
  items: {
    courseId: string;
    versionId: string;
    status: VersionStatus;
    manifestSha256: string;
    publishedAt: string;
    retiredAt: string | null;
  }[];
  asOf: string;
}> {
  if (!deps.maintainers.has(userId)) throw new ServiceError('MAINTAINER_REQUIRED');
  const course = await deps.persistence.read('l_courses', ids.course(courseId));
  const publishedVersion =
    course && course['publishedVersion'] ? String(course['publishedVersion']) : null;
  const live = Boolean(course && course['status'] === 'PUBLISHED' && publishedVersion);
  const page = await deps.persistence.list('l_content_versions', {
    equal: { courseId },
    orderDesc: 'publishedAt',
    limit: 100,
  });
  const items = page.items.map(({ row }) => {
    const versionId = String(row['versionId']);
    const retired = row['retiredAt'] != null;
    const status: VersionStatus = retired
      ? 'RETIRED'
      : live && versionId === publishedVersion
        ? 'LIVE'
        : 'SUPERSEDED';
    return {
      courseId,
      versionId,
      status,
      manifestSha256: String(row['manifestSha256']),
      publishedAt: String(row['publishedAt']),
      retiredAt: row['retiredAt'] != null ? String(row['retiredAt']) : null,
    };
  });
  return { items, asOf: iso(deps.nowMs()) };
}

/** Take a course offline without deleting anything: PUBLISHED -> DRAFT, live pointer cleared. */
export async function unpublishCourse(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  expectedPublishedVersion: string | null,
  key: string,
  bodyHash: string,
  options: { system?: boolean } = {},
) {
  if (!options.system && !deps.maintainers.has(userId))
    throw new ServiceError('MAINTAINER_REQUIRED');
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'unpublishCourse', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const courseRowId = ids.course(courseId);
      const course = await tx.get('l_courses', courseRowId);
      if (!course) throw new ServiceError('NOT_FOUND', { details: { courseId } });
      const current = course['publishedVersion'] ? String(course['publishedVersion']) : null;
      if (expectedPublishedVersion !== current)
        throw new ServiceError('REVISION_CONFLICT', { details: { publishedVersion: current } });
      if (course['status'] === 'PUBLISHED') {
        tx.put('l_courses', courseRowId, {
          ...course,
          status: 'DRAFT',
          publishedVersion: null,
          ...bumped(course, now),
        });
      }
      return {
        statusCode: 200,
        response: { status: 'unpublished', courseId, publishedVersion: null },
      };
    },
  );
}

/**
 * Permanently flag a version as retired. If it was the live version, the course is also taken
 * offline (DRAFT) so Mobile stops serving it. A retired version can never become live again
 * (rollback refuses it). The row is never deleted — history is preserved.
 */
export async function retireVersion(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  versionId: string,
  expectedPublishedVersion: string | null,
  key: string,
  bodyHash: string,
  options: { system?: boolean } = {},
) {
  if (!options.system && !deps.maintainers.has(userId))
    throw new ServiceError('MAINTAINER_REQUIRED');
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'retireVersion', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const versionRowId = ids.contentVersion(courseId, versionId);
      const version = await tx.get('l_content_versions', versionRowId);
      if (!version) throw new ServiceError('NOT_FOUND', { details: { courseId, versionId } });
      if (version['retiredAt']) {
        return {
          statusCode: 200,
          response: { status: 'retired', courseId, versionId, alreadyRetired: true },
        };
      }
      const courseRowId = ids.course(courseId);
      const course = await tx.get('l_courses', courseRowId);
      if (!course) throw new ServiceError('NOT_FOUND', { details: { courseId } });
      const current = course['publishedVersion'] ? String(course['publishedVersion']) : null;
      if (expectedPublishedVersion !== current)
        throw new ServiceError('REVISION_CONFLICT', { details: { publishedVersion: current } });
      const wasLive = Boolean(course && course['status'] === 'PUBLISHED' && current === versionId);
      tx.put('l_content_versions', versionRowId, {
        ...version,
        retiredAt: iso(now),
        ...bumped(version, now),
      });
      if (wasLive) {
        tx.put('l_courses', courseRowId, {
          ...course,
          status: 'DRAFT',
          publishedVersion: null,
          ...bumped(course, now),
        });
      }
      return {
        statusCode: 200,
        response: { status: 'retired', courseId, versionId, unpublishedCourse: wasLive },
      };
    },
  );
}

/**
 * Re-point the course at a previous version. The target must still read and verify (sha256 +
 * Ed25519) and must not be retired; otherwise the rollback is refused. The previously-live version
 * is left untouched (it becomes SUPERSEDED by derivation) — newer versions are never lost. The
 * whole pointer move commits atomically with the receipt, and `expectedPublishedVersion` provides
 * optimistic concurrency so two admins cannot roll back past each other.
 */
export async function rollbackCourse(
  deps: LearningDeps,
  userId: string,
  courseId: string,
  targetVersionId: string,
  expectedPublishedVersion: string | null,
  key: string,
  bodyHash: string,
  options: { system?: boolean } = {},
) {
  if (!options.system && !deps.maintainers.has(userId))
    throw new ServiceError('MAINTAINER_REQUIRED');
  // Storage I/O must not run inside the commit effect (it can be retried), so the target version's
  // media is audited first: a rollback onto a version whose media was deleted or replaced since it
  // was published would serve Mobile broken lessons.
  await deps.content.media.confirm(await verifyVersionMedia(deps, courseId, targetVersionId));
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'rollbackCourse', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const courseRowId = ids.course(courseId);
      const course = await tx.get('l_courses', courseRowId);
      if (!course) throw new ServiceError('NOT_FOUND', { details: { courseId } });
      const current = course['publishedVersion'] ? String(course['publishedVersion']) : null;
      if (expectedPublishedVersion !== current)
        throw new ServiceError('REVISION_CONFLICT', { details: { publishedVersion: current } });
      // Integrity: the target must still resolve, verify and not be retired. `manifestVersion`
      // throws NOT_FOUND (missing), CONTENT_VERSION_RETIRED (retired), or STORAGE_UNAVAILABLE
      // (manifest file missing) — any of these refuses the rollback safely.
      await deps.content.manifestVersion(courseId, targetVersionId);
      tx.put('l_courses', courseRowId, {
        ...course,
        status: 'PUBLISHED',
        publishedVersion: targetVersionId,
        ...bumped(course, now),
      });
      return {
        statusCode: 200,
        response: {
          status: 'rolled-back',
          courseId,
          publishedVersion: targetVersionId,
          previousVersion: current,
        },
      };
    },
  );
}
