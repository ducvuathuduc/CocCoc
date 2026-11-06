using CocEnglish.Contracts;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed partial class ProgressSocial
{
    private static readonly IReadOnlyDictionary<string, string[]> Messages = new Dictionary<string, string[]>(StringComparer.Ordinal)
    {
        ["NUDGE"] = ["nudge.keep_going", "nudge.miss_you", "nudge.streak_risk"],
        ["HIGH_FIVE"] = ["high_five.nice", "high_five.great_job"],
        ["KUDOS"] = ["kudos.milestone", "kudos.league", "kudos.streak"],
        ["GIFT_BOOST"] = ["gift_boost.enjoy"],
        ["CONGRATS"] = ["congrats.streak", "congrats.league", "congrats.achievement"]
    };

    public async Task<InteractionResponse> InteractAsync(OwnerSession tx, string user, string target, string kind, string context, string message, string key, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        if (profile.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN");
        var zone = profile.Text("learningZone") ?? "UTC";
        var day = DayKey(ZonedDay(tx.Now, zone));
        if (!Messages.TryGetValue(kind, out var allowed) || !allowed.Contains(message, StringComparer.Ordinal)) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "messageKey" });
        if (target == user) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "targetUserId" });
        if (await Blocked(tx, user, target, ct)) throw new ServiceException("USER_BLOCKED");
        if (await VisibleAsync(tx, user, target, ct) is null) throw new ServiceException("PROFILE_UNAVAILABLE");
        var id = CanonicalWire.RowId("p_interactions", user, target, kind, context, day);
        var row = await tx.GetAsync("p_interactions", id, ct);
        var rewards = await tx.GetAsync("p_rewards", CanonicalWire.RowId("p_rewards", user), ct);
        var gems = rewards?.Number("gems") ?? 0;
        if (row is not null) return InteractionView(row, gems);
        var operation = CanonicalWire.RowId("operation", "interaction", user, key);
        var cost = kind == "GIFT_BOOST" ? 50 : 0;
        if (cost > 0)
        {
            gems = await ProgressShop.CreditGemsAsync(tx, user, -cost, "GIFT", operation, "gift_boost", zone, ct);
            tx.Put("p_boosts", CanonicalWire.RowId("p_boosts", target, operation), new()
            {
                ["userId"] = target, ["boostId"] = operation, ["kind"] = "XP_BOOST", ["multiplier"] = 2,
                ["startsAt"] = tx.NowIso, ["endsAt"] = OwnerSchema.Iso(tx.Now.AddMinutes(15)), ["sourceOperationId"] = operation
            });
        }
        row = new() { ["operationId"] = operation, ["fromUserId"] = user, ["toUserId"] = target, ["kind"] = kind,
            ["contextId"] = context, ["day"] = day, ["messageKey"] = message, ["gemsCost"] = cost };
        tx.Put("p_interactions", id, row);
        return InteractionView(row, gems);
    }

    private static InteractionResponse InteractionView(JsonObject row, long gems) => new(row.Text("operationId")!, row.Text("toUserId")!, row.Text("kind")!, row.Text("contextId")!, row.Text("day")!, row.Number("gemsCost"), gems);

    public async Task<string> OptInQuestAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        if (profile.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN");
        var week = LeagueWeek(tx.Now);
        var mine = await tx.ListAsync("p_quests", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["period"] = "WEEK", ["periodKey"] = week }, Limit: 10), ct);
        if (mine.Any(q => q.Data.Text("questId")?.StartsWith("friend_", StringComparison.Ordinal) == true)) return "replayed";
        var outgoing = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["fromUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        var incoming = await tx.ListAsync("p_follows", new(Where: new Dictionary<string, object?> { ["toUserId"] = user, ["status"] = "ACTIVE" }, Limit: 500), ct);
        var back = incoming.Select(r => r.Data.Text("fromUserId")).ToHashSet(StringComparer.Ordinal);
        foreach (var friend in outgoing.Select(r => r.Data.Text("toUserId")!).Where(back.Contains).Order(StringComparer.Ordinal))
        {
            if (await VisibleAsync(tx, user, friend, ct) is null) continue;
            var soloId = CanonicalWire.RowId("p_quests", friend, "WEEK", week, "friend_solo");
            var solo = await tx.GetAsync("p_quests", soloId, ct);
            if (solo is null || solo.Flag("claimed")) continue;
            var members = new[] { user, friend }.Order(StringComparer.Ordinal).ToArray();
            var pair = CanonicalWire.RowId("operation", "friend-pair", week, members[0], members[1])[..28];
            var count = solo.Number("metricValue");
            tx.Put("p_friend_quests", CanonicalWire.RowId("p_friend_quests", week, pair), new()
            {
                ["weekId"] = week, ["pairId"] = pair, ["templateId"] = "lessons10", ["userIdsJson"] = CanonicalWire.Stringify(new JsonArray(members.Select(m => (JsonNode?)JsonValue.Create(m)).ToArray())),
                ["target"] = 10, ["count"] = count, ["claimedUserIdsJson"] = "[]", ["membershipFrozenAt"] = tx.NowIso
            });
            tx.Delete("p_quests", soloId);
            foreach (var member in members) PutQuest(tx, member, week, "friend_" + pair, count);
            return "completed";
        }
        PutQuest(tx, user, week, "friend_solo", 0);
        return "completed";
    }

    private static void PutQuest(OwnerSession tx, string user, string week, string quest, long count) => tx.Put("p_quests", CanonicalWire.RowId("p_quests", user, "WEEK", week, quest), new()
    {
        ["userId"] = user, ["period"] = "WEEK", ["periodKey"] = week, ["questId"] = quest, ["metricValue"] = count,
        ["target"] = 10, ["claimed"] = false, ["claimOperationId"] = null
    });
}
