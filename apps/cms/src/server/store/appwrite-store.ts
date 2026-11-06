import { Client, ID, Query, TablesDB } from 'node-appwrite';
import type { Models } from 'node-appwrite';
import type { AuditEntry, BuildRun, CourseRecord, UnitRecord } from '@/cms/types';
import {
  ConflictError,
  NotFoundError,
  type CmsStore,
  type SaveCourseInput,
  type SaveUnitInput,
} from './port';
import { statusOf, withTransientRetry } from './retry';

const TABLE = {
  courses: 'c_courses',
  units: 'c_units',
  runs: 'c_build_runs',
  audit: 'c_admin_audit',
} as const;

const iso = (value: string | undefined): string => {
  const ms = value ? Date.parse(value) : NaN;
  return Number.isNaN(ms) ? (value ?? '') : new Date(ms).toISOString();
};

interface CourseRow extends Models.Row {
  courseId: string;
  title: string;
  revision: number;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
  draftJson: string;
}

interface UnitRow extends Models.Row {
  courseId: string;
  unitId: string;
  unitKey: string;
  order: number;
  revision: number;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
  theme: string;
  title: string;
  cefr: string;
  vocabCount: number;
  sentenceCount: number;
  draftJson: string;
}

interface RunRow extends Models.Row {
  runId: string;
  courseId: string;
  versionId: string;
  kind: string;
  status: string;
  message: string;
  actorId: string;
  createdAt: string;
  revision: number;
  updatedAt: string;
  logJson: string;
}

interface AuditRow extends Models.Row {
  entryId: string;
  actorId: string;
  operation: string;
  targetId: string;
  beforeJson: string;
  afterJson: string;
  requestId: string;
  createdAt: string;
}

/**
 * Durable CMS store over Appwrite TablesDB. The CMS owns c_ tables only: published course versions
 * stay Learning's to commit, through POST /v1/admin/content-versions.
 * Optimistic concurrency: a save re-reads the row and aborts when the revision moved.
 */
export class AppwriteStore implements CmsStore {
  readonly mode = 'appwrite' as const;
  private readonly tables: TablesDB;
  private readonly databaseId: string;

