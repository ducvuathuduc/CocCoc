namespace CocEnglish.Contracts;

/// <summary>Owned inventory item, including its persisted optional expiry.</summary>
public sealed record InventoryResponse(string ItemId, long Quantity, DateTimeOffset? ExpiresAt);

/// <summary>Server-owned shop offer with wallet and capacity availability applied.</summary>
public sealed record ShopItemResponse(string ItemId, string Kind, long PriceGems, long MaxOwned, long Owned, long? DurationMinutes, bool Available);

/// <summary>Versioned shop catalog and the verified account's wallet/inventory projection.</summary>
public sealed record ShopResponse(string CatalogVersion, long Gems, long FreezeSlots, IReadOnlyList<ShopItemResponse> Items, IReadOnlyList<InventoryResponse> Inventory, DateTimeOffset AsOf);

/// <summary>Atomic virtual-item purchase outcome; Learning applies pending energy grants asynchronously.</summary>
public sealed record ShopPurchaseResponse(string OperationId, string ItemId, long Quantity, long GemsSpent, long Gems, long FreezeSlots,
    InventoryResponse? Inventory, bool EnergyGrantPending, DateTimeOffset AsOf);

/// <summary>Inventory-backed boost window, stacked after any active window of its kind.</summary>
public sealed record BoostResponse(string BoostId, string Kind, long Multiplier, DateTimeOffset StartsAt, DateTimeOffset EndsAt, InventoryResponse Inventory);

/// <summary>Purchase a bounded quantity from an explicit server catalog version.</summary>
public sealed record ShopPurchaseRequest(string ItemId, long Quantity, string CatalogVersion);

/// <summary>Restore the server-recorded lost streak using gems or an owned repair item.</summary>
public sealed record StreakRepairRequest(string LostStreakDay, string PayWith);
