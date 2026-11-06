using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using CocEnglish.Progress.Domain;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Globalization;
using System.Text.RegularExpressions;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressEconomy
{
    private readonly Func<string> newChestOperation;
    public ProgressEconomy() : this(QuestChestPolicy.NewOperation) { }
    internal ProgressEconomy(Func<string> newChestOperation) => this.newChestOperation = newChestOperation;
    public async Task<RewardsResponse> BuyFreezeAsync(OwnerSession tx, string userId, string key, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, userId, ct);
        var zone = profile.Text("learningZone") ?? "UTC";
        var id = CanonicalWire.RowId("p_rewards", userId);
        var rewards = await tx.GetAsync("p_rewards", id, ct) ?? EmptyRewards(userId);
        var revision = rewards.Number("revision", -1) + 1;
        var slots = rewards.Number("freezeSlots");
        if (slots >= ProgressCatalog.FreezeCapacity(rewards.Number("currentStreak"))) throw new ServiceException("FREEZE_CAPACITY", new() { ["freezeSlots"] = slots });
        if (rewards.Number("gems") < 20) throw new ServiceException("INSUFFICIENT_GEMS", new() { ["required"] = 20 });
        var operation = CanonicalWire.RowId("operation", "freeze-buy", userId, key);
        rewards["gems"] = rewards.Number("gems") - 20;
        rewards["freezeSlots"] = slots + 1;
        tx.Put("p_freeze_ledger", CanonicalWire.RowId("p_freeze_ledger", userId, operation), new()
        {
            ["userId"] = userId, ["operationId"] = operation, ["action"] = "BUY", ["day"] = null, ["gemsDelta"] = -20, ["slotDelta"] = 1
        });
        PutLedger(tx, userId, operation, "FREEZE", "streak_freeze", -20, zone);
        tx.Put("p_rewards", id, rewards);
        rewards["revision"] = revision;
        return ProgressReads.RewardsView(tx.Now, zone, rewards);
    }

    public async Task<RewardsResponse> ClaimQuestAsync(OwnerSession tx, string userId, string questId, string periodKey, bool upgradeChest, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, userId, ct);
        var zone = profile.Text("learningZone") ?? "UTC";
        var quest = ProgressCatalog.Quests.FirstOrDefault(q => q.Id == questId) ?? throw new ServiceException("NOT_FOUND");
        if (!Regex.IsMatch(periodKey, quest.Period == "DAY" ? "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" : "^[0-9]{4}-[0-9]{2}$", RegexOptions.CultureInvariant))
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "periodKey" });
        var id = CanonicalWire.RowId("p_quests", userId, quest.Period, periodKey, questId);
        var row = await tx.GetAsync("p_quests", id, ct);
        var rewardsId = CanonicalWire.RowId("p_rewards", userId);
        var rewards = await tx.GetAsync("p_rewards", rewardsId, ct) ?? EmptyRewards(userId);
        if (row?.Flag("claimed") == true)
        {
            var prior = row.Text("claimOperationId") ?? "";
            var result = ProgressReads.RewardsView(tx.Now, zone, rewards);
            if (!prior.StartsWith("ch1_", StringComparison.Ordinal)) return result;
            var chest = QuestChestPolicy.Receipt(prior, 1);
            var ledger = await tx.GetAsync("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", userId, prior, "QUEST"), ct);
            var credit = ledger?["gemsDelta"];
            if (chest is null || ledger is null || ledger.Text("eventId") != prior || ledger.Text("completionId") != prior ||
                ledger.Text("userId") != userId || ledger.Text("rewardIdentity") != questId || ledger.Text("kind") != "QUEST" ||
                credit?.GetValueKind() != JsonValueKind.Number || !double.TryParse(credit.ToJsonString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var gems) ||
                !double.IsFinite(gems) || Math.Truncate(gems) != gems || gems <= 0 || gems > 9007199254740991)
                throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "CHEST_LEDGER_MISSING_OR_INVALID" });
            return result with { Chest = chest with { Gems = (long)gems } };
        }
        if (row is null || row.Number("metricValue") < quest.Target)
            throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = "QUEST_NOT_COMPLETE", ["questId"] = questId, ["periodKey"] = periodKey });
        var operation = upgradeChest && quest.Gems > 0 ? newChestOperation() : CanonicalWire.RowId("operation", "quest-claim", userId, quest.Period, periodKey, questId);
        var outcome = QuestChestPolicy.Receipt(operation, quest.Gems);
        var rewardGems = outcome?.Gems ?? quest.Gems;
        row["claimed"] = true; row["claimOperationId"] = operation;
        tx.Put("p_quests", id, row);
        var revision = rewards.Number("revision", -1) + 1;
        if (quest.Gems > 0)
        {
            PutLedger(tx, userId, operation, "QUEST", questId, rewardGems, zone);
            rewards["gems"] = rewards.Number("gems") + rewardGems;
        }
        if (quest.Badge)
        {
            var badge = "monthly_" + periodKey.Replace('-', '_');
            var badgeId = CanonicalWire.RowId("p_achievements", userId, badge, "0");
            if (await tx.GetAsync("p_achievements", badgeId, ct) is null)
                tx.Put("p_achievements", badgeId, new() { ["userId"] = userId, ["achievementId"] = badge, ["tier"] = 0, ["earnedAt"] = tx.NowIso, ["sourceEventId"] = operation });
        }
        tx.Put("p_activity", CanonicalWire.RowId("p_activity", operation), new()
        {
            ["eventId"] = operation, ["userId"] = userId, ["kind"] = "QUEST", ["publicSummary"] = "Completed the " + questId.Replace('_', ' ') + " quest",
            ["visible"] = profile.Flag("publicOptIn") && profile.Text("ageBand") != "CHILD"
        });
        tx.Put("p_rewards", rewardsId, rewards);
        rewards["revision"] = revision;
        return ProgressReads.RewardsView(tx.Now, zone, rewards) with { Chest = outcome };
    }

    private static void PutLedger(OwnerSession tx, string userId, string operation, string kind, string identity, long gems, string zone) =>
        tx.Put("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", userId, operation, kind), new()
        {
            ["eventId"] = operation, ["completionId"] = operation, ["userId"] = userId, ["rewardIdentity"] = identity, ["kind"] = kind,
            ["studyXpDelta"] = 0, ["leagueXpDelta"] = 0, ["gemsDelta"] = gems, ["learningDay"] = DayKey(ZonedDay(tx.Now, zone)),
            ["leagueWeek"] = LeagueWeek(tx.Now), ["occurredAt"] = tx.NowIso, ["capped"] = false
        });

    internal static JsonObject EmptyRewards(string userId) => new()
    {
        ["userId"] = userId, ["studyXp"] = 0, ["leagueXpLifetime"] = 0, ["gems"] = 0, ["freezeSlots"] = 0,
        ["currentStreak"] = 0, ["bestStreak"] = 0, ["streakStartDay"] = null, ["lastQualifiedDay"] = null,
        ["lostStreak"] = 0, ["lostStreakDay"] = null, ["streakGoal"] = 0, ["streakGoalStartDay"] = null
    };
}
