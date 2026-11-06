using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Globalization;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed class ProgressPromos
{
    public async Task<PromoResponse> RedeemAsync(OwnerSession tx, string user, string code, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct); var zone = profile.Text("learningZone") ?? "UTC";
        var hash = ProgressCodes.Hash(code); var rowId = CanonicalWire.RowId("p_promo_codes", CanonicalWire.RowId("operation", "promo", hash));
        var promo = await tx.GetAsync("p_promo_codes", rowId, ct);
        if (promo is not null && promo.Text("codeHash") == hash && await tx.GetAsync("p_promo_redemptions", CanonicalWire.RowId("p_promo_redemptions", user, promo.Text("promoId")!), ct) is not null)
            throw new ServiceException("PROMO_ALREADY_REDEEMED");
        if (promo is null || promo.Text("codeHash") != hash || promo.Text("status") != "ACTIVE" ||
            StringComparer.Ordinal.Compare(promo.Text("startsAt"), tx.NowIso) > 0 ||
            promo.Text("endsAt") is { Length: > 0 } end && StringComparer.Ordinal.Compare(end, tx.NowIso) <= 0 ||
            promo["maxRedemptions"] is not null && promo.Number("redeemedCount") >= promo.Number("maxRedemptions")) throw new ServiceException("NOT_FOUND");
        var promoId = promo.Text("promoId")!; var kind = promo.Text("rewardType")!;
        var redemption = CanonicalWire.RowId("operation", "promo-redemption", user, promoId);
        var operation = CanonicalWire.RowId("operation", "promo-reward", user, promoId);
        promo["redeemedCount"] = promo.Number("redeemedCount") + 1;
        tx.Put("p_promo_codes", rowId, promo);
        tx.Put("p_promo_redemptions", CanonicalWire.RowId("p_promo_redemptions", user, promoId), new() {
            ["redemptionId"] = redemption, ["userId"] = user, ["promoId"] = promoId, ["rewardType"] = kind, ["rewardOperationId"] = operation, ["redeemedAt"] = tx.NowIso
        });
        EntitlementResponse? entitlement = null;
        if (kind == "SUPER_DAYS")
        {
            var current = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new JsonObject();
            var active = ProgressReads.EntitlementView(current, tx.Now).UnlimitedEnergy;
            var start = active && current.Text("expiresAt") is { Length: > 0 } expiry ? DateTimeOffset.Parse(expiry, CultureInfo.InvariantCulture) : tx.Now;
            entitlement = await ProgressBilling.ChangeEntitlementAsync(tx, user, new() { ["plan"] = active && current.Text("plan") == "MAX" ? "MAX" : "SUPER",
                ["source"] = active ? current.Text("source") : "PROMO", ["status"] = "ACTIVE", ["expiresAt"] = OwnerSchema.Iso(start.AddDays(promo.Number("superDays"))) }, ct);
        }
        else if (kind == "GEMS") await ProgressShop.CreditGemsAsync(tx, user, promo.Number("gems"), "ADJUST", operation, "promo", zone, ct);
        else await ProgressShop.AdjustInventoryAsync(tx, user, promo.Text("itemId")!, promo.Number("itemQuantity"), "GRANT", operation, 0, "promo", ct);
        return new(redemption, promoId, kind, kind == "SUPER_DAYS" ? promo.Number("superDays") : null, kind == "GEMS" ? promo.Number("gems") : null,
            kind == "ITEM" ? promo.Text("itemId") : null, kind == "ITEM" ? promo.Number("itemQuantity") : null, entitlement, tx.Now);
    }
}
