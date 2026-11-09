'use server';

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { BuildRun } from '@/cms/types';
import { config } from '../config';
import { getStore } from '../store';
import { publishReadiness } from '../publish-state';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';
import { explainPublishFailure } from '../plain-errors';

const run = promisify(execFile);

const PUBLISHER = 'tools/content/publish-appwrite.mjs';

export interface PublishResult {
  ok: boolean;
  run?: BuildRun;
  message?: string;
  warning?: string;
}

/**
 * Publishes the committed build of a course version by running the repository's own publisher, which
 * uploads the manifest, bundles and media to `learning-assets` and then flips the Learning pointer
 * through POST /v1/admin/content-versions. The CMS never writes `l_*` rows itself.
 *
 * `live` is false by default: the dry run uploads nothing it cannot redo and prints the file counts,
 * so an operator can see the scope before touching a shared project.
 */
export async function publishCourseVersion(courseId: string, live: boolean): Promise<PublishResult> {
  const actor = await assertAdmin();
  const c = config();
  const store = getStore();

  const readiness = await publishReadiness(courseId);
  if (!readiness) return { ok: false, message: 'Khóa này chưa có bản nháp nào để cho app nhận.' };
  if (!readiness.gatesOk) return { ok: false, message: readiness.blocking };
  if (c.mode !== 'appwrite')
    return {
      ok: false,
      message:
        'Máy này đang lưu bài trên một tệp, chưa nối máy chủ dùng chung, nên chưa chạy được bước cho app nhận bản — kể cả chạy thử.',
    };
  if (live && !c.publishAllowed)
    return {
      ok: false,
      message:
        'Xuất bản thật đang bị khóa ở máy chủ. Nhờ người quản trị mở quyền xuất bản, hoặc bấm “Chạy thử” để xem trước mà không ghi gì.',
    };

  const args = [PUBLISHER, '--course', courseId, '--version', readiness.version];
  if (!live) args.push('--dry-run');

  const runId = crypto.randomUUID();
  const record: BuildRun = {
    runId,
    courseId,
    versionId: readiness.version,
    kind: 'PUBLISH',
    status: 'RUNNING',
    message: live ? 'Đang cho app nhận bản…' : 'Đang chạy thử bước cho app nhận bản…',
    log: [`$ node ${args.join(' ')}`],
    actorId: actor.userId,
    createdAt: new Date().toISOString(),
  };
  await store.saveBuildRun(record);

  let status: BuildRun['status'] = 'SUCCEEDED';
  let message = live
    ? `App đã nhận bản ${readiness.version} của khóa này.`
    : `Chạy thử ổn: bản ${readiness.version} đã sẵn sàng để cho app nhận.`;
  const log = [...record.log];
  try {
    const { stdout, stderr } = await run(process.execPath, args, {
      cwd: c.repoRoot,
      maxBuffer: 16 * 1024 * 1024,
      timeout: 900_000,
      env: {
        ...process.env,
        APPWRITE_ENDPOINT: c.endpoint,
        APPWRITE_PROJECT_ID: c.projectId,
        APPWRITE_API_KEY: c.apiKey,
        COC_DATABASE_ID: c.databaseId,
      },
    });
    log.push(...tail(stdout), ...tail(stderr));
  } catch (error) {
    const failure = error as { stdout?: string; stderr?: string; message?: string };
    const raw = [failure.stderr, failure.stdout, failure.message].filter(Boolean).join('\n');
    status = 'FAILED';
    message = explainPublishFailure(raw);
    console.error(`[publish ${courseId}/${readiness.version}]\n${raw.slice(-2000)}`);
    log.push(...tail(failure.stdout ?? ''), ...tail(failure.stderr ?? failure.message ?? ''));
  }

  const finished: BuildRun = { ...record, status, message, log };
  await store.saveBuildRun(finished);
  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: live ? 'content.publish' : 'content.publish_dry_run',
    targetId: `${courseId}/${readiness.version}`,
    afterJson: JSON.stringify({ status, message }),
  });
  return {
    ok: status === 'SUCCEEDED',
    run: finished,
    message: status === 'SUCCEEDED' ? undefined : message,
    warning: auditWarning ?? undefined,
  };
}

const tail = (text: string, lines = 30): string[] =>
  text
    .split('\n')
    .map((l) => l.trimEnd())
    .filter(Boolean)
    .slice(-lines);

