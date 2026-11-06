using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using System.Globalization;
using System.Text.Json.Nodes;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public static class ProgressCompletionEffects
{
    public static async Task GrantAchievementsAsync(OwnerSession tx, string user, JsonObject rewards, bool firstCompletion, string eventId, string occurredAt, bool visible, CancellationToken ct)
    {
        var lessons = await tx.CountAsync("p_first_rewards", new Dictionary<string, object?> { ["userId"] = user }, ct) + (firstCompletion ? 1 : 0);
        foreach (var (track, value, thresholds) in new (string Track, long Value, int[] Thresholds)[] {
            ("lessons", lessons, [5, 20, 50]), ("streak", rewards.Number("currentStreak"), [3, 7, 30]) })
        {
            for (var index = 0; index < thresholds.Length; index++)
            {
                if (value < thresholds[index]) continue;
                var tier = index + 1; var id = CanonicalWire.RowId("p_achievements", user, track, tier.ToString(CultureInfo.InvariantCulture));
                if (await tx.GetAsync("p_achievements", id, ct) is not null) continue;
                tx.Put("p_achievements", id, new() { ["userId"] = user, ["achievementId"] = track, ["tier"] = tier, ["earnedAt"] = occurredAt, ["sourceEventId"] = eventId });
                var summary = track == "lessons" ? $"Completed {thresholds[index]} lessons" : $"Reached a {thresholds[index]}-day streak";
                tx.Put("p_activity", CanonicalWire.RowId("p_activity", id), new() { ["eventId"] = id, ["userId"] = user, ["kind"] = "MILESTONE", ["publicSummary"] = summary, ["visible"] = visible });
            }
        }
    }

    public static async Task AdvanceFriendQuestAsync(OwnerSession tx, string user, string week, JsonObject rewards, CancellationToken ct)
    {
        var mine = await tx.ListAsync("p_quests", new(Where: new Dictionary<string, object?> { ["userId"] = user, ["period"] = "WEEK", ["periodKey"] = week }, Limit: 10), ct);
        var entry = mine.FirstOrDefault(r => r.Data.Text("questId")?.StartsWith("friend_", StringComparison.Ordinal) == true);
        if (entry is null || entry.Data.Flag("claimed")) return;
        var questId = entry.Data.Text("questId")!; var pairId = questId[7..];
        var pairRowId = CanonicalWire.RowId("p_friend_quests", week, pairId);
        var pair = pairId == "solo" ? null : await tx.GetAsync("p_friend_quests", pairRowId, ct);
        var members = pair is null ? new[] { user } : System.Text.Json.JsonSerializer.Deserialize<string[]>(pair.Text("userIdsJson")!)!;
        var count = (pair?.Number("count") ?? entry.Data.Number("metricValue")) + 1; var done = count >= 10;
        if (pair is not null)
        {
            if (System.Text.Json.JsonSerializer.Deserialize<string[]>(pair.Text("claimedUserIdsJson")!)!.Length > 0) return;
            pair["count"] = count; pair["claimedUserIdsJson"] = System.Text.Json.JsonSerializer.Serialize(done ? members : []);
            tx.Put("p_friend_quests", pairRowId, pair);
        }
        var operation = CanonicalWire.RowId("operation", "friend-quest", week, pairId == "solo" ? user : pairId);
        foreach (var member in members)
        {
            var id = CanonicalWire.RowId("p_quests", member, "WEEK", week, questId); var memberQuest = await tx.GetAsync("p_quests", id, ct);
            if (memberQuest is not null) { memberQuest["metricValue"] = count; memberQuest["claimed"] = done; memberQuest["claimOperationId"] = done ? operation : null; tx.Put("p_quests", id, memberQuest); }
            if (!done) continue;
            tx.Put("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", member, operation, "QUEST"), new() {
                ["eventId"] = CanonicalWire.RowId("operation", "friend-quest-ledger", operation, member), ["completionId"] = operation, ["userId"] = member,
                ["rewardIdentity"] = "lessons10", ["kind"] = "QUEST", ["studyXpDelta"] = 0, ["leagueXpDelta"] = 0, ["gemsDelta"] = 10,
                ["learningDay"] = week, ["leagueWeek"] = week, ["occurredAt"] = tx.NowIso, ["capped"] = false });
            if (member == user) rewards["gems"] = rewards.Number("gems") + 10;
            else
            {
                var rewardsId = CanonicalWire.RowId("p_rewards", member); var other = await tx.GetAsync("p_rewards", rewardsId, ct) ?? ProgressEconomy.EmptyRewards(member);
                other["gems"] = other.Number("gems") + 10; tx.Put("p_rewards", rewardsId, other);
            }
        }
    }

    public static async Task ExtendFriendStreaksAsync(OwnerSession tx, string user, string day, CancellationToken ct)
    {
        foreach (var column in new[] { "userAId", "userBId" })
        {
            var rows = await tx.ListAsync("p_friend_streaks", new(Where: new Dictionary<string, object?> { [column] = user, ["status"] = "ACTIVE" }, Limit: 10), ct);
            foreach (var document in rows)
            {
                var row = document.Data;
                if (row.Text("lastExtendedDay") == day) continue;
                var partner = row.Text("userAId") == user ? row.Text("userBId")! : row.Text("userAId")!;
                var partnerDay = await tx.GetAsync("p_day_activity", CanonicalWire.RowId("p_day_activity", partner, day), ct);
                if (partnerDay is null || !partnerDay.Flag("active")) continue;
                var consecutive = row.Text("lastExtendedDay") == DayKey(Day(day).AddDays(-1));
                row["length"] = consecutive ? row.Number("length") + 1 : 1;
                if (!consecutive) row["startDay"] = day;
                row["lastExtendedDay"] = day;
                tx.Put("p_friend_streaks", document.Id, row);
            }
        }
    }

    public static async Task AdvanceStreakAsync(OwnerSession tx, string user, JsonObject rewards, string day, CancellationToken ct)
    {
        var last = rewards.Text("lastQualifiedDay"); var current = rewards.Number("currentStreak");
        if (last == day) return;
        if (last is null || StringComparer.Ordinal.Compare(day, last) > 0)
        {
            if (last is not null && Day(last).AddDays(1) == Day(day)) rewards["currentStreak"] = current + 1;
            else
            {
                if (current > 0) { rewards["lostStreak"] = current; rewards["lostStreakDay"] = day; }
                rewards["currentStreak"] = 1; rewards["streakStartDay"] = day;
            }
            rewards["lastQualifiedDay"] = day;
        }
        else
        {
            var latest = Day(last); var start = latest.AddDays(-364); var startKey = DayKey(start);
            var rows = await tx.ListAsync("p_day_activity", new(Where: new Dictionary<string, object?> { ["userId"] = user },
                GreaterThanEqual: new Dictionary<string, object?> { ["day"] = startKey }, OrderBy: [new("day", true)], Limit: 365), ct);
            var qualified = rows.Where(r => r.Data.Flag("active") || r.Data.Flag("protected")).Select(r => r.Data.Text("day")!).ToHashSet(StringComparer.Ordinal);
            qualified.Add(day);
            var cursor = latest; var length = 0;
            while (qualified.Contains(DayKey(cursor)))
            {
                length++;
                if (cursor == start)
                {
                    if (rewards.Text("streakStartDay") is { } anchor && StringComparer.Ordinal.Compare(anchor, startKey) < 0)
                    { length = latest.DayNumber - Day(anchor).DayNumber + 1; rewards["currentStreak"] = length; rewards["bestStreak"] = Math.Max(rewards.Number("bestStreak"), length); return; }
                    break;
                }
                cursor = cursor.AddDays(-1);
            }
            rewards["currentStreak"] = length; rewards["streakStartDay"] = length > 0 ? DayKey(latest.AddDays(-(length - 1))) : null;
        }
        rewards["bestStreak"] = Math.Max(rewards.Number("bestStreak"), rewards.Number("currentStreak"));
    }

    public static async Task<string> ZoneAtAsync(OwnerSession tx, string user, DateTimeOffset instant, CancellationToken ct)
    {
        var rows = await tx.ListAsync("p_zone_history", new(Where: new Dictionary<string, object?> { ["userId"] = user },
            LessThan: new Dictionary<string, object?> { ["effectiveAt"] = OwnerSchema.Iso(instant.AddMilliseconds(1)) },
            OrderBy: [new("effectiveAt", true)], Limit: 1), ct);
        return rows.FirstOrDefault()?.Data.Text("zone") ?? "UTC";
    }

    public static async Task<long> BoostAtAsync(OwnerSession tx, string user, DateTimeOffset instant, CancellationToken ct)
    {
        var at = OwnerSchema.Iso(instant);
        var rows = await tx.ListAsync("p_boosts", new(Where: new Dictionary<string, object?> { ["userId"] = user },
            GreaterThanEqual: new Dictionary<string, object?> { ["endsAt"] = at }, OrderBy: [new("endsAt")], Limit: 20), ct);
        long multiplier = 1;
        foreach (var row in rows)
            if (row.Data.Text("kind") is "XP_BOOST" or "HAPPY_HOUR" && StringComparer.Ordinal.Compare(row.Data.Text("startsAt"), at) <= 0 && StringComparer.Ordinal.Compare(at, row.Data.Text("endsAt")) < 0)
                multiplier = Math.Max(multiplier, row.Data.Number("multiplier", 1));
        return multiplier;
    }

    public static async Task BumpQuestsAsync(OwnerSession tx, string user, string day, long lessons, long originalCorrect, long reviewSessions, long activeDays, CancellationToken ct)
    {
        var quests = new (string Id, string Period, long Target, long Delta)[] {
            ("daily_lessons", "DAY", 2, lessons), ("daily_correct", "DAY", 15, originalCorrect),
            ("daily_review", "DAY", 1, reviewSessions), ("monthly_active_days", "MONTH", 20, activeDays)
        };
        foreach (var (quest, period, target, delta) in quests)
        {
            if (delta == 0) continue;
            var periodKey = period == "DAY" ? day : day[..7];
            var id = CanonicalWire.RowId("p_quests", user, period, periodKey, quest);
            var row = await tx.GetAsync("p_quests", id, ct) ?? new();
            row["userId"] = user; row["period"] = period; row["periodKey"] = periodKey; row["questId"] = quest;
            row["metricValue"] = row.Number("metricValue") + delta; row["target"] = target;
            row["claimed"] = row.Flag("claimed"); row["claimOperationId"] = row.Text("claimOperationId");
            tx.Put("p_quests", id, row);
        }
    }

    public static async Task AddLeagueXpAsync(OwnerSession tx, string user, string week, long xp, string occurredAt, CancellationToken ct)
    {
        if (xp <= 0) return;
        var id = CanonicalWire.RowId("p_league_members", week, user);
        var member = await tx.GetAsync("p_league_members", id, ct);
        if (member is null || member.Flag("settled") || member.Flag("excluded")) return;
        var previous = member.Text("lastXpAt");
        if (!DateTimeOffset.TryParse(previous, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var last) ||
            !DateTimeOffset.TryParse(occurredAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var occurred) || last <= occurred)
            member["lastXpAt"] = occurredAt;
        member["eligibleXp"] = member.Number("eligibleXp") + xp;
        tx.Put("p_league_members", id, member);
    }
}
