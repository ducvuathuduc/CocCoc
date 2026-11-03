using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using System.Globalization;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public interface IProgressReads
{
    Task<ProfileResponse> GetMeAsync(string userId, CancellationToken ct);
    Task<RewardsResponse> GetRewardsAsync(string userId, string? completionId, CancellationToken ct);
    Task<LearningStatsResponse> GetLearningStatsAsync(string userId, CancellationToken ct);
    Task<QuestPageResponse> GetQuestsAsync(string userId, int offset, int limit, CancellationToken ct);
    Task<PreferencesResponse> GetPreferencesAsync(string userId, CancellationToken ct);
}

public sealed class ProgressReads(OwnerStore store) : IProgressReads
{
    public Task<PreferencesResponse> GetPreferencesAsync(string userId, CancellationToken ct) => store.TransactAsync(async (tx, token) =>
    {
        await RequireProfile(tx, userId, token);
        var row = await tx.GetAsync("p_preferences", CanonicalWire.RowId("p_preferences", userId), token) ?? ProgressWrites.DefaultPreferences(userId);
        return ProgressWrites.PreferencesView(row, tx.Now);
    }, ct);

    public Task<QuestPageResponse> GetQuestsAsync(string userId, int offset, int limit, CancellationToken ct) => store.TransactAsync(async (tx, token) =>
    {
        var profile = await RequireProfile(tx, userId, token);
        var today = DayKey(ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC"));
        var templates = new (string Id, string Period, long Target, long Gems)[]
        {
            ("daily_lessons", "DAY", 2, 5), ("daily_correct", "DAY", 15, 5),
            ("daily_review", "DAY", 1, 5), ("monthly_active_days", "MONTH", 20, 0)
        };
        var items = new List<QuestResponse>();
        foreach (var template in templates)
        {
            var periodKey = template.Period == "DAY" ? today : today[..7];
            var row = await tx.GetAsync("p_quests", CanonicalWire.RowId("p_quests", userId, template.Period, periodKey, template.Id), token) ?? new JsonObject();
            items.Add(new(template.Id, template.Period, periodKey, template.Target, row.Number("metricValue"), row.Flag("claimed"), template.Gems));
        }
        var utcDate = DateOnly.FromDateTime(tx.Now.UtcDateTime);
        var week = DayKey(utcDate.AddDays(-(((int)utcDate.DayOfWeek + 6) % 7)));
        var weekly = await tx.ListAsync("p_quests", new(Where: new Dictionary<string, object?>
            { ["userId"] = userId, ["period"] = "WEEK", ["periodKey"] = week }, Limit: 10), token);
        foreach (var document in weekly)
        {
            var row = document.Data;
            if (row.Text("questId") is not { } id || !id.StartsWith("friend_", StringComparison.Ordinal)) continue;
            items.Add(new(id, "WEEK", week, row.Number("target"), row.Number("metricValue"), row.Flag("claimed"), 10));
        }
        return new QuestPageResponse(items.Skip(offset).Take(limit).ToArray(), items.Count > offset + limit
            ? Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"o\":{offset + limit}}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_') : null, tx.Now);
    }, ct);

    public Task<ProfileResponse> GetMeAsync(string userId, CancellationToken ct) => store.TransactAsync(async (tx, token) =>
    {
        var profile = await RequireProfile(tx, userId, token);
        return await ProfileView(tx, profile, token);
    }, ct);

    internal static async Task<ProfileResponse> ProfileView(OwnerSession tx, JsonObject profile, CancellationToken ct)
    {
        PromoteZone(profile, tx.Now);
        var achievements = await tx.ListAsync("p_achievements", new(Where: User(profile.Text("userId")!), OrderBy: [new("earnedAt")], Limit: 200), ct);
        return new ProfileResponse(profile.Text("userId")!, profile.Text("nickname")!, profile.Text("avatarId"), profile.Flag("publicOptIn"),
            (int)profile.Number("dailyGoal"), profile.Text("learningZone")!, profile.Text("pendingZone"),
            profile.Text("zoneEffectiveAt") is { } effective ? DateTimeOffset.Parse(effective, CultureInfo.InvariantCulture) : null,
            profile.Number("revision"), achievements.Select(a => a.Data.Text("achievementId")!).Distinct(StringComparer.Ordinal).Take(30).ToArray());
    }

    public Task<RewardsResponse> GetRewardsAsync(string userId, string? completionId, CancellationToken ct) => store.TransactAsync(async (tx, token) =>
    {
        var profile = await RequireProfile(tx, userId, token);
        var rewards = await tx.GetAsync("p_rewards", CanonicalWire.RowId("p_rewards", userId), token) ?? new JsonObject();
        JsonObject? ledger = null;
        if (completionId is not null)
            foreach (var kind in new[] { "FIRST", "REPLAY", "PRACTICE" })
            {
                ledger = await tx.GetAsync("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", userId, completionId, kind), token);
                if (ledger is not null) break;
            }
        var shownStreak = 0L;
        if (rewards.Text("lastQualifiedDay") is { } last)
        {
            var gap = ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC").DayNumber - Day(last).DayNumber;
            if (gap <= 1 || gap - 1 <= Math.Min(rewards.Number("freezeSlots"), 7)) shownStreak = rewards.Number("currentStreak");
        }
        return new RewardsResponse(completionId, completionId is null ? "credited" : ledger is null ? "pending" : ledger.Flag("capped") ? "capped" : "credited",
            rewards.Number("studyXp"), rewards.Number("leagueXpLifetime"), rewards.Number("gems"), rewards.Number("freezeSlots"), shownStreak,
            ledger is null ? null : ledger.Number("studyXpDelta"), rewards.Number("revision"), tx.Now);
    }, ct);

    public Task<LearningStatsResponse> GetLearningStatsAsync(string userId, CancellationToken ct) => store.TransactAsync(async (tx, token) =>
    {
        await RequireProfile(tx, userId, token);
        var history = await tx.ListAsync("p_zone_history", new(Where: User(userId),
            LessThan: new Dictionary<string, object?> { ["effectiveAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(1)) },
            OrderBy: [new("effectiveAt", true)], Limit: 1), token);
        var zone = history.FirstOrDefault()?.Data.Text("zone") ?? "UTC";
        var end = ZonedDay(tx.Now, zone);
        var latest = await tx.ListAsync("p_day_activity", new(Where: User(userId), OrderBy: [new("day", true)], Limit: 1), token);
        if (latest.FirstOrDefault()?.Data.Text("day") is { } last && Day(last) > end) end = Day(last);
        var start = end.AddDays(-27);
        var activity = await tx.ListAsync("p_day_activity", new(Where: User(userId),
            GreaterThanEqual: new Dictionary<string, object?> { ["day"] = DayKey(start) },
            LessThan: new Dictionary<string, object?> { ["day"] = DayKey(end.AddDays(1)) },
            OrderBy: [new("day")], Limit: 28), token);
        var byDay = activity.ToDictionary(row => row.Data.Text("day")!, row => row.Data, StringComparer.Ordinal);
        var days = Enumerable.Range(0, 28).Select(i =>
        {
            var key = DayKey(start.AddDays(i));
            var row = byDay.GetValueOrDefault(key) ?? new JsonObject();
            return new LearningStatsDayResponse(key, row.Number("studyXp"), row.Number("completedLessons"), row.Number("reviewSessions"),
                row.Number("originalCorrect"), row.Flag("active"), row.Number("trackedOriginalCount"), row.Number("trackedOriginalCorrect"));
        }).ToArray();
        return new LearningStatsResponse(tx.Now, zone, days);
    }, ct);

    internal static async Task<JsonObject> RequireProfile(OwnerSession tx, string userId, CancellationToken ct)
    {
        var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", userId), ct);
        var deletion = await tx.GetAsync("p_deletions", CanonicalWire.RowId("p_deletions", userId), ct);
        if (profile is null || deletion is not null || profile.Text("deletedAt") is not null) throw new ServiceException("PROFILE_UNAVAILABLE");
        PromoteZone(profile, tx.Now);
        return profile;
    }

    private static void PromoteZone(JsonObject profile, DateTimeOffset now)
    {
        if (profile.Text("pendingZone") is { } pending && profile.Text("zoneEffectiveAt") is { } at && DateTimeOffset.Parse(at, CultureInfo.InvariantCulture) <= now)
        {
            profile["learningZone"] = pending;
            profile["pendingZone"] = null;
            profile["zoneEffectiveAt"] = null;
        }
    }

    private static Dictionary<string, object?> User(string userId) => new() { ["userId"] = userId };
    private static DateOnly Day(string value) => DateOnly.ParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static string DayKey(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static DateOnly ZonedDay(DateTimeOffset instant, string zone) => DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(instant, TimeZoneInfo.FindSystemTimeZoneById(zone)).DateTime);
}
