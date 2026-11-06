namespace CocEnglish.Contracts;

/// <summary>Owner-only purchase projection without vendor state or tokens.</summary>
public sealed record PurchaseResponse(string PurchaseId, string ProductId, string Kind, string Platform, string State,
    DateTimeOffset? VerifiedAt, long? Gems, EntitlementResponse Entitlement);
