import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import type {
  AuditEntry,
  BuildRun,
  CourseRecord,
  UnitRecord,
} from '@/cms/types';
import { ConflictError, NotFoundError, type CmsStore, type UnitIndexEntry } from './port';

interface Db {
  courses: CourseRecord[];
  units: UnitRecord[];
  runs: BuildRun[];
  audit: AuditEntry[];
}

const EMPTY: Db = { courses: [], units: [], runs: [], audit: [] };

/**
 * Dev-only store: a single JSON file guarded by an in-process queue. It exists so the CMS is
 * usable before an Appwrite project is reachable; a production process never selects it.
 */
export class FileStore implements CmsStore {
  readonly mode = 'file' as const;
  private readonly file: string;
  private queue: Promise<void> = Promise.resolve();

  constructor(dataDir: string) {
    this.file = path.join(dataDir, 'cms-data.json');
  }

  private async mutate<T>(fn: (db: Db) => Promise<T> | T): Promise<T> {
    const run = this.queue.then(async () => {
      const db = await this.read();
      const result = await fn(db);
      await mkdir(path.dirname(this.file), { recursive: true });
      await writeFile(this.file, JSON.stringify(db, null, 2), 'utf8');
      return result;
    });
    this.queue = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }

  private async read(): Promise<Db> {
    try {
      const raw = await readFile(this.file, 'utf8');
      return { ...EMPTY, ...(JSON.parse(raw) as Partial<Db>) };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return structuredClone(EMPTY);
      throw error;
    }
  }

  async listCourses(): Promise<CourseRecord[]> {
    const db = await this.read();
    return [...db.courses].sort((a, b) => a.courseId.localeCompare(b.courseId));
  }

  async getCourse(courseId: string): Promise<CourseRecord | null> {
    const db = await this.read();
    return db.courses.find((c) => c.courseId === courseId) ?? null;
  }

  async saveCourse(input: {
    courseId: string;
    draft: CourseRecord['draft'];
    actorId: string;
    expectedRevision: number;
  }): Promise<CourseRecord> {
    return this.mutate((db) => {
      const index = db.courses.findIndex((c) => c.courseId === input.courseId);
      const current = index >= 0 ? db.courses[index] : null;
      if (current && current.revision !== input.expectedRevision) throw new ConflictError();
      const record: CourseRecord = {
        courseId: input.courseId,
        revision: (current?.revision ?? 0) + 1,
        updatedAt: new Date().toISOString(),
        updatedBy: input.actorId,
        draft: input.draft,
      };
      if (index >= 0) db.courses[index] = record;
      else db.courses.push(record);
      return record;
    });
  }

  async listUnits(courseId: string): Promise<UnitRecord[]> {
    const db = await this.read();
    return db.units
      .filter((u) => u.courseId === courseId)
      .sort((a, b) => a.order - b.order);
  }

  async listUnitIndex(courseId: string): Promise<UnitIndexEntry[]> {
    const units = await this.listUnits(courseId);
    return units.map((u) => ({
      unitId: u.unitId,
      order: u.order,
      title: u.draft.title,
      theme: u.draft.theme,
    }));
  }

  async getUnit(courseId: string, unitId: string): Promise<UnitRecord | null> {
    const db = await this.read();
    return db.units.find((u) => u.courseId === courseId && u.unitId === unitId) ?? null;
  }

  async saveUnit(input: {
    courseId: string;
    unitId: string;
    order: number;
    draft: UnitRecord['draft'];
    actorId: string;
    expectedRevision: number;
  }): Promise<UnitRecord> {
    return this.mutate((db) => {
      const key = `${input.courseId}__${input.unitId}`;
      const index = db.units.findIndex((u) => `${u.courseId}__${u.unitId}` === key);
      const current = index >= 0 ? db.units[index] : null;
      if (current && current.revision !== input.expectedRevision) throw new ConflictError();
      if (index < 0 && input.expectedRevision !== 0)
        throw new NotFoundError(`Unit ${input.unitId} chưa tồn tại.`);
      const record: UnitRecord = {
        courseId: input.courseId,
        unitId: input.unitId,
        order: input.order,
        revision: (current?.revision ?? 0) + 1,
        updatedAt: new Date().toISOString(),
        updatedBy: input.actorId,
        draft: input.draft,
      };
      if (index >= 0) db.units[index] = record;
      else db.units.push(record);
      return record;
    });
  }

  async deleteUnit(courseId: string, unitId: string): Promise<void> {
    await this.mutate((db) => {
      db.units = db.units.filter((u) => !(u.courseId === courseId && u.unitId === unitId));
    });
  }

  async listBuildRuns(courseId: string): Promise<BuildRun[]> {
    const db = await this.read();
    return db.runs
      .filter((r) => r.courseId === courseId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  async saveBuildRun(run: BuildRun): Promise<BuildRun> {
    return this.mutate((db) => {
      const index = db.runs.findIndex((r) => r.runId === run.runId);
      if (index >= 0) db.runs[index] = run;
      else db.runs.unshift(run);
      return run;
    });
  }

  async appendAudit(entry: AuditEntry): Promise<void> {
    await this.mutate((db) => {
      db.audit.unshift(entry);
      db.audit = db.audit.slice(0, 500);
    });
  }

  async listAudit(limit: number): Promise<AuditEntry[]> {
    const db = await this.read();
    return db.audit.slice(0, limit);
  }
}
