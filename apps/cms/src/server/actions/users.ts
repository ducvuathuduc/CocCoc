'use server';

import { recordAudit } from '../audit';
import { config } from '../config';
import { LEARNER_GONE, LEARNERS_UNAVAILABLE, getDirectory } from '../ops/learners';
import { isUserId } from '../ops/port';
import { assertAdmin } from '../session';

export interface UserAccessResult {
  ok: boolean;
  /** The status now stored in Appwrite Auth, so the button can show what it just did. */
  locked?: boolean;
  /** Set when nothing needed writing: the account was already in that state. */
  unchanged?: boolean;
  message?: string;
  /** The change happened but the audit row could not be written. */
  warning?: string;
}

/**
 * Locking means disabling the Appwrite account, which is the only thing the CMS may change about a
 * learner: the app refuses to sign a disabled account in, and every progress row stays exactly as the
 * person left it. Nothing here can be undone by the CMS writing a row — that is why the refusal cases
 * below all answer before a request leaves the process.
 */
export async function setLearnerAccess(
  userId: string,
  locked: boolean,
): Promise<UserAccessResult> {
  const actor = await assertAdmin();
  if (!isUserId(userId))
    return { ok: false, message: 'Mã tài khoản không hợp lệ, nên chưa có gì bị khóa.' };
  if (config().admins.has(userId))
    return {
      ok: false,
      message: 'Không khóa được tài khoản quản trị: sẽ mất luôn quyền vào CMS.',
    };

  const directory = getDirectory();
  if (!directory) return { ok: false, message: LEARNERS_UNAVAILABLE };

  let account;
  try {
    account = await directory.getAccount(userId);
  } catch {
    // Whatever the project answered — dropped socket, rejected key — no account was touched.
    return { ok: false, message: LEARNERS_UNAVAILABLE };
  }
  if (!account) return { ok: false, message: LEARNER_GONE };
  if (account.locked === locked) return { ok: true, locked, unchanged: true };

  try {
    await directory.setAccess(userId, locked);
  } catch {
    return { ok: false, message: LEARNERS_UNAVAILABLE };
  }

  const warning = await recordAudit({
    actorId: actor.userId,
    operation: locked ? 'user.lock' : 'user.unlock',
    targetId: userId,
    beforeJson: JSON.stringify({ locked: account.locked }),
    afterJson: JSON.stringify({ locked }),
  });
  return { ok: true, locked, warning: warning ?? undefined };
}
