/**
 * The read side of learner administration.
 *
 * Everything here comes from tables the app writes: `p_*` (progress, profile, feedback) and `l_*`
 * (enrollment, lesson reports). The CMS reads them and never writes them — a maintainer's opinion
 * about a learner is not a fact about their learning. The one change this module can make lives
 * outside the tables: the account status on Appwrite Auth, which is what `setAccess` is for.
 */

/** Appwrite needs a table ID; the symbolic name keeps the call sites readable. */
export const APP_TABLE = {
  profiles: 'p_profiles',
  entitlements: 'p_entitlements',
  enrollments: 'l_enrollments',
  days: 'p_day_activity',
  feedback: 'p_feedback',
  userReports: 'p_user_reports',
  contentReports: 'l_reports',
} as const;

export type AppTableName = keyof typeof APP_TABLE;

export type LearnerSummary = {
  userId: string;
  email: string;
  name: string;
  /** `true` when Appwrite Auth has the account disabled — the app cannot sign them in. */
  locked: boolean;
  /** An account with no email exists only as an ID, usually because sign-up was never finished. */
  anonymous: boolean;
  createdAt: string;
};

export type ProfileRow = {
  $id: string;
  userId: string;
  username: string;
  nickname: string;
  ageBand: string;
  dailyGoal: number;
  deletedAt: string | null;
  createdAt: string;
};

export type EntitlementRow = {
  $id: string;
  userId: string;
  plan: string;
  source: string;
  status: string;
  expiresAt: string | null;
};

export type EnrollmentRow = {
  $id: string;
  userId: string;
  courseId: string;
  courseVersion: string;
  frontierNodeOrder: number;
  completedLessonsJson: string;
  proficiencyScore: number;
};

export type DayRow = {
  $id: string;
  day: string;
  studyXp: number;
  replayXp: number;
  completedLessons: number;
};

export type FeedbackRow = {
  $id: string;
  userId: string;
  topic: string;
  message: string;
  platform: string;
  status: string;
  createdAt: string;
};

export type UserReportRow = {
  $id: string;
  reporterId: string;
  targetUserId: string;
  reason: string;
  note: string | null;
  createdAt: string;
};

export type ContentReportRow = {
  $id: string;
  userId: string;
  exerciseId: string;
  lessonVersion: string;
  category: string;
  note: string;
  createdAt: string;
};

/** The three views a screen may render, each already decided so the page never re-derives a fact. */
export type LearnerProfileView = {
  nickname: string;
  username: string;
  ageBand: string;
  dailyGoal: number;
  joinedAt: string;
  deleted: boolean;
};

export type LearnerEntitlementView = {
  plan: string;
  source: string;
  status: string;
  expiresAt: string | null;
};

export type LearnerEnrollmentView = {
  courseId: string;
  courseVersion: string;
  lessonsDone: number;
  frontier: number;
  proficiency: number;
};

export type LearnerDayView = {
  day: string;
  xp: number;
  lessons: number;
};

export type LearnerNoteView = {
  noteId: string;
  userId: string;
  topic: string;
  message: string;
  platform: string;
  status: string;
  createdAt: string;
};

export type LearnerUserReportView = {
  reportId: string;
  reporterId: string;
  targetUserId: string;
  reason: string;
  note: string;
  createdAt: string;
};

export type LearnerContentReportView = {
  reportId: string;
  userId: string;
  exerciseId: string;
  lessonVersion: string;
  category: string;
  note: string;
  createdAt: string;
};

export type LearnerDetail = {
  userId: string;
  account: LearnerSummary;
  /** `null` for every view below means the app never stored a row: the person never finished onboarding. */
  profile: LearnerProfileView | null;
  entitlement: LearnerEntitlementView | null;
  enrollment: LearnerEnrollmentView | null;
  days: LearnerDayView[];
  feedback: LearnerNoteView[];
};

export type LearnerQueue = {
  feedback: LearnerNoteView[];
  userReports: LearnerUserReportView[];
  contentReports: LearnerContentReportView[];
};

/**
 * Every read is one query on one indexed column; an unindexed filter is a 400 that only a live project
 * reports, so the interface offers whole questions instead of raw queries and the implementations below
 * answer them with indexed columns only.
 */
export interface LearnerDirectory {
  listAccounts(search: string): Promise<LearnerSummary[]>;
  getAccount(userId: string): Promise<LearnerSummary | null>;
  setAccess(userId: string, locked: boolean): Promise<void>;
  firstRow<T>(table: AppTableName, userId: string): Promise<T | null>;
  userRows<T>(
    table: AppTableName,
    userId: string,
    newestBy: string,
    limit: number,
  ): Promise<T[]>;
  openRows<T>(table: AppTableName, limit: number): Promise<T[]>;
}

/** Appwrite's own rule for an account ID, restated so a malformed one never reaches the network. */
const USER_ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

export function isUserId(value: string): boolean {
  return USER_ID.test(value);
}
