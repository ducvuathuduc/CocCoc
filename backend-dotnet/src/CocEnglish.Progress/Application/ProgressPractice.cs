using CocEnglish.Progress.Domain;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public static class ProgressPractice
{
    public static async Task ApplyAsync(OwnerSession tx, string eventId, DateTimeOffset occurred, JsonObject payload, CancellationToken ct)
    {
        var user = payload.Text("userId")!; var completion = payload.Text("completionId")!;
        if (await tx.GetAsync("p_deletions", CanonicalWire.RowId("p_deletions", user), ct) is not null) return;
        var ledger = CanonicalWire.RowId("p_reward_ledger", user, completion, "PRACTICE");
        if (await tx.GetAsync("p_reward_ledger", ledger, ct) is not null) return;
        var zone = await ProgressCompletionEffects.ZoneAtAsync(tx, user, occurred, ct);
        var day = DayKey(ZonedDay(occurred, zone)); var week = LeagueWeek(occurred); var dayId = CanonicalWire.RowId("p_day_activity", user, day);
        var oldDay = await tx.GetAsync("p_day_activity", dayId, ct);
        var prior = await tx.ListAsync("p_reward_ledger", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["learningDay"] = day, ["kind"] = "PRACTICE" },
            GreaterThanEqual: new Dictionary<string, object?> { ["studyXpDelta"] = 1 }, Limit: 100), ct);
        var practiceXp = prior.Sum(r => r.Data.Number("studyXpDelta"));
        var boost = await ProgressCompletionEffects.BoostAtAsync(tx, user, occurred, ct);
        var award = PracticePolicy.Award((int)payload.Number("xp"), (int)(oldDay?.Number("studyXp") ?? 0), (int)practiceXp, (int)boost);
        var identity = "practice-" + payload.Text("scenarioId");
        tx.Put("p_reward_ledger", ledger, new() { ["eventId"] = eventId, ["completionId"] = completion, ["userId"] = user,
            ["rewardIdentity"] = identity[..Math.Min(36, identity.Length)], ["kind"] = "PRACTICE", ["studyXpDelta"] = award.StudyXp, ["leagueXpDelta"] = award.LeagueXp,
            ["gemsDelta"] = 0, ["learningDay"] = day, ["leagueWeek"] = week, ["occurredAt"] = OwnerSchema.Iso(occurred), ["capped"] = award.Capped });
        var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", user), ct);
        var becameActive = oldDay is null || !oldDay.Flag("active"); var dayRow = oldDay ?? new JsonObject();
        dayRow["userId"] = user; dayRow["day"] = day; dayRow["zone"] = oldDay?.Text("zone") ?? zone;
        dayRow["active"] = true; dayRow["protected"] = oldDay?.Flag("protected") ?? false;
        dayRow["studyXp"] = (oldDay?.Number("studyXp") ?? 0) + award.StudyXp;
        foreach (var metric in new[] { "replayXp", "completedLessons", "originalCorrect", "trackedOriginalCount", "trackedOriginalCorrect", "reviewSessions", "minutesSpent" }) dayRow[metric] = oldDay?.Number(metric) ?? 0;
        dayRow["goalMet"] = dayRow.Number("studyXp") >= (profile?.Number("dailyGoal", 10) ?? 10); tx.Put("p_day_activity", dayId, dayRow);
        var rewardsId = CanonicalWire.RowId("p_rewards", user); var rewards = await tx.GetAsync("p_rewards", rewardsId, ct) ?? ProgressEconomy.EmptyRewards(user);
        rewards["studyXp"] = rewards.Number("studyXp") + award.StudyXp; rewards["leagueXpLifetime"] = rewards.Number("leagueXpLifetime") + award.LeagueXp;
        if (becameActive) { await ProgressCompletionEffects.AdvanceStreakAsync(tx, user, rewards, day, ct); await ProgressCompletionEffects.ExtendFriendStreaksAsync(tx, user, day, ct); }
        var visible = profile?.Flag("publicOptIn") == true && profile.Text("ageBand") != "CHILD";
        await ProgressCompletionEffects.GrantAchievementsAsync(tx, user, rewards, false, eventId, OwnerSchema.Iso(occurred), visible, ct);
        var streak = rewards.Number("currentStreak");
        if (becameActive && (streak is 7 or 30 or 100 or 365 || streak > 365 && streak % 365 == 0))
        {
            var id = CanonicalWire.RowId("operation", "streak", user, rewards.Text("streakStartDay")!, streak.ToString(System.Globalization.CultureInfo.InvariantCulture));
            tx.Put("p_activity", CanonicalWire.RowId("p_activity", id), new() { ["eventId"] = id, ["userId"] = user, ["kind"] = "STREAK", ["publicSummary"] = $"Reached a {streak}-day streak", ["visible"] = visible });
        }
        await ProgressCompletionEffects.BumpQuestsAsync(tx, user, day, 0, 0, 0, becameActive ? 1 : 0, ct);
        await ProgressCompletionEffects.AddLeagueXpAsync(tx, user, week, award.LeagueXp, OwnerSchema.Iso(occurred), ct);
        tx.Put("p_rewards", rewardsId, rewards);
        var staged = await tx.GetAsync("p_rewards", rewardsId, ct);
        tx.Put("p_notifications", CanonicalWire.RowId("p_notifications", user, completion), new() { ["userId"] = user, ["completionId"] = completion,
            ["status"] = "CREDITED", ["profileRevision"] = profile?.Number("revision") ?? 0, ["rewardRevision"] = staged?.Number("revision") ?? 0 }, [user]);
    }
}
