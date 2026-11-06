namespace CocEnglish.Contracts;

/// <summary>Verified account's membership of an active classroom.</summary>
public sealed record ClassroomMembershipResponse(string ClassroomId, string Name, string CourseId, string Status, DateTimeOffset JoinedAt);

/// <summary>Own yearly learning summary; finished years are frozen on first generation.</summary>
public sealed record YearReviewResponse(int Year, DateTimeOffset GeneratedAt, long TotalXp, long ActiveDays, long LongestStreak,
    long LessonsCompleted, long WordsLearned, long MinutesSpent, long AchievementsEarned, long? TopLeagueTier, IReadOnlyList<string> CourseIds);
