namespace CocEnglish.Contracts;

/// <summary>Gift delivery projection without the simulated purchase token.</summary>
public sealed record GiftResponse(string GiftId, string SenderId, string RecipientId, string Plan, long DurationDays, string? Note, string Status, DateTimeOffset? DeliveredAt);
