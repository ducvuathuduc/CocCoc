namespace CocEnglish.Contracts;

/// <summary>Private profile projection matching the existing Profile schema.</summary>
public sealed record ProfileResponse(string UserId, string Nickname, string? AvatarId, bool PublicOptIn, int DailyGoal,
    string LearningZone, string? PendingZone, DateTimeOffset? ZoneEffectiveAt, long Revision, IReadOnlyList<string> AchievementIds);

/// <summary>Server-owned reward totals and optional completion-credit status.</summary>
public sealed record RewardsResponse(string? CompletionId, string Status, long StudyXp, long LeagueXp, long Gems, long FreezeSlots,
    long CurrentStreak, long? AwardXp, long Revision, DateTimeOffset AsOf);

/// <summary>Persisted activity for one immutable server learning-day key.</summary>
public sealed record LearningStatsDayResponse(string Day, long StudyXp, long CompletedLessons, long ReviewSessions,
    long OriginalCorrect, bool Active, long TrackedOriginalCount, long TrackedOriginalCorrect);

/// <summary>Own last 28 learning days, including empty days and tracked accuracy counts.</summary>
public sealed record LearningStatsResponse(DateTimeOffset AsOf, string LearningZone, IReadOnlyList<LearningStatsDayResponse> Days);

/// <summary>Current progress against a server-owned quest template.</summary>
public sealed record QuestResponse(string QuestId, string Period, string PeriodKey, long Target, long MetricValue, bool Claimed, long RewardGems);

/// <summary>Bounded quest page with an opaque continuation cursor.</summary>
public sealed record QuestPageResponse(IReadOnlyList<QuestResponse> Items, string? NextCursor, DateTimeOffset AsOf);

/// <summary>Private account notification and exercise preferences.</summary>
public sealed record PreferencesResponse(IReadOnlyList<string> NotificationsOff, bool SmartScheduling, long ReminderMinute,
    bool SoundEffects, bool Haptics, bool MotivationalMessages, bool ListeningExercises, bool SpeakingExercises,
    bool FriendStreakInvites, long Revision, DateTimeOffset AsOf);

/// <summary>Durable account-deletion request; owner purge and acknowledgement are asynchronous.</summary>
public sealed record DeletionReceiptResponse(string RequestId, string Status, DateTimeOffset RequestedAt);
