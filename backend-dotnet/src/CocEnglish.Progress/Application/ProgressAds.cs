using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressAds
{
    public async Task<AdResponse> RecordAsync(OwnerSession tx, string user, string ad, string placement, string kind, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct); var zone = profile.Text("learningZone") ?? "UTC";
        if (placement is not ("LESSON_END_INTERSTITIAL" or "REWARDED_GEMS" or "REWARDED_ENERGY_REFILL")) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "placement" });
        var rewarded = kind == "REWARDED_COMPLETION";
        var cap = rewarded ? placement == "LESSON_END_INTERSTITIAL" ? 0 : 5 : 20;
        var id = CanonicalWire.RowId("p_ad_events", ad); var rewardsId = CanonicalWire.RowId("p_rewards", user);
        var existing = await tx.GetAsync("p_ad_events", id, ct);
        var rewards = await tx.GetAsync("p_rewards", rewardsId, ct) ?? ProgressEconomy.EmptyRewards(user);
        if (existing is not null)
        {
            if (existing.Text("userId") != user || existing.Text("placement") != placement || existing.Text("kind") != kind) throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["field"] = "adEventId" });
            return View(existing, cap, rewards.Number("gems"), false);
        }
        var entitlement = await tx.GetAsync("p_entitlements", CanonicalWire.RowId("p_entitlements", user), ct) ?? new JsonObject();
        if (ProgressReads.EntitlementView(entitlement, tx.Now).UnlimitedEnergy) throw new ServiceException("AD_NOT_ELIGIBLE");
        if (rewarded && cap == 0) throw new ServiceException("AD_NOT_ELIGIBLE", new() { ["reason"] = "PLACEMENT_HAS_NO_REWARD" });
        var day = DayKey(ZonedDay(tx.Now, zone));
        var today = await tx.ListAsync("p_ad_events", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["learningDay"] = day, ["placement"] = placement, ["kind"] = kind }, Limit: 50), ct);
        var index = today.Count + 1;
        if (index > cap) throw new ServiceException("AD_DAILY_CAP", new() { ["cap"] = cap });
        var operation = rewarded ? CanonicalWire.RowId("operation", "ad-reward", user, ad) : null;
        tx.Put("p_rewards", rewardsId, rewards);
        var gems = rewards.Number("gems"); var gemReward = rewarded && placement == "REWARDED_GEMS" ? 5 : 0;
        var energyReward = rewarded && placement == "REWARDED_ENERGY_REFILL" ? 25 : 0;
        if (gemReward > 0) gems = await ProgressShop.CreditGemsAsync(tx, user, gemReward, "ADJUST", operation!, "ad", zone, ct);
        if (energyReward > 0) ProgressWrites.EnqueueEvent(tx, "energy.granted.v1", user, new() { ["operationId"] = operation, ["userId"] = user, ["amount"] = energyReward, ["refillToCapacity"] = false, ["reason"] = "AD" });
        var row = new JsonObject { ["adEventId"] = ad, ["userId"] = user, ["placement"] = placement, ["kind"] = kind, ["learningDay"] = day, ["dailyIndex"] = index,
            ["rewardGems"] = gemReward, ["rewardEnergy"] = energyReward, ["rewardOperationId"] = operation, ["occurredAt"] = tx.NowIso };
        tx.Put("p_ad_events", id, row);
        return View(row, cap, gems, energyReward > 0);
    }
    private static AdResponse View(JsonObject row, long cap, long gems, bool pending) => new(row.Text("adEventId")!, row.Text("placement")!, row.Text("kind")!, row.Text("learningDay")!,
        row.Number("dailyIndex"), Math.Max(0, cap - row.Number("dailyIndex")), row.Number("rewardGems"), row.Number("rewardEnergy"), gems, pending);
}
