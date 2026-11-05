using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed class ProgressReferrals(ProgressCodes codes)
{
    public async Task<ReferralResponse> GetAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var code = codes.Derive("referral", user); var hash = ProgressCodes.Hash(code);
        var id = CanonicalWire.RowId("p_referrals", hash);
        if (await tx.GetAsync("p_referrals", id, ct) is null) tx.Put("p_referrals", id, new() { ["inviterId"] = user, ["inviteeId"] = null, ["codeHash"] = hash, ["status"] = "ISSUED", ["rewardOperationId"] = null });
        var rows = await tx.ListAsync("p_referrals", new(Where: new Dictionary<string, object?> { ["inviterId"] = user }, Limit: 500), ct);
        return new(code, rows.Count(r => r.Data.Text("status") is "ACCEPTED" or "QUALIFIED" or "REWARDED"),
            rows.Count(r => r.Data.Text("status") is "QUALIFIED" or "REWARDED"), rows.Count(r => r.Data.Text("status") == "REWARDED"), tx.Now);
    }

    public async Task<string> RedeemAsync(OwnerSession tx, string user, string code, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var hash = ProgressCodes.Hash(code);
        var existing = await tx.ListAsync("p_referrals", new(Where: new Dictionary<string, object?> { ["inviteeId"] = user }, Limit: 1), ct);
        if (existing.Count > 0) return "replayed";
        var index = await tx.ListAsync("p_referrals", new(Where: new Dictionary<string, object?> { ["codeHash"] = hash, ["status"] = "ISSUED" }, Limit: 1), ct);
        var issued = index.FirstOrDefault();
        if (issued is null || issued.Data.Text("inviterId") == user) throw new ServiceException("NOT_FOUND");
        var inviter = issued.Data.Text("inviterId")!;
        tx.Put("p_referrals", CanonicalWire.RowId("p_referrals", hash, user), new() {
            ["inviterId"] = inviter, ["inviteeId"] = user, ["codeHash"] = CanonicalWire.Sha256(hash + "|" + user), ["status"] = "REWARDED",
            ["rewardOperationId"] = CanonicalWire.RowId("operation", "referral", inviter, user)
        });
        foreach (var member in new[] { inviter, user })
        {
            var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", member), ct) ?? new JsonObject();
            if (ProgressReads.EntitlementView(entitlement, tx.Now).UnlimitedEnergy) continue;
            await ProgressBilling.ChangeEntitlementAsync(tx, member, new() { ["plan"] = "SUPER", ["source"] = "REFERRAL", ["status"] = "ACTIVE",
                ["expiresAt"] = OwnerSchema.Iso(tx.Now.AddDays(7)), ["autoRenew"] = false }, ct);
        }
        return "completed";
    }
}
