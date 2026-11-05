using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using System.Globalization;

namespace CocEnglish.Progress.Application;

public sealed class ProgressGifts
{
    public async Task<GiftResponse> SendAsync(OwnerSession tx, string user, string recipient, string plan, long days, string? note, string outcome, string key, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var target = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", recipient), ct);
        if (target is null || target.Text("deletedAt") is { Length: > 0 } || recipient == user) throw new ServiceException("PROFILE_UNAVAILABLE");
        if (await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", user, recipient), ct) is not null ||
            await tx.GetAsync("p_blocks", CanonicalWire.RowId("p_blocks", recipient, user), ct) is not null) throw new ServiceException("USER_BLOCKED");
        if (outcome == "PENDING") throw new ServiceException("PURCHASE_PENDING");
        var gift = CanonicalWire.RowId("operation", "gift", user, key); var purchase = CanonicalWire.RowId("operation", "gift-purchase", user, key); var token = "sim:" + purchase;
        var paid = outcome is "ACTIVE" or "GRACE";
        tx.Put("p_purchases", CanonicalWire.RowId("p_purchases", purchase), new() { ["purchaseId"] = purchase, ["userId"] = user, ["platform"] = "SIMULATION",
            ["productId"] = "gift_" + plan.ToLowerInvariant(), ["kind"] = "GIFT", ["purchaseToken"] = token, ["purchaseTokenHash"] = CanonicalWire.Sha256(token),
            ["state"] = outcome, ["vendorStateJson"] = CanonicalWire.Stringify(new JsonObject { ["simulation"] = true, ["lastOccurredAt"] = tx.NowIso }), ["verifiedAt"] = tx.NowIso, ["lastNotificationId"] = null });
        tx.Put("p_gifts", CanonicalWire.RowId("p_gifts", gift), new() { ["giftId"] = gift, ["senderId"] = user, ["recipientId"] = recipient, ["plan"] = plan,
            ["durationDays"] = days, ["note"] = note, ["status"] = paid ? "DELIVERED" : "REFUNDED", ["purchaseId"] = purchase, ["deliveredAt"] = paid ? tx.NowIso : null });
        return new(gift, user, recipient, plan, days, note, paid ? "DELIVERED" : "REFUNDED", paid ? tx.Now : null);
    }

    public async Task<EntitlementResponse> RedeemAsync(OwnerSession tx, string user, string giftId, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_gifts", giftId); var gift = await tx.GetAsync("p_gifts", id, ct);
        if (gift is null || gift.Text("recipientId") != user) throw new ServiceException("NOT_FOUND");
        var current = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new JsonObject();
        var entitlement = ProgressReads.EntitlementView(current, tx.Now);
        if (gift.Text("status") == "REDEEMED") return entitlement;
        if (gift.Text("status") != "DELIVERED") throw new ServiceException("NOT_FOUND");
        gift["status"] = "REDEEMED"; tx.Put("p_gifts", id, gift);
        var active = entitlement.UnlimitedEnergy;
        var start = active && current.Text("expiresAt") is { Length: > 0 } expiry ? DateTimeOffset.Parse(expiry, CultureInfo.InvariantCulture) : tx.Now;
        return await ProgressBilling.ChangeEntitlementAsync(tx, user, new() { ["plan"] = active && current.Text("plan") == "MAX" ? "MAX" : gift.Text("plan"),
            ["source"] = active ? current.Text("source") : "GIFT", ["status"] = "ACTIVE", ["expiresAt"] = OwnerSchema.Iso(start.AddDays(gift.Number("durationDays"))), ["giftId"] = giftId }, ct);
    }
}
