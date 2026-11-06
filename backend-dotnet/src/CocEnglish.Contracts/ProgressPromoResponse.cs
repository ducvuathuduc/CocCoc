namespace CocEnglish.Contracts;

/// <summary>One promo redemption and its type-specific reward.</summary>
public sealed record PromoResponse(string RedemptionId, string PromoId, string RewardType, long? SuperDays, long? Gems,
    string? ItemId, long? ItemQuantity, EntitlementResponse? Entitlement, DateTimeOffset RedeemedAt);
