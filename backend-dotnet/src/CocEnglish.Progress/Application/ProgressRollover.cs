using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed record MissedDayResult(IReadOnlyList<string> ProtectedDays, long? LostStreak);
public sealed class ProgressRollover
{
    public async Task<MissedDayResult> ProcessAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        var protectedDays = new List<string>(); long? lost = null;
        var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", user), ct);
        if (profile is null || profile.Text("deletedAt") is { Length: > 0 }) return new(protectedDays, null);
        var zone = profile.Text("learningZone") ?? "UTC"; var id = CanonicalWire.RowId("p_rewards", user);
        var rewards = await tx.GetAsync("p_rewards", id, ct);
        if (rewards is null || rewards.Text("lastQualifiedDay") is not { Length: > 0 } last || rewards.Number("currentStreak") == 0) return new(protectedDays, null);
        var yesterday = ZonedDay(tx.Now, zone).AddDays(-1); var changed = false;
        for (var day = Day(last).AddDays(1); day <= yesterday && day.DayNumber - Day(last).DayNumber <= 400; day = day.AddDays(1))
        {
            var key = DayKey(day); var dayId = CanonicalWire.RowId("p_day_activity", user, key); var activity = await tx.GetAsync("p_day_activity", dayId, ct);
            if (activity is not null && (activity.Flag("active") || activity.Flag("protected"))) { rewards["lastQualifiedDay"] = key; continue; }
            var operation = CanonicalWire.RowId("operation", "freeze-consume", user, key); var ledgerId = CanonicalWire.RowId("p_freeze_ledger", user, operation);
            var slots = rewards.Number("freezeSlots");
            if (slots > 0 && await tx.GetAsync("p_freeze_ledger", ledgerId, ct) is null)
            {
                tx.Put("p_freeze_ledger", ledgerId, new() { ["userId"] = user, ["operationId"] = operation, ["action"] = "CONSUME", ["day"] = key, ["gemsDelta"] = 0, ["slotDelta"] = -1 });
                activity ??= new JsonObject();
                activity["userId"] = user; activity["day"] = key; activity["zone"] = zone; activity["active"] = activity.Flag("active"); activity["protected"] = true;
                foreach (var metric in new[] { "studyXp", "replayXp", "completedLessons", "originalCorrect", "reviewSessions", "minutesSpent" }) activity[metric] = activity.Number(metric);
                activity["goalMet"] = activity.Flag("goalMet"); tx.Put("p_day_activity", dayId, activity);
                rewards["freezeSlots"] = slots - 1; rewards["currentStreak"] = rewards.Number("currentStreak") + 1;
                rewards["bestStreak"] = Math.Max(rewards.Number("bestStreak"), rewards.Number("currentStreak")); rewards["lastQualifiedDay"] = key;
                protectedDays.Add(key); changed = true; continue;
            }
            lost = rewards.Number("currentStreak"); rewards["lostStreak"] = lost; rewards["lostStreakDay"] = key;
            rewards["currentStreak"] = 0; rewards["streakStartDay"] = null; changed = true; break;
        }
        if (changed || rewards.Text("lastQualifiedDay") != last) tx.Put("p_rewards", id, rewards);
        return new(protectedDays, lost);
    }
}