  constructor(endpoint: string, projectId: string, apiKey: string, databaseId: string) {
    this.databaseId = databaseId;
    this.tables = new TablesDB(
      new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey),
    );
  }

  private async get<T extends Models.Row>(table: string, rowId: string): Promise<T | null> {
    try {
      return (await withTransientRetry(() => this.tables.getRow({ databaseId: this.databaseId, tableId: table, rowId }))) as T;
    } catch (error) {
      if (statusOf(error) === 404) return null;
      throw error;
    }
  }

  private async list<T extends Models.Row>(table: string, queries: string[]): Promise<T[]> {
    const result = await withTransientRetry(() =>
      this.tables.listRows<T>({
        databaseId: this.databaseId,
        tableId: table,
        queries,
      }),
    );
    return result.rows;
  }

  /**
   * Rows are created with generated IDs, so a business key (courseId, unitKey) is found through its
   * indexed column — getRow() would look up $id and miss, turning every save into a duplicate row.
   */
  private async findRow<T extends Models.Row>(
    table: string,
    column: string,
    value: string,
  ): Promise<T | null> {
    const rows = await this.list<T>(table, [Query.equal(column, [value]), Query.limit(1)]);
    return rows[0] ?? null;
  }

  private toCourse(row: CourseRow): CourseRecord {
    return {
      courseId: row.courseId,
      revision: Number(row.revision),
      updatedAt: iso(row.updatedAt),
      updatedBy: row.updatedBy,
      draft: JSON.parse(row.draftJson) as CourseRecord['draft'],
    };
  }

  private toUnit(row: UnitRow): UnitRecord {
    return {
      courseId: row.courseId,
      unitId: row.unitId,
      order: Number(row.order),
      revision: Number(row.revision),
      updatedAt: iso(row.updatedAt),
      updatedBy: row.updatedBy,
      draft: JSON.parse(row.draftJson) as UnitRecord['draft'],
    };
  }

  async listCourses(): Promise<CourseRecord[]> {
    const rows = await this.list<CourseRow>(TABLE.courses, [Query.orderAsc('courseId'), Query.limit(100)]);
    return rows.map((r) => this.toCourse(r));
  }

  async getCourse(courseId: string): Promise<CourseRecord | null> {
    const row = await this.findRow<CourseRow>(TABLE.courses, 'courseId', courseId);
    return row ? this.toCourse(row) : null;
  }

  async saveCourse(input: SaveCourseInput): Promise<CourseRecord> {
    const row = await this.findRow<CourseRow>(TABLE.courses, 'courseId', input.courseId);
    const revision = Number(row?.revision ?? 0);
    if (row && revision !== input.expectedRevision) throw new ConflictError();
    const now = new Date().toISOString();
    const record: CourseRecord = {
      courseId: input.courseId,
      revision: revision + 1,
      updatedAt: now,
      updatedBy: input.actorId,
      draft: input.draft,
    };
    const data = {
      courseId: record.courseId,
      title: record.draft.course.title,
      revision: record.revision,
      updatedBy: record.updatedBy,
      createdAt: row?.createdAt ?? now,
      updatedAt: record.updatedAt,
      draftJson: JSON.stringify(record.draft),
    };
    if (row) {
      await withTransientRetry(() =>
        this.tables.updateRow({
          databaseId: this.databaseId,
          tableId: TABLE.courses,
          rowId: row.$id,
          data,
        }),
      );
    } else {
      await withTransientRetry(() =>
        this.tables.createRow({
          databaseId: this.databaseId,
          tableId: TABLE.courses,
          rowId: ID.unique(),
          data,
        }),
      );
    }
    return record;
  }

  async listUnits(courseId: string): Promise<UnitRecord[]> {
    const rows = await this.list<UnitRow>(TABLE.units, [
      Query.equal('courseId', [courseId]),
      Query.orderAsc('order'),
      Query.limit(200),
    ]);
    return rows.map((r) => this.toUnit(r));
  }

  async getUnit(courseId: string, unitId: string): Promise<UnitRecord | null> {
    const row = await this.findRow<UnitRow>(TABLE.units, 'unitKey', `${courseId}__${unitId}`);
    return row ? this.toUnit(row) : null;
  }

  async saveUnit(input: SaveUnitInput): Promise<UnitRecord> {
    const key = `${input.courseId}__${input.unitId}`;
    const row = await this.findRow<UnitRow>(TABLE.units, 'unitKey', key);
    const revision = Number(row?.revision ?? 0);
    if (!row && input.expectedRevision !== 0)
      throw new NotFoundError(`Unit ${input.unitId} chưa tồn tại trong khóa ${input.courseId}.`);
    if (row && revision !== input.expectedRevision) throw new ConflictError();
    const now = new Date().toISOString();
    const record: UnitRecord = {
      courseId: input.courseId,
      unitId: input.unitId,
      order: input.order,
      revision: revision + 1,
      updatedAt: now,
      updatedBy: input.actorId,
      draft: input.draft,
    };
    const data = {
      courseId: record.courseId,
      unitId: record.unitId,
      unitKey: key,
      order: record.order,
      revision: record.revision,
      updatedBy: record.updatedBy,
      createdAt: row?.createdAt ?? now,
      updatedAt: record.updatedAt,
      theme: record.draft.theme,
      title: record.draft.title,
      cefr: record.draft.cefr,
      vocabCount: record.draft.vocab.length,
      sentenceCount: record.draft.sentences.length,
      draftJson: JSON.stringify(record.draft),
    };
    if (row) {
      await withTransientRetry(() =>
        this.tables.updateRow({ databaseId: this.databaseId, tableId: TABLE.units, rowId: row.$id, data }),
      );
    } else {
      await withTransientRetry(() =>
        this.tables.createRow({
          databaseId: this.databaseId,
          tableId: TABLE.units,
          rowId: ID.unique(),
          data,
        }),
      );
    }
    return record;
  }

  async deleteUnit(courseId: string, unitId: string): Promise<void> {
    const row = await this.findRow<UnitRow>(TABLE.units, 'unitKey', `${courseId}__${unitId}`);
    if (!row) return;
    await withTransientRetry(() =>
      this.tables.deleteRow({ databaseId: this.databaseId, tableId: TABLE.units, rowId: row.$id }),
    );
  }

  async listBuildRuns(courseId: string): Promise<BuildRun[]> {
    const rows = await this.list<RunRow>(TABLE.runs, [
      Query.equal('courseId', [courseId]),
      Query.orderDesc('createdAt'),
      Query.limit(50),
    ]);
    return rows.map((r) => ({
      runId: r.runId,
      courseId: r.courseId,
      versionId: r.versionId,
      kind: r.kind as BuildRun['kind'],
      status: r.status as BuildRun['status'],
      message: r.message,
      log: JSON.parse(String(r.logJson ?? '[]')) as string[],
      actorId: r.actorId,
      createdAt: iso(r.createdAt),
    }));
  }

  async saveBuildRun(run: BuildRun): Promise<BuildRun> {
    const existing = await this.get<RunRow>(TABLE.runs, run.runId);
    const now = new Date().toISOString();
    const data = {
      runId: run.runId,
      courseId: run.courseId,
      versionId: run.versionId,
      kind: run.kind,
      status: run.status,
      message: run.message,
      actorId: run.actorId,
      createdAt: existing?.createdAt ?? run.createdAt,
      updatedAt: now,
      revision: Number(existing?.revision ?? 0) + 1,
      logJson: JSON.stringify(run.log),
    };
    if (existing) {
      await withTransientRetry(() =>
        this.tables.updateRow({
          databaseId: this.databaseId,
          tableId: TABLE.runs,
          rowId: run.runId,
          data,
        }),
      );
    } else {
      await withTransientRetry(() =>
        this.tables.createRow({
          databaseId: this.databaseId,
          tableId: TABLE.runs,
          rowId: run.runId,
          data,
        }),
      );
    }
    return run;
  }

  async appendAudit(entry: AuditEntry): Promise<void> {
    await withTransientRetry(() =>
      this.tables.createRow({
        databaseId: this.databaseId,
        tableId: TABLE.audit,
        rowId: entry.entryId,
        data: {
          entryId: entry.entryId,
          actorId: entry.actorId,
          operation: entry.operation,
          targetId: entry.targetId,
          beforeJson: entry.beforeJson.slice(0, 20000),
          afterJson: entry.afterJson.slice(0, 20000),
          requestId: entry.requestId,
          createdAt: entry.createdAt,
        },
      }),
    );
  }

  async listAudit(limit: number): Promise<AuditEntry[]> {
    const rows = await this.list<AuditRow>(TABLE.audit, [
      Query.orderDesc('createdAt'),
      Query.limit(Math.min(limit, 100)),
    ]);
    return rows.map((r) => ({
      entryId: r.entryId,
      actorId: r.actorId,
      operation: r.operation,
      targetId: r.targetId,
      beforeJson: r.beforeJson,
      afterJson: r.afterJson,
      requestId: r.requestId,
      createdAt: iso(r.createdAt),
    }));
  }
}
