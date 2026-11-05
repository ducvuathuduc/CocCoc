using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using CocEnglish.Progress.Domain;
using System.Text.Json.Nodes;
using System.Globalization;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public interface ILearningWatermark
{
    Task<long> PendingBeforeAsync(DateTimeOffset cutoff, CancellationToken ct);
}
public sealed record SettlementReport(string WeekId, IReadOnlyList<string> Closed, IReadOnlyList<string> Settling, bool NeedsIntervention);

public sealed class ProgressSettlement(OwnerStore store, TimeProvider clock)
{
    public async Task<SettlementReport> SettleAsync(string week, ILearningWatermark watermark, CancellationToken ct)
    {
        var cutoff = new DateTimeOffset(Day(week).AddDays(7).ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);
        if (clock.GetUtcNow() < cutoff) throw new ServiceException("VALIDATION_ERROR", new() { ["reason"] = "WEEK_NOT_ENDED", ["weekId"] = week });
        var runs = await store.TransactAsync((tx, token) => tx.ListAsync("p_league_runs", new(Where: new Dictionary<string, object?> { ["weekId"] = week }, Limit: 500), token), ct);
        long pending;
        try { pending = await watermark.PendingBeforeAsync(cutoff, ct); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { pending = -1; }
        var closed = new List<string>(); var settling = new List<string>(); var intervention = false;
        foreach (var document in runs.Where(r => r.Data.Text("status") != "CLOSED"))
        {
            var cohort = document.Data.Text("cohortId")!;
            var runId = CanonicalWire.RowId("p_league_runs", week, cohort);
            if (pending != 0)
            {
                await store.TransactAsync(async (tx, token) =>
                {
                    var run = await tx.GetAsync("p_league_runs", runId, token);
                    if (run?.Text("status") == "OPEN") { run["status"] = "SETTLING"; tx.Put("p_league_runs", runId, run); }
                    return 0;
                }, ct);
                settling.Add(cohort);
                if (clock.GetUtcNow() - cutoff > TimeSpan.FromDays(1)) intervention = true;
                continue;
            }
            await store.TransactAsync(async (tx, token) =>
            {
                var run = await tx.GetAsync("p_league_runs", runId, token);
                if (run is null || run.Text("status") == "CLOSED") return 0;
                var tier = run.Number("tier");
                var members = await tx.ListAsync("p_league_members", new(Where: new Dictionary<string, object?> { ["weekId"] = week, ["cohortId"] = cohort }, Limit: 30), token);
                var ranked = members.Where(m => !m.Data.Flag("excluded")).OrderByDescending(m => m.Data.Number("eligibleXp"))
                    .ThenBy(m => DateTimeOffset.TryParse(m.Data.Text("lastXpAt"), CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) ? date : DateTimeOffset.MaxValue)
                    .ThenBy(m => m.Data.Text("userId"), StringComparer.Ordinal).ToArray();
                var ranks = new JsonArray();
                for (var index = 0; index < ranked.Length; index++)
                {
                    var member = ranked[index]; var user = member.Data.Text("userId")!; var rank = index + 1;
                    var movement = LeaguePolicy.Movement(rank, ranked.Length, tier);
                    ranks.Add(new JsonObject { ["userId"] = user, ["rank"] = rank, ["eligibleXp"] = member.Data.Number("eligibleXp"), ["movement"] = movement });
                    var current = await tx.GetAsync("p_league_members", member.Id, token);
                    if (current is not null) { current["rank"] = rank; current["settled"] = true; tx.Put("p_league_members", member.Id, current); }
                    var profileId = CanonicalWire.RowId("p_league_profiles", user);
                    var profile = await tx.GetAsync("p_league_profiles", profileId, token);
                    if (profile is null || profile.Text("lastSettledWeekId") == week) continue;
                    var nextTier = LeaguePolicy.NextTier(tier, movement);
                    var podium = ranked.Length >= 10 && rank <= 3 ? new long[] { 20, 15, 10 }[index] : 0;
                    if (podium > 0) await ProgressShop.CreditGemsAsync(tx, user, podium, "LEAGUE", CanonicalWire.RowId("operation", "league-podium", week, user), "league_" + week, "UTC", token);
                    profile["tier"] = nextTier; profile["weeksParticipated"] = profile.Number("weeksParticipated") + 1;
                    profile["topThreeFinishes"] = profile.Number("topThreeFinishes") + (rank <= 3 ? 1 : 0);
                    profile["diamondWeeks"] = profile.Number("diamondWeeks") + (tier == 9 ? 1 : 0);
                    profile["lastSettledWeekId"] = week;
                    profile["lastResultJson"] = CanonicalWire.Stringify(new JsonObject { ["weekId"] = week, ["previousTier"] = tier, ["tier"] = nextTier, ["rank"] = rank,
                        ["movement"] = movement, ["outcome"] = movement == "PROMOTE" ? "PROMOTED" : movement == "DEMOTE" ? "DEMOTED" : "STAYED", ["gemsAwarded"] = podium });
                    tx.Put("p_league_profiles", profileId, profile);
                }
                JsonArray ids;
                try { ids = (JsonNode.Parse(run.Text("snapshotJson") ?? "{}")?["members"] as JsonArray)?.DeepClone().AsArray() ?? new(); }
                catch (System.Text.Json.JsonException) { ids = new(); }
                run["status"] = "CLOSED"; run["watermarkAt"] = tx.NowIso; run["closedAt"] = tx.NowIso;
                run["checkpointUserId"] = ranked.LastOrDefault()?.Data.Text("userId");
                run["snapshotJson"] = CanonicalWire.Stringify(new JsonObject { ["members"] = ids, ["ranks"] = ranks });
                tx.Put("p_league_runs", runId, run);
                return 0;
            }, ct);
            closed.Add(cohort);
        }
        return new(week, closed, settling, intervention);
    }
}
