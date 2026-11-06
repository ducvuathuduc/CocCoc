using CocEnglish.Progress.Domain;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public static class ProgressLesson
{
    public static async Task ApplyAsync(OwnerSession tx, string eventId, DateTimeOffset occurred, JsonObject payload, CancellationToken ct)
    {
        var user = payload.Text("userId")!; var completion = payload.Text("completionId")!; var identity = payload.Text("rewardIdentity")!;
        if (await tx.GetAsync("p_deletions", CanonicalWire.RowId("p_deletions", user), ct) is not null) return;
        foreach (var kind in new[] { "FIRST", "REPLAY" }) if (await tx.GetAsync("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", user, completion, kind), ct) is not null) return;
        var zone = await ProgressCompletionEffects.ZoneAtAsync(tx, user, occurred, ct); var day = DayKey(ZonedDay(occurred, zone)); var week = LeagueWeek(occurred);
        var mode = payload.Text("mode")!; var markerId = CanonicalWire.RowId("p_first_rewards", user, identity);
        var formula = mode is "LESSON" or "STORIES" or "ADVENTURE" or "RADIO" or "SIDE_QUEST" or "CLASH";
        var marker = formula ? await tx.GetAsync("p_first_rewards", markerId, ct) : null;
        var dayId = CanonicalWire.RowId("p_day_activity", user, day); var old = await tx.GetAsync("p_day_activity", dayId, ct);
        var boost = await ProgressCompletionEffects.BoostAtAsync(tx, user, occurred, ct);
        var award = LessonPolicy.Award(mode, payload.Text("source")!, (int)payload.Number("originalCount"), (int)payload.Number("originalCorrect"), payload.Flag("assisted"),
            formula && marker is null, (int)(old?.Number("studyXp") ?? 0), (int)(old?.Number("replayXp") ?? 0), (int)boost);
        if (award.Error is not null) throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = award.Error });
        if (award.Kind is null) return;
        tx.Put("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", user, completion, award.Kind), new() { ["eventId"] = eventId, ["completionId"] = completion, ["userId"] = user,
            ["rewardIdentity"] = identity, ["kind"] = award.Kind, ["studyXpDelta"] = award.StudyXp, ["leagueXpDelta"] = award.LeagueXp, ["gemsDelta"] = 0,
            ["learningDay"] = day, ["leagueWeek"] = week, ["occurredAt"] = OwnerSchema.Iso(occurred), ["capped"] = award.Capped });
        if (award.Kind == "FIRST") tx.Put("p_first_rewards", markerId, new() { ["userId"] = user, ["rewardIdentity"] = identity, ["completionId"] = completion });
        var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", user), ct); var becameActive = old is null || !old.Flag("active");
        var row = old ?? new JsonObject(); row["userId"] = user; row["day"] = day; row["zone"] = old?.Text("zone") ?? zone; row["active"] = true; row["protected"] = old?.Flag("protected") ?? false;
        row["studyXp"] = row.Number("studyXp") + award.StudyXp; row["replayXp"] = row.Number("replayXp") + award.ReplayXp;
        row["completedLessons"] = row.Number("completedLessons") + (mode == "LESSON" ? 1 : 0);
        row["originalCorrect"] = row.Number("originalCorrect") + (mode == "LESSON" ? payload.Number("originalCorrect") : 0);
        row["reviewSessions"] = row.Number("reviewSessions") + (mode == "REVIEW" ? 1 : 0);
        row["trackedOriginalCount"] = row.Number("trackedOriginalCount") + (mode == "LESSON" ? payload.Number("originalCount") : 0);
        row["trackedOriginalCorrect"] = row.Number("trackedOriginalCorrect") + (mode == "LESSON" ? payload.Number("originalCorrect") : 0);
        row["minutesSpent"] = row.Number("minutesSpent");
        row["goalMet"] = row.Number("studyXp") >= (profile?.Number("dailyGoal", 10) ?? 10); tx.Put("p_day_activity", dayId, row);
        var rewardsId = CanonicalWire.RowId("p_rewards", user); var rewards = await tx.GetAsync("p_rewards", rewardsId, ct) ?? ProgressEconomy.EmptyRewards(user);
        rewards["studyXp"] = rewards.Number("studyXp") + award.StudyXp; rewards["leagueXpLifetime"] = rewards.Number("leagueXpLifetime") + award.LeagueXp;
        if (becameActive) { await ProgressCompletionEffects.AdvanceStreakAsync(tx, user, rewards, day, ct); await ProgressCompletionEffects.ExtendFriendStreaksAsync(tx, user, day, ct); }
        var visible = profile?.Flag("publicOptIn") == true && profile.Text("ageBand") != "CHILD";
        await ProgressCompletionEffects.GrantAchievementsAsync(tx, user, rewards, award.Kind == "FIRST", eventId, OwnerSchema.Iso(occurred), visible, ct);
        var streak = rewards.Number("currentStreak");
        if (becameActive && (streak is 7 or 30 or 100 or 365 || streak > 365 && streak % 365 == 0))
        {
            var id = CanonicalWire.RowId("operation", "streak", user, rewards.Text("streakStartDay")!, streak.ToString(System.Globalization.CultureInfo.InvariantCulture));
            tx.Put("p_activity", CanonicalWire.RowId("p_activity", id), new() { ["eventId"] = id, ["userId"] = user, ["kind"] = "STREAK", ["publicSummary"] = $"Reached a {streak}-day streak", ["visible"] = visible });
        }
        await ProgressCompletionEffects.BumpQuestsAsync(tx, user, day, mode == "LESSON" ? 1 : 0, mode == "LESSON" ? payload.Number("originalCorrect") : 0, mode == "REVIEW" ? 1 : 0, becameActive ? 1 : 0, ct);
        if (mode == "LESSON") await ProgressCompletionEffects.AdvanceFriendQuestAsync(tx, user, week, rewards, ct);
        await ProgressCompletionEffects.AddLeagueXpAsync(tx, user, week, award.LeagueXp, OwnerSchema.Iso(occurred), ct);
        tx.Put("p_rewards", rewardsId, rewards); var staged = await tx.GetAsync("p_rewards", rewardsId, ct);
        tx.Put("p_notifications", CanonicalWire.RowId("p_notifications", user, completion), new() { ["userId"] = user, ["completionId"] = completion,
            ["status"] = "CREDITED", ["profileRevision"] = profile?.Number("revision") ?? 0, ["rewardRevision"] = staged?.Number("revision") ?? 0 }, [user]);
    }
}
