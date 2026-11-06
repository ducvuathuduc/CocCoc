namespace CocEnglish.Contracts;

/// <summary>Server-ranked member of a weekly league cohort.</summary>
public sealed record LeagueMemberResponse(string UserId, string Nickname, long EligibleXp, int Rank, DateTimeOffset? LastXpAt);

/// <summary>Own current weekly cohort and bounded ranked member list.</summary>
public sealed record LeagueResponse(string WeekId, string CohortId, long Tier, string Status, IReadOnlyList<LeagueMemberResponse> Members, DateTimeOffset AsOf, string? NextCursor);

/// <summary>One persisted settled league result projected without internal settlement fields.</summary>
public sealed record SettledLeagueResponse(string WeekId, long PreviousTier, long Tier, string Stage, long? Rank, string Outcome, long GemsAwarded);

/// <summary>Own league participation and whether the latest settled result remains unseen.</summary>
public sealed record LeagueResultResponse(long Tier, string Stage, long WeeksParticipated, long TopThreeFinishes, long DiamondWeeks,
    SettledLeagueResponse? LastResult, bool Unseen, DateTimeOffset AsOf);
