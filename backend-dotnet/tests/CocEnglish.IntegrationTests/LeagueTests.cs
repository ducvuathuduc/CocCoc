using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LeagueTests
{
    [Fact]
    public async Task Settlement_FullCohortRanksTiesAwardsPodiumAndExcludesRemovedMember()
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-03T00:00:00Z") };
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear();
        string? cohort = null;
        foreach (var user in Enumerable.Range(0, 11).Select(i => "u" + i.ToString("D2")))
        {
            await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, user, ct));
            fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", user))]["publicOptIn"] = true;
            fixture.Driver.Rows[("p_league_profiles", CanonicalWire.RowId("p_league_profiles", user))]["tier"] = 4;
            cohort = (await store.TransactAsync((tx, ct) => new ProgressLeagues().JoinAsync(tx, user, ct))).CohortId;
            var member = fixture.Driver.Rows[("p_league_members", CanonicalWire.RowId("p_league_members", "2026-11-02", user))];
            member["eligibleXp"] = 100;
            member["lastXpAt"] = user == "u01" ? "2026-11-03T01:00:00.000Z" : "2026-11-03T02:00:00.000Z";
            if (user == "u10") { member["excluded"] = true; member["eligibleXp"] = 9999; }
        }
        fixture.Now = DateTimeOffset.Parse("2026-11-09T00:00:00Z");
        await new ProgressSettlement(store, fixture.Services.GetRequiredService<TimeProvider>()).SettleAsync("2026-11-02", new Watermark(0), CancellationToken.None);
        Assert.Equal(40, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "u01"))].Number("gems"));
        Assert.Equal(35, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "u00"))].Number("gems"));
        Assert.Equal(30, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "u02"))].Number("gems"));
        Assert.Equal(5, fixture.Driver.Rows[("p_league_profiles", CanonicalWire.RowId("p_league_profiles", "u01"))].Number("tier"));
        Assert.Equal(3, fixture.Driver.Rows[("p_league_profiles", CanonicalWire.RowId("p_league_profiles", "u09"))].Number("tier"));
        Assert.False(fixture.Driver.Rows[("p_league_members", CanonicalWire.RowId("p_league_members", "2026-11-02", "u10"))].Flag("settled"));
        Assert.Equal(0, fixture.Driver.Rows[("p_league_profiles", CanonicalWire.RowId("p_league_profiles", "u10"))].Number("weeksParticipated"));
        var run = fixture.Driver.Rows[("p_league_runs", CanonicalWire.RowId("p_league_runs", "2026-11-02", cohort!))];
        Assert.Equal("CLOSED", run.Text("status"));
        Assert.Equal("u09", run.Text("checkpointUserId"));
        Assert.Equal(10, System.Text.Json.Nodes.JsonNode.Parse(run.Text("snapshotJson")!)!["ranks"]!.AsArray().Count);
    }
    [Theory]
    [InlineData(1, false)]
    [InlineData(-1, true)]
    public async Task Settlement_NonzeroOrFailedWatermarkNeverClosesCohort(long pending, bool unavailable)
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-10T00:00:00.001Z") };
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        const string week = "2026-11-02", cohort = "cohort";
        var id = CanonicalWire.RowId("p_league_runs", week, cohort);
        fixture.Driver.Rows[("p_league_runs", id)] = new() { ["weekId"] = week, ["cohortId"] = cohort, ["tier"] = 0, ["stage"] = "LEAGUE", ["status"] = "OPEN", ["snapshotJson"] = "{\"members\":[]}" };
        var watermark = new Watermark(pending, unavailable);
        var service = new ProgressSettlement(store, fixture.Services.GetRequiredService<TimeProvider>());
        var report = await service.SettleAsync(week, watermark, CancellationToken.None);
        Assert.Empty(report.Closed);
        Assert.Equal(new[] { cohort }, report.Settling);
        Assert.True(report.NeedsIntervention);
        Assert.Equal("SETTLING", fixture.Driver.Rows[("p_league_runs", id)].Text("status"));
        Assert.Equal(DateTimeOffset.Parse("2026-11-09T00:00:00Z"), watermark.Cutoff);
    }

    [Fact]
    public async Task Settlement_ZeroWatermarkClosesOnceAndSmallCohortHasNoPodiumCredit()
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-09T00:00:00Z") };
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear();
        await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["publicOptIn"] = true;
        fixture.Now = DateTimeOffset.Parse("2026-11-03T00:00:00Z");
        var joined = await store.TransactAsync((tx, ct) => new ProgressLeagues().JoinAsync(tx, "alice", ct));
        var settlement = new ProgressSettlement(store, fixture.Services.GetRequiredService<TimeProvider>());
        Assert.Equal("VALIDATION_ERROR", (await Assert.ThrowsAsync<ServiceException>(() => settlement.SettleAsync(joined.WeekId, new Watermark(0), CancellationToken.None))).Code);
        fixture.Now = DateTimeOffset.Parse("2026-11-09T00:00:00Z");
        var result = await settlement.SettleAsync(joined.WeekId, new Watermark(0), CancellationToken.None);
        Assert.Equal(new[] { joined.CohortId }, result.Closed);
        Assert.Empty(result.Settling);
        var profile = fixture.Driver.Rows[("p_league_profiles", CanonicalWire.RowId("p_league_profiles", "alice"))];
        Assert.Equal(1, profile.Number("weeksParticipated"));
        Assert.Equal(0, profile.Number("tier"));
        Assert.Equal(20, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        var commits = fixture.Driver.Commits;
        Assert.Empty((await settlement.SettleAsync(joined.WeekId, new Watermark(0), CancellationToken.None)).Closed);
        Assert.Equal(commits, fixture.Driver.Commits);
    }

    private sealed class Watermark(long pending, bool unavailable = false) : ILearningWatermark
    {
        public DateTimeOffset Cutoff { get; private set; }
        public Task<long> PendingBeforeAsync(DateTimeOffset cutoff, CancellationToken ct)
        {
            Cutoff = cutoff;
            return unavailable ? throw new HttpRequestException("offline") : Task.FromResult(pending);
        }
    }
    [Fact]
    public async Task Join_UsesFirstOpenCohortAndRepeatsWithoutWrites()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var app = new ProgressLeagues();
        Assert.Equal("NOT_FOUND", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.GetAsync(tx, "alice", ct)))).Code);
        Assert.Equal("FORBIDDEN", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", ct)))).Code);
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["publicOptIn"] = true;
        var first = await store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", ct));
        Assert.Equal("2026-11-02", first.WeekId);
        Assert.Equal(CanonicalWire.RowId("operation", "cohort", "2026-11-02", "0", "0"), first.CohortId);
        Assert.Equal(0, Assert.Single(first.Members).EligibleXp);
        Assert.Equal(1, first.Members[0].Rank);
        Assert.Equal(2, fixture.Driver.LastWrites.Count);
        var repeat = await store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", ct));
        Assert.Equal(first.CohortId, repeat.CohortId);
        Assert.Equal(1, fixture.Driver.Commits);
    }

    [Theory]
    [InlineData(29, "OPEN", 0)]
    [InlineData(30, "OPEN", 1)]
    [InlineData(0, "CLOSED", 1)]
    [InlineData(0, "SETTLING", 1)]
    public async Task Join_SkipsFullOrNonOpenCohorts(int members, string status, int expectedIndex)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["publicOptIn"] = true;
        var cohort = CanonicalWire.RowId("operation", "cohort", "2026-11-02", "0", "0");
        fixture.Driver.Rows[("p_league_runs", CanonicalWire.RowId("p_league_runs", "2026-11-02", cohort))] = new()
        { ["weekId"] = "2026-11-02", ["cohortId"] = cohort, ["tier"] = 0, ["stage"] = "LEAGUE", ["status"] = status, ["snapshotJson"] = System.Text.Json.JsonSerializer.Serialize(new { members = Enumerable.Range(0, members).Select(i => "user-" + i).ToArray() }) };
        var result = await store.TransactAsync((tx, ct) => new ProgressLeagues().JoinAsync(tx, "alice", ct));
        Assert.Equal(CanonicalWire.RowId("operation", "cohort", "2026-11-02", "0", expectedIndex.ToString()), result.CohortId);
        Assert.Equal(1, fixture.Driver.Commits);
    }
}
