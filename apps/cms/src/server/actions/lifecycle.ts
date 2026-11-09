'use server';

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { config } from '../config';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';

const run = promisify(execFile);

const LIFECYCLE = 'tools/content/lifecycle-appwrite.mjs';

export type VersionStatus = 'LIVE' | 'SUPERSEDED' | 'RETIRED';

export interface ContentVersionRow {
  courseId: string;
  versionId: string;
  status: VersionStatus;
  manifestSha256: string;
  publishedAt: string;
  retiredAt: string | null;
}

export interface LifecycleResult {
  ok: boolean;
  message?: string;
  versions?: ContentVersionRow[];
}

/**
 * Reads the published-version history of a course straight from Learning's `l_content_versions`
 * table (via the admin route), so the CMS and the app can never disagree about what is live. A
 * read-only call — no `CMS_ALLOW_PUBLISH` needed — but it does require the shared Appwrite project.
 */
export async function getContentVersions(courseId: string): Promise<LifecycleResult> {
  await assertAdmin();
  const c = config();
  if (c.mode !== 'appwrite')
    return {
      ok: false,
      message:
        'Máy này lưu bài trên tệp, chưa nối máy chủ dùng chung, nên chưa xem được lịch sử bản.',
    };
  const result = await runScript([LIFECYCLE, '--action', 'list', '--course', courseId], c);
  if (!result.ok) return { ok: false, message: result.message };
  return { ok: true, versions: result.versions ?? [] };
}

/**
 * Unpublish / retire / rollback. Each is a real write to the shared Learning tables behind a CAS
 * token, so it needs `CMS_ALLOW_PUBLISH=1` exactly like a publish. `expectedPublishedVersion` is the
 * operator's last-known live version; when omitted we let the script read it, but the UI always
 * passes it so two admins cannot roll past each other.
 */
export async function runLifecycle(
  courseId: string,
  action: 'unpublish' | 'retire' | 'rollback',
  options: { versionId?: string; expectedPublishedVersion?: string | null } = {},
): Promise<LifecycleResult> {
  await assertAdmin();
  const c = config();
  if (c.mode !== 'appwrite')
    return {
      ok: false,
      message:
        'Máy này lưu bài trên tệp, chưa nối máy chủ dùng chung, nên chưa đổi được trạng thái bản.',
    };
  if (!c.publishAllowed)
    return {
      ok: false,
      message:
        'Cần đặt CMS_ALLOW_PUBLISH=1 để xác nhận bạn muốn đổi trạng thái bản trên máy chủ dùng chung.',
    };

  const args = [LIFECYCLE, '--action', action, '--course', courseId];
  if (options.versionId) args.push('--version', options.versionId);
  if (options.expectedPublishedVersion !== undefined) {
    if (options.expectedPublishedVersion === null) args.push('--expect', 'null');
    else args.push('--expect', options.expectedPublishedVersion);
  }

  const result = await runScript(args, c);
  await recordAudit({
    actorId: (await assertAdmin()).userId,
    operation: `content.${action}`,
    targetId: `${courseId}${options.versionId ? '/' + options.versionId : ''}`,
    afterJson: JSON.stringify({ ok: result.ok, message: result.message }),
  });
  if (!result.ok) return { ok: false, message: result.message };
  return { ok: true };
}

async function runScript(args: string[], c: ReturnType<typeof config>): Promise<LifecycleResult> {
  try {
    const { stdout } = await run(process.execPath, args, {
      cwd: c.repoRoot,
      maxBuffer: 16 * 1024 * 1024,
      timeout: 120_000,
      env: {
        ...process.env,
        APPWRITE_ENDPOINT: c.endpoint,
        APPWRITE_PROJECT_ID: c.projectId,
        APPWRITE_API_KEY: c.apiKey,
        COC_DATABASE_ID: c.databaseId,
      },
    });
    const text = (stdout ?? '').trim().split('\n').filter(Boolean).pop();
    const data = text ? JSON.parse(text) : {};
    if (data.status !== 'PASS')
      return { ok: false, message: 'Máy chủ trả về kết quả không hợp lệ.' };
    return { ok: true, versions: data.items };
  } catch (error) {
    const failure = error as { stdout?: string; stderr?: string; message?: string };
    const source = (failure.stderr || failure.stdout || failure.message || 'lỗi không rõ')
      .toString()
      .split('\n')
      .reverse()
      .find((l: string) => l.trim().length > 0);
    return { ok: false, message: source?.trim().slice(0, 300) ?? 'Không gọi được máy chủ.' };
  }
}
