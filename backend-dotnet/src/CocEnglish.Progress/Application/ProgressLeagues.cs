using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;
using System.Globalization;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressLeagues
{
    public async Task<LeagueResponse> GetAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var week = LeagueWeek(tx.Now);
        var member = await tx.GetAsync("p_league_members", CanonicalWire.RowId("p_league_members", week, user), ct)
            ?? throw new ServiceException("NOT_FOUND", new() { ["reason"] = "NOT_JOINED", ["weekId"] = week });
        return await View(tx, week, member.Text("cohortId")!, member.Number("tier"), ct);
    }
    public async Task<LeagueResponse> JoinAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        if (!profile.Flag("publicOptIn") || profile.Text("ageBand") == "CHILD") throw new ServiceException("FORBIDDEN", new() { ["reason"] = "PUBLIC_OPT_IN_REQUIRED" });
        var week = LeagueWeek(tx.Now);
        var memberId = CanonicalWire.RowId("p_league_members", week, user);
        if (await tx.GetAsync("p_league_members", memberId, ct) is { } existing) return await View(tx, week, existing.Text("cohortId")!, existing.Number("tier"), ct);
        var league = await tx.GetAsync("p_league_profiles", CanonicalWire.RowId("p_league_profiles", user), ct);
        var tier = league?.Number("tier") ?? 0;
        for (var index = 0; index < 1000; index++)
        {
            var cohort = CanonicalWire.RowId("operation", "cohort", week, tier.ToString(CultureInfo.InvariantCulture), index.ToString(CultureInfo.InvariantCulture));
            var runId = CanonicalWire.RowId("p_league_runs", week, cohort);
            var run = await tx.GetAsync("p_league_runs", runId, ct);
            JsonArray members;
            try { members = (JsonNode.Parse(run?.Text("snapshotJson") ?? "{}")?["members"] as JsonArray)?.DeepClone().AsArray() ?? new(); }
            catch (System.Text.Json.JsonException) { members = new(); }
            if (run is not null && (run.Text("status") != "OPEN" || members.Count >= 30)) continue;
            members.Add(user);
            run ??= new();
            run["weekId"] = week; run["cohortId"] = cohort; run["tier"] = tier; run["stage"] = "LEAGUE"; run["status"] = "OPEN";
            run["watermarkAt"] = null; run["checkpointUserId"] = null; run["closedAt"] = null;
            run["snapshotJson"] = CanonicalWire.Stringify(new JsonObject { ["members"] = members });
            tx.Put("p_league_runs", runId, run);
            tx.Put("p_league_members", memberId, new()
            { ["weekId"] = week, ["cohortId"] = cohort, ["userId"] = user, ["tier"] = tier, ["stage"] = "LEAGUE", ["eligibleXp"] = 0, ["lastXpAt"] = null, ["rank"] = null, ["excluded"] = false, ["settled"] = false });
            return await View(tx, week, cohort, tier, ct);
        }
        throw new ServiceException("RATE_LIMITED", new() { ["reason"] = "NO_OPEN_COHORT" });
    }

    private static async Task<LeagueResponse> View(OwnerSession tx, string week, string cohort, long tier, CancellationToken ct)
    {
        var run = await tx.GetAsync("p_league_runs", CanonicalWire.RowId("p_league_runs", week, cohort), ct);
        var rows = await tx.ListAsync("p_league_members", new(Where: new Dictionary<string, object?> { ["weekId"] = week, ["cohortId"] = cohort }, Limit: 30), ct);
        var ranked = rows.Where(r => !r.Data.Flag("excluded")).OrderByDescending(r => r.Data.Number("eligibleXp"))
            .ThenBy(r => DateTimeOffset.TryParse(r.Data.Text("lastXpAt"), CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) ? date : DateTimeOffset.MaxValue)
            .ThenBy(r => r.Data.Text("userId"), StringComparer.Ordinal);
        var members = new List<LeagueMemberResponse>();
        foreach (var entry in ranked)
        {
            var row = entry.Data;
            var profile = await tx.GetAsync("p_profiles", CanonicalWire.RowId("p_profiles", row.Text("userId")!), ct);
            var name = profile?.Text("nickname") ?? "Learner";
            members.Add(new(row.Text("userId")!, name[..Math.Min(40, name.Length)], row.Number("eligibleXp"), members.Count + 1,
                row.Text("lastXpAt") is { } text ? DateTimeOffset.Parse(text, CultureInfo.InvariantCulture) : null));
        }
        return new(week, cohort, tier, run?.Text("status") ?? "OPEN", members, tx.Now, null);
    }
}
