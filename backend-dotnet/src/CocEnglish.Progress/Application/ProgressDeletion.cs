using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json;

namespace CocEnglish.Progress.Application;

public sealed class ProgressDeletion(OwnerStore store)
{
    private static readonly (string Table, string Column)[] Plan = [
        ("p_profiles", "userId"), ("p_zone_history", "userId"), ("p_rewards", "userId"), ("p_reward_ledger", "userId"),
        ("p_first_rewards", "userId"), ("p_day_activity", "userId"), ("p_freeze_ledger", "userId"), ("p_quests", "userId"),
        ("p_follows", "fromUserId"), ("p_follows", "toUserId"), ("p_blocks", "blockerId"), ("p_blocks", "blockedId"),
        ("p_league_members", "userId"), ("p_league_profiles", "userId"), ("p_activity", "userId"), ("p_achievements", "userId"),
        ("p_notifications", "userId"), ("p_receipts", "userId"), ("p_preferences", "userId"), ("p_inventory", "userId"),
        ("p_item_ledger", "userId"), ("p_boosts", "userId"), ("p_entitlements", "userId"), ("p_ad_events", "userId"),
        ("p_promo_redemptions", "userId"), ("p_year_reviews", "userId"), ("p_feedback", "userId"), ("p_classroom_members", "userId")
    ];
    public async Task RecordAckAsync(OwnerSession tx, string user, string request, string owner, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_deletions", user); var deletion = await tx.GetAsync("p_deletions", id, ct);
        if (deletion is null || deletion.Text("requestId") != request) return;
        var acks = (JsonSerializer.Deserialize<string[]>(deletion.Text("ownerAcksJson") ?? "[]") ?? []).ToHashSet(StringComparer.Ordinal);
        acks.Add(owner);
        if (deletion.Text("status") != "COMPLETED" && acks.Contains("learning") && acks.Contains("ai")) deletion["status"] = "PURGING";
        deletion["ownerAcksJson"] = JsonSerializer.Serialize(acks.Order(StringComparer.Ordinal));
        tx.Put("p_deletions", id, deletion);
    }
    public async Task<bool> PurgeAsync(string user, int maxBatches, CancellationToken ct)
    {
        var id = CanonicalWire.RowId("p_deletions", user);
        for (var batch = 0; batch < maxBatches; batch++)
        {
            var done = await store.TransactAsync(async (tx, token) => {
                var deletion = await tx.GetAsync("p_deletions", id, token);
                if (deletion is null || deletion.Text("status") != "PURGING") return true;
                var budget = 80;
                foreach (var (table, column) in Plan)
                {
                    if (budget <= 0) return false;
                    var rows = await tx.ListAsync(table, new(Where: new Dictionary<string, object?> { [column] = user }, Limit: budget), token);
                    foreach (var row in rows) tx.Delete(table, row.Id);
                    budget -= rows.Count;
                }
                if (budget <= 0) return false;
                deletion["status"] = "COMPLETED"; deletion["completedAt"] = tx.NowIso; tx.Put("p_deletions", id, deletion);
                return true;
            }, ct);
            if (done) return await store.TransactAsync(async (tx, token) => (await tx.GetAsync("p_deletions", id, token))?.Text("status") == "COMPLETED", ct);
        }
        return false;
    }
}
