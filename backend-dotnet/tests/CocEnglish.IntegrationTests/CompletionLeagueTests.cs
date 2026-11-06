using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class CompletionLeagueTests
{
    [Theory]
    [InlineData(false, false, 10)]
    [InlineData(true, false, 0)]
    [InlineData(false, true, 0)]
    public async Task LeagueCredit_ProtectsSettledAndExcludedMembers(bool settled, bool excluded, int added)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>(); var id = CanonicalWire.RowId("p_league_members", "2026-11-02", "alice");
        fixture.Driver.Rows[("p_league_members", id)] = new() { ["userId"] = "alice", ["weekId"] = "2026-11-02", ["cohortId"] = "cohort", ["tier"] = 0, ["stage"] = "LEAGUE",
            ["eligibleXp"] = 20, ["lastXpAt"] = "2026-11-03T11:00:00.000Z", ["settled"] = settled, ["excluded"] = excluded, ["rank"] = null, ["revision"] = 0 };
        await store.TransactAsync(async (tx, ct) => { await ProgressCompletionEffects.AddLeagueXpAsync(tx, "alice", "2026-11-02", 10, "2026-11-03T10:00:00.000Z", ct); return 0; });
        var row = fixture.Driver.Rows[("p_league_members", id)]; Assert.Equal(20 + added, row.Number("eligibleXp"));
        Assert.Equal("2026-11-03T11:00:00.000Z", row.Text("lastXpAt"));
        Assert.Equal(added == 0 ? 0 : 1, fixture.Driver.Commits);
    }
}
