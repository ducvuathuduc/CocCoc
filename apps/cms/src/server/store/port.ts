import type {
  AuditEntry,
  BuildRun,
  CourseDraft,
  CourseRecord,
  UnitDraft,
  UnitRecord,
} from '@/cms/types';

export class ConflictError extends Error {
  constructor(message = 'Bản ghi vừa được người khác sửa. Tải lại để lấy bản mới nhất.') {
    super(message);
    this.name = 'ConflictError';
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}

/**
 * The store answered with a connection-level failure after its own retries. Actions turn this into a
 * normal `{ ok: false }` reply so the admin sees one actionable sentence instead of a stack trace.
 */
export class StoreUnavailableError extends Error {
  constructor(
    message = 'Không gọi được Appwrite sau vài lần thử (mạng chập chờn). Nội dung vẫn chưa lưu — bấm lưu lại lần nữa.',
    cause?: unknown,
  ) {
    super(message, { cause });
    this.name = 'StoreUnavailableError';
  }
}

export interface SaveUnitInput {
  courseId: string;
  unitId: string;
  order: number;
  draft: UnitDraft;
  actorId: string;
  expectedRevision: number;
}

export interface SaveCourseInput {
  courseId: string;
  draft: CourseDraft;
  actorId: string;
  expectedRevision: number;
}

/** The columns a navigation list needs — never the draft payload, which is the heavy part of a unit row. */
export interface UnitIndexEntry {
  unitId: string;
  order: number;
  title: string;
  theme: string;
}

export interface CmsStore {
  readonly mode: 'appwrite' | 'file';
  listCourses(): Promise<CourseRecord[]>;
  getCourse(courseId: string): Promise<CourseRecord | null>;
  saveCourse(input: SaveCourseInput): Promise<CourseRecord>;
  listUnits(courseId: string): Promise<UnitRecord[]>;
  listUnitIndex(courseId: string): Promise<UnitIndexEntry[]>;
  getUnit(courseId: string, unitId: string): Promise<UnitRecord | null>;
  saveUnit(input: SaveUnitInput): Promise<UnitRecord>;
  deleteUnit(courseId: string, unitId: string, actorId: string): Promise<void>;
  listBuildRuns(courseId: string): Promise<BuildRun[]>;
  saveBuildRun(run: BuildRun): Promise<BuildRun>;
  appendAudit(entry: AuditEntry): Promise<void>;
  listAudit(limit: number): Promise<AuditEntry[]>;
}
