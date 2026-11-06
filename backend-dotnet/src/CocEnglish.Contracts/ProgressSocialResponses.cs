namespace CocEnglish.Contracts;

/// <summary>Account-relative view of a persisted friend-streak invitation or run.</summary>
public sealed record FriendStreakResponse(string PairId, string FriendUserId, string FriendNickname, string InviterId, string Status,
    long Length, string? StartDay, string? LastExtendedDay, bool ExtendedToday);

/// <summary>Bounded open friend-streak relationships.</summary>
public sealed record FriendStreakPageResponse(IReadOnlyList<FriendStreakResponse> Items, string? NextCursor, DateTimeOffset AsOf);

/// <summary>Privacy-filtered public account projection without credentials or wallet data.</summary>
public sealed record PublicProfileResponse(string UserId, string Nickname, string? AvatarId, long StudyXp, long Streak,
    IReadOnlyList<string> AchievementIds, string FollowStatus);

/// <summary>Privacy-filtered mutual-friend page.</summary>
public sealed record FriendsPageResponse(IReadOnlyList<PublicProfileResponse> Items, string? NextCursor, DateTimeOffset AsOf);

/// <summary>Safe public activity text without private event payload.</summary>
public sealed record ActivityResponse(string EventId, string UserId, string Kind, string Summary, DateTimeOffset CreatedAt);

/// <summary>Own activity and visible activity of followed accounts.</summary>
public sealed record ActivityPageResponse(IReadOnlyList<ActivityResponse> Items, string? NextCursor, DateTimeOffset AsOf);
