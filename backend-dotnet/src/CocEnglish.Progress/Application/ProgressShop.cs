using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using CocEnglish.Progress.Domain;
using System.Text.Json.Nodes;
using System.Globalization;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressShop
{
    public async Task<ShopResponse> ListAsync(OwnerSession tx, string userId, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, userId, ct);
        var rewards = await tx.GetAsync("p_rewards", CanonicalWire.RowId("p_rewards", userId), ct) ?? ProgressEconomy.EmptyRewards(userId);
        var rows = await tx.ListAsync("p_inventory", new(Where: new Dictionary<string, object?> { ["userId"] = userId }, Limit: 50), ct);
        var inventory = rows.Select(r => new InventoryResponse(r.Data.Text("itemId")!, r.Data.Number("quantity"),
            r.Data.Text("expiresAt") is { } expiry ? DateTimeOffset.Parse(expiry, CultureInfo.InvariantCulture) : null)).ToArray();
        var slots = rewards.Number("freezeSlots");
        var gems = rewards.Number("gems");
        var items = ProgressCatalog.Shop.Select(item =>
        {
            var held = item.Kind == "FREEZE" ? slots : inventory.FirstOrDefault(i => i.ItemId == item.Id)?.Quantity ?? 0;
            var capacity = item.Kind == "FREEZE" ? ProgressCatalog.FreezeCapacity(rewards.Number("currentStreak")) : item.MaxOwned;
            return new ShopItemResponse(item.Id, item.Kind, item.Price, capacity, held, item.Minutes,
                item.Available && (item.Kind == "ENERGY_REFILL" || held < capacity) && gems >= item.Price);
        }).ToArray();
        return new(ProgressCatalog.ShopVersion, gems, slots, items, inventory, tx.Now);
    }

    public async Task<ShopPurchaseResponse> BuyAsync(OwnerSession tx, string userId, ShopPurchaseRequest request, string key, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, userId, ct);
        var zone = profile.Text("learningZone") ?? "UTC";
        var item = ProgressCatalog.Shop.FirstOrDefault(i => i.Id == request.ItemId);
        if (request.CatalogVersion != ProgressCatalog.ShopVersion || item is null || !item.Available)
            throw new ServiceException("ITEM_UNAVAILABLE", new() { ["itemId"] = request.ItemId, ["catalogVersion"] = ProgressCatalog.ShopVersion });
        var operation = CanonicalWire.RowId("operation", "shop-buy", userId, key);
        var id = CanonicalWire.RowId("p_rewards", userId);
        var wallet = await tx.GetAsync("p_rewards", id, ct) ?? ProgressEconomy.EmptyRewards(userId);
        var cost = item.Price * request.Quantity;
        var slots = wallet.Number("freezeSlots");
        if (item.Kind == "FREEZE")
        {
            if (slots + request.Quantity > ProgressCatalog.FreezeCapacity(wallet.Number("currentStreak"))) throw new ServiceException("FREEZE_CAPACITY", new() { ["freezeSlots"] = slots });
        }
        else if (item.Kind == "ENERGY_REFILL")
        {
            if (request.Quantity != 1) throw new ServiceException("ITEM_UNAVAILABLE", new() { ["reason"] = "ONE_REFILL_PER_PURCHASE" });
        }
        else
        {
            var held = await tx.GetAsync("p_inventory", CanonicalWire.RowId("p_inventory", userId, item.Id), ct);
            if ((held?.Number("quantity") ?? 0) + request.Quantity > item.MaxOwned)
                throw new ServiceException("ITEM_UNAVAILABLE", new() { ["reason"] = "MAX_OWNED", ["itemId"] = item.Id });
        }
        if (wallet.Number("gems") < cost) throw new ServiceException("INSUFFICIENT_GEMS", new() { ["required"] = cost });
        var gems = await CreditGemsAsync(tx, userId, -cost, "SHOP", operation, item.Id, zone, ct);
        InventoryResponse? inventory = null;
        if (item.Kind == "FREEZE")
        {
            var rewards = (await tx.GetAsync("p_rewards", id, ct))!;
            slots += request.Quantity;
            rewards["freezeSlots"] = slots;
            tx.Put("p_rewards", id, rewards);
            tx.Put("p_freeze_ledger", CanonicalWire.RowId("p_freeze_ledger", userId, operation), new()
            { ["userId"] = userId, ["operationId"] = operation, ["action"] = "BUY", ["day"] = null, ["gemsDelta"] = -cost, ["slotDelta"] = request.Quantity });
        }
        else if (item.Kind == "ENERGY_REFILL")
        {
            PutItemLedger(tx, userId, item.Id, "BUY", operation, 0, -cost, "shop");
            ProgressWrites.EnqueueEvent(tx, "energy.granted.v1", userId, new()
            { ["operationId"] = operation, ["userId"] = userId, ["amount"] = null, ["refillToCapacity"] = true, ["reason"] = "SHOP" });
        }
        else inventory = await AdjustInventoryAsync(tx, userId, item.Id, request.Quantity, "BUY", operation, -cost, "shop", ct);
        return new(operation, item.Id, request.Quantity, cost, gems, slots, inventory, item.Kind == "ENERGY_REFILL", tx.Now);
    }

    public async Task<BoostResponse> ActivateAsync(OwnerSession tx, string userId, string itemId, string key, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, userId, ct);
        var item = ProgressCatalog.Shop.FirstOrDefault(i => i.Id == itemId);
        if (item is null || item.Kind is not ("XP_BOOST" or "TIMER_BOOST") || item.Minutes is null or 0)
            throw new ServiceException("ITEM_UNAVAILABLE", new() { ["itemId"] = itemId });
        var operation = CanonicalWire.RowId("operation", "boost", userId, key);
        var inventory = await AdjustInventoryAsync(tx, userId, itemId, -1, "ACTIVATE", operation, 0, "boost", ct);
        var active = await tx.ListAsync("p_boosts", new(Where: new Dictionary<string, object?> { ["userId"] = userId, ["kind"] = item.Kind },
            GreaterThanEqual: new Dictionary<string, object?> { ["endsAt"] = tx.NowIso }, OrderBy: [new("endsAt", true)], Limit: 1), ct);
        var starts = active.FirstOrDefault()?.Data.Text("endsAt") is { } last ? DateTimeOffset.Parse(last, CultureInfo.InvariantCulture) : tx.Now;
        var ends = starts.AddMinutes(item.Minutes.Value);
        tx.Put("p_boosts", CanonicalWire.RowId("p_boosts", userId, operation), new()
        {
            ["userId"] = userId, ["boostId"] = operation, ["kind"] = item.Kind, ["multiplier"] = item.Multiplier,
            ["startsAt"] = OwnerSchema.Iso(starts), ["endsAt"] = OwnerSchema.Iso(ends), ["sourceOperationId"] = operation
        });
        return new(operation, item.Kind, item.Multiplier, starts, ends, inventory);
    }

    public async Task<RewardsResponse> RepairAsync(OwnerSession tx, string userId, StreakRepairRequest request, string key, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, userId, ct);
        var zone = profile.Text("learningZone") ?? "UTC";
        var id = CanonicalWire.RowId("p_rewards", userId);
        var stored = await tx.GetAsync("p_rewards", id, ct) ?? ProgressEconomy.EmptyRewards(userId);
        var lost = stored.Number("lostStreak");
        if (lost <= 0 || stored.Text("lostStreakDay") != request.LostStreakDay || ZonedDay(tx.Now, zone).DayNumber - Day(request.LostStreakDay).DayNumber > 2)
            throw new ServiceException("STREAK_REPAIR_EXPIRED");
        var operation = CanonicalWire.RowId("operation", "streak-repair", userId, key);
        if (request.PayWith == "GEMS") await CreditGemsAsync(tx, userId, -100, "STREAK", operation, "streak_repair", zone, ct);
        else await AdjustInventoryAsync(tx, userId, "streak_repair", -1, "CONSUME", operation, 0, "streak-repair", ct);
        var rewards = await tx.GetAsync("p_rewards", id, ct) ?? stored;
        var last = rewards.Text("lastQualifiedDay");
        var continuing = last is not null && StringComparer.Ordinal.Compare(last, request.LostStreakDay) >= 0;
        var restored = lost + (continuing ? rewards.Number("currentStreak") : 0);
        var end = continuing ? Day(last!) : Day(request.LostStreakDay).AddDays(-1);
        rewards["currentStreak"] = restored;
        rewards["streakStartDay"] = DayKey(end.AddDays(checked((int)-(restored - 1))));
        rewards["lastQualifiedDay"] = continuing ? last : DayKey(end);
        rewards["bestStreak"] = Math.Max(rewards.Number("bestStreak"), restored);
        rewards["lostStreak"] = 0; rewards["lostStreakDay"] = null;
        tx.Put("p_rewards", id, rewards);
        rewards["revision"] = stored.Number("revision", -1) + 1;
        return ProgressReads.RewardsView(tx.Now, zone, rewards);
    }

    internal static async Task<long> CreditGemsAsync(OwnerSession tx, string userId, long delta, string kind, string completionId, string identity, string zone, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_rewards", userId);
        var rewards = await tx.GetAsync("p_rewards", id, ct) ?? ProgressEconomy.EmptyRewards(userId);
        var balance = rewards.Number("gems");
        var applied = Math.Max(delta, -balance);
        if (delta < 0 && applied != delta && kind != "REFUND") throw new ServiceException("INSUFFICIENT_GEMS", new() { ["required"] = -delta });
        rewards["gems"] = balance + applied;
        tx.Put("p_rewards", id, rewards);
        var ledger = CanonicalWire.RowId("p_reward_ledger", userId, completionId, kind);
        if (await tx.GetAsync("p_reward_ledger", ledger, ct) is not null) throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["reason"] = "LEDGER_ROW_EXISTS" });
        tx.Put("p_reward_ledger", ledger, new()
        {
            ["eventId"] = CanonicalWire.RowId("operation", "ledger", userId, completionId, kind), ["completionId"] = completionId, ["userId"] = userId,
            ["rewardIdentity"] = identity[..Math.Min(36, identity.Length)], ["kind"] = kind, ["studyXpDelta"] = 0, ["leagueXpDelta"] = 0,
            ["gemsDelta"] = applied, ["learningDay"] = DayKey(ZonedDay(tx.Now, zone)), ["leagueWeek"] = LeagueWeek(tx.Now), ["occurredAt"] = tx.NowIso, ["capped"] = false
        });
        return balance + applied;
    }

    internal static async Task<InventoryResponse> AdjustInventoryAsync(OwnerSession tx, string userId, string item, long delta, string action, string operation, long gems, string source, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_inventory", userId, item);
        var row = await tx.GetAsync("p_inventory", id, ct) ?? new JsonObject { ["userId"] = userId, ["itemId"] = item, ["expiresAt"] = null };
        var quantity = row.Number("quantity") + delta;
        if (quantity < 0) throw new ServiceException("ITEM_UNAVAILABLE", new() { ["itemId"] = item });
        row["quantity"] = Math.Min(999, quantity);
        tx.Put("p_inventory", id, row);
        PutItemLedger(tx, userId, item, action, operation, delta, gems, source);
        return new(item, Math.Min(999, quantity), null);
    }

    private static void PutItemLedger(OwnerSession tx, string userId, string item, string action, string operation, long quantity, long gems, string source) =>
        tx.Put("p_item_ledger", CanonicalWire.RowId("p_item_ledger", userId, operation, item), new()
        {
            ["userId"] = userId, ["operationId"] = operation, ["itemId"] = item, ["action"] = action, ["quantityDelta"] = quantity,
            ["gemsDelta"] = gems, ["source"] = source, ["occurredAt"] = tx.NowIso
        });
}
