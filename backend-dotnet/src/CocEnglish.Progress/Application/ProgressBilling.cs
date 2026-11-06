using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Globalization;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed partial class ProgressBilling
{
    public async Task<PurchaseResponse> GetPurchaseAsync(OwnerSession tx, string user, string purchase, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var row = await tx.GetAsync("p_purchases", CanonicalWire.RowId("p_purchases", purchase), ct);
        if (row is null || row.Text("userId") != user) throw new ServiceException("NOT_FOUND");
        var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new JsonObject();
        return new(row.Text("purchaseId")!, row.Text("productId")!, row.Text("kind")!, "SIMULATION", row.Text("state")!,
            row.Text("verifiedAt") is { } date ? DateTimeOffset.Parse(date, CultureInfo.InvariantCulture) : null, null, ProgressReads.EntitlementView(entitlement, tx.Now));
    }

    public async Task<EntitlementResponse> CancelAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_entitlements", user);
        var current = await tx.GetAsync("p_entitlements", id, ct);
        var entitlement = ProgressReads.EntitlementView(current ?? new(), tx.Now);
        if (current?.Text("purchaseId") is not { Length: > 0 } purchaseId || !entitlement.UnlimitedEnergy) return entitlement;
        var purchaseRowId = CanonicalWire.RowId("p_purchases", purchaseId);
        var purchase = await tx.GetAsync("p_purchases", purchaseRowId, ct);
        if (purchase is null || purchase.Text("userId") != user || purchase.Text("platform") != "SIMULATION") throw new ServiceException("NOT_FOUND");
        if (purchase.Text("state") == "CANCELED") return entitlement;
        purchase["state"] = "CANCELED";
        purchase["vendorStateJson"] = CanonicalWire.Stringify(new JsonObject { ["simulation"] = true, ["lastOccurredAt"] = tx.NowIso });
        tx.Put("p_purchases", purchaseRowId, purchase);
        var revision = current.Number("revision") + 1;
        current["status"] = "CANCELED"; current["autoRenew"] = false;
        tx.Put("p_entitlements", id, current);
        ProgressWrites.EnqueueEvent(tx, "entitlement.changed.v1", user, new()
        {
            ["userId"] = user, ["plan"] = current.Text("plan"), ["status"] = "CANCELED", ["expiresAt"] = current.Text("expiresAt"), ["entitlementRevision"] = revision
        });
        return ProgressReads.EntitlementView(current, tx.Now) with { Revision = revision };
    }
}
