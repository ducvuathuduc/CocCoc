using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;

namespace CocEnglish.Progress.Application;

public sealed class ProgressLeagueResults
{
    public async Task<LeagueResultResponse> GetAsync(OwnerSession tx, string user, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var row = await tx.GetAsync("p_league_profiles", CanonicalWire.RowId("p_league_profiles", user), ct) ?? new JsonObject();
        var last = row.Text("lastResultJson") is { Length: > 0 } json ? JsonNode.Parse(json)?.AsObject() : null;
        return new(row.Number("tier"), row.Text("stage") ?? "LEAGUE", row.Number("weeksParticipated"), row.Number("topThreeFinishes"), row.Number("diamondWeeks"),
            last is null ? null : new(last.Text("weekId")!, last.Number("previousTier"), last.Number("tier"), "LEAGUE", last["rank"] is null ? null : last.Number("rank"), last.Text("outcome") ?? "STAYED", last.Number("gemsAwarded")),
            !string.IsNullOrEmpty(row.Text("lastSettledWeekId")) && row.Text("resultSeenWeekId") != row.Text("lastSettledWeekId"), tx.Now);
    }
    public async Task<string> SeenAsync(OwnerSession tx, string user, string week, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_league_profiles", user);
        var row = await tx.GetAsync("p_league_profiles", id, ct);
        if (row is null || row.Text("lastSettledWeekId") != week) throw new ServiceException("NOT_FOUND");
        if (row.Text("resultSeenWeekId") == week) return "replayed";
        row["resultSeenWeekId"] = week;
        tx.Put("p_league_profiles", id, row);
        return "completed";
    }
}
