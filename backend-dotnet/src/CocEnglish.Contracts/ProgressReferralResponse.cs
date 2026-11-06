namespace CocEnglish.Contracts;

/// <summary>Server-derived invitation code and bounded referral counts.</summary>
public sealed record ReferralResponse(string Code, int Accepted, int Qualified, int Rewarded, DateTimeOffset AsOf);
