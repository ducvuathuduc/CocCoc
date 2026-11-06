import { config } from '../config';
import { StoreUnavailableError } from '../store/port';
import { AppwriteLearnerDirectory } from './appwrite';
import {
  isUserId,
  type ContentReportRow,
  type DayRow,
  type EnrollmentRow,
  type EntitlementRow,
  type FeedbackRow,
  type LearnerContentReportView,
  type LearnerDayView,
  type LearnerDetail,
  type LearnerDirectory,
  type LearnerEntitlementView,
  type LearnerEnrollmentView,
  type LearnerNoteView,
  type LearnerProfileView,
  type LearnerQueue,
  type LearnerSummary,
  type LearnerUserReportView,
  type ProfileRow,
  type UserReportRow,
} from './port';

/** One sentence for the operator, for a machine that cannot reach the project at all. */
export const LEARNERS_UNAVAILABLE =
  'Chưa đọc được tài khoản người học: máy này chưa nối (hoặc đang không gọi được) Appwrite.';

/** Said when the account itself is gone: there is nothing left to lock, and no row to leave behind. */
export const LEARNER_GONE =
  'Tài khoản này không còn trong hệ thống — có lẽ người học đã tự xóa. Không có gì để khóa.';

const RECENT_DAYS = 14;
const NOTES_PER_LEARNER = 30;
const QUEUE_PAGE = 50;

let directory: LearnerDirectory | null | undefined;

/**
 * `null` when the CMS runs without an Appwrite pair: there is no such thing as a local file store of
 * other people's accounts, so a screen must say so instead of listing an empty room.
 */
export function getDirectory(): LearnerDirectory | null {
  if (directory !== undefined) return directory;
  const c = config();
  directory =
    c.mode === 'appwrite'
      ? new AppwriteLearnerDirectory(c.endpoint, c.projectId, c.apiKey, c.databaseId)
      : null;
  return directory;
}

function requireDirectory(): LearnerDirectory {
  const found = getDirectory();
  if (!found) throw new Error(LEARNERS_UNAVAILABLE);
  return found;
}

/** A dropped connection becomes the one sentence above; a rejected query stays a real error. */
async function explain<T>(request: () => Promise<T>): Promise<T> {
  try {
    return await request();
  } catch (error) {
    if (error instanceof StoreUnavailableError)
      throw new Error(LEARNERS_UNAVAILABLE, { cause: error });
    throw error;
  }
}

const countLessons = (raw: string): number => {
  try {
    const list: unknown = JSON.parse(raw);
    return Array.isArray(list) ? list.length : 0;
  } catch {
    return 0;
  }
};

const toProfile = (row: ProfileRow): LearnerProfileView => ({
  nickname: row.nickname,
  username: row.username,
  ageBand: row.ageBand,
  dailyGoal: Number(row.dailyGoal),
  joinedAt: row.createdAt,
  deleted: Boolean(row.deletedAt),
});

const toEntitlement = (row: EntitlementRow): LearnerEntitlementView => ({
  plan: row.plan,
  source: row.source,
  status: row.status,
  expiresAt: row.expiresAt || null,
});

const toEnrollment = (row: EnrollmentRow): LearnerEnrollmentView => ({
  courseId: row.courseId,
  courseVersion: row.courseVersion,
  lessonsDone: countLessons(row.completedLessonsJson),
  frontier: Number(row.frontierNodeOrder),
  proficiency: Number(row.proficiencyScore),
});

const toDay = (row: DayRow): LearnerDayView => ({
  day: row.day,
  xp: Number(row.studyXp) + Number(row.replayXp),
  lessons: Number(row.completedLessons),
});

const toNote = (row: FeedbackRow): LearnerNoteView => ({
  noteId: row.$id,
  userId: row.userId,
  topic: row.topic,
  message: row.message,
  platform: row.platform,
  status: row.status,
  createdAt: row.createdAt,
});

const toUserReport = (row: UserReportRow): LearnerUserReportView => ({
  reportId: row.$id,
  reporterId: row.reporterId,
  targetUserId: row.targetUserId,
  reason: row.reason,
  note: row.note ?? '',
  createdAt: row.createdAt,
});

const toContentReport = (row: ContentReportRow): LearnerContentReportView => ({
  reportId: row.$id,
  userId: row.userId,
  exerciseId: row.exerciseId,
  lessonVersion: row.lessonVersion,
  category: row.category,
  note: row.note,
  createdAt: row.createdAt,
});

/** Every account in the project, newest first. Appwrite filters the search term; nothing is filtered here. */
export async function listLearners(search: string): Promise<LearnerSummary[]> {
  const found = requireDirectory();
  return explain(() => found.listAccounts(search.trim()));
}

/**
 * One person as the app stored them. `null` means the account is gone — a person who deleted it leaves
 * the CMS with nothing to show, and inventing a row would look like a bug in the app.
 */
export async function learnerDetail(userId: string): Promise<LearnerDetail | null> {
  const found = requireDirectory();
  if (!isUserId(userId)) return null;
  const account = await explain(() => found.getAccount(userId));
  if (!account) return null;
  const [profile, entitlement, enrollment, days, notes] = await explain(() =>
    Promise.all([
      found.firstRow<ProfileRow>('profiles', userId),
      found.firstRow<EntitlementRow>('entitlements', userId),
      found.firstRow<EnrollmentRow>('enrollments', userId),
      found.userRows<DayRow>('days', userId, 'day', RECENT_DAYS),
      found.userRows<FeedbackRow>('feedback', userId, 'createdAt', NOTES_PER_LEARNER),
    ]),
  );
  return {
    userId,
    account,
    profile: profile ? toProfile(profile) : null,
    entitlement: entitlement ? toEntitlement(entitlement) : null,
    enrollment: enrollment ? toEnrollment(enrollment) : null,
    days: days.map(toDay),
    // The read uses one index, so whether a note is still open is decided on the recent slice it gave back.
    feedback: notes.filter((note) => note.status === 'OPEN').map(toNote),
  };
}

/** What learners told us and still wait for an answer: feedback, reports about a person, reports about a lesson. */
export async function learnerQueue(): Promise<LearnerQueue> {
  const found = requireDirectory();
  const [feedback, userReports, contentReports] = await explain(() =>
    Promise.all([
      found.openRows<FeedbackRow>('feedback', QUEUE_PAGE),
      found.openRows<UserReportRow>('userReports', QUEUE_PAGE),
      found.openRows<ContentReportRow>('contentReports', QUEUE_PAGE),
    ]),
  );
  return {
    feedback: feedback.map(toNote),
    userReports: userReports.map(toUserReport),
    contentReports: contentReports.map(toContentReport),
  };
}
