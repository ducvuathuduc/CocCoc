using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text;
using System.Text.Json.Nodes;

namespace CocEnglish.IntegrationTests;

public sealed class RolloverTests
{
    [Theory]
    [InlineData("scheduler", 200)]
    [InlineData("maintainer", 200)]
    [InlineData("learning", 403)]
    public async Task SignedJob_UsesDurableCandidatesAndRepeatsWithoutAnotherFreeze(string sender, int status)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> {
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"rollover-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('4', 64) + "\"}]"
        })));
        using var client = app.CreateClient(); using var scope = app.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear(); await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        var wallet = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        wallet["lastQualifiedDay"] = "2026-10-31"; wallet["currentStreak"] = 5; wallet["freezeSlots"] = 1;
        const string path = "/internal/jobs/streak-rollover";
        const string body = "{\"tickId\":\"11111111-1111-4111-8111-111111111111\",\"scheduledAt\":\"2026-11-03T10:00:00Z\"}";
        for (var i = 0; i < 2; i++)
        {
            var signature = ServiceHmac.Sign(new("rollover-test", sender, Convert.FromHexString(new string('4', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request); Assert.Equal(status, (int)response.StatusCode);
            if (status == 200)
            {
                var report = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
                Assert.Equal("STREAK_ROLLOVER", report["job"]!.GetValue<string>());
                Assert.Equal(i == 0 ? 1 : 0, report["processed"]!.GetValue<int>());
                Assert.Equal(i == 0 ? 1 : 0, report["succeeded"]!.GetValue<int>());
                Assert.Equal(0, report["retried"]!.GetValue<int>());
            }
        }
        Assert.Equal(status == 200 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_freeze_ledger"));
    }

    [Fact]
    public async Task MissedDays_ConsumesOnceThenRecordsLostStreakAndRepeatsWithoutWrites()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear(); await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        var id = CanonicalWire.RowId("p_rewards", "alice"); var wallet = fixture.Driver.Rows[("p_rewards", id)];
        wallet["lastQualifiedDay"] = "2026-10-31"; wallet["currentStreak"] = 5; wallet["bestStreak"] = 5; wallet["streakStartDay"] = "2026-10-27"; wallet["freezeSlots"] = 1;
        var service = new ProgressRollover();
        var result = await store.TransactAsync((tx, ct) => service.ProcessAsync(tx, "alice", ct));
        Assert.Equal(new[] { "2026-11-01" }, result.ProtectedDays); Assert.Equal(6, result.LostStreak);
        wallet = fixture.Driver.Rows[("p_rewards", id)];
        Assert.Equal(0, wallet.Number("currentStreak")); Assert.Equal(6, wallet.Number("bestStreak")); Assert.Equal(0, wallet.Number("freezeSlots"));
        Assert.Equal("2026-11-02", wallet.Text("lostStreakDay")); Assert.Null(wallet["streakStartDay"]);
        var day = fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-01"))];
        Assert.True(day.Flag("protected")); Assert.False(day.Flag("active")); Assert.Equal(0, day.Number("studyXp"));
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_freeze_ledger");
        var commits = fixture.Driver.Commits;
        var repeated = await store.TransactAsync((tx, ct) => service.ProcessAsync(tx, "alice", ct));
        Assert.Empty(repeated.ProtectedDays); Assert.Null(repeated.LostStreak); Assert.Equal(commits, fixture.Driver.Commits);
    }

    [Theory]
    [InlineData("UTC", "2026-11-01", true)]
    [InlineData("America/Los_Angeles", "2026-11-01", false)]
    public async Task MissingYesterday_UsesAccountZoneAtServerMidnight(string zone, string last, bool loses)
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-03T00:01:00Z") }; using var client = fixture.CreateClient();
        fixture.Driver.Rows.Clear(); using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["learningZone"] = zone;
        var wallet = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        wallet["lastQualifiedDay"] = last; wallet["currentStreak"] = 5;
        // UTC has ended the missing day; Los Angeles has not yet ended that day.
        var result = await store.TransactAsync((tx, ct) => new ProgressRollover().ProcessAsync(tx, "alice", ct));
        Assert.Empty(result.ProtectedDays); Assert.Equal(loses ? 5L : (long?)null, result.LostStreak);
        Assert.Equal(loses ? 0 : 5, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("currentStreak"));
    }

    [Fact]
    public async Task ExistingQualifiedDaysAdvanceAndAnExistingFreezeLedgerCannotConsumeAgain()
    {
        await using var fixture = new ProgressApiFixture();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear();
        await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        var rewardsId = CanonicalWire.RowId("p_rewards", "alice");
        fixture.Driver.Rows[("p_rewards", rewardsId)]["lastQualifiedDay"] = "2026-10-30";
        fixture.Driver.Rows[("p_rewards", rewardsId)]["currentStreak"] = 7;
        fixture.Driver.Rows[("p_rewards", rewardsId)]["freezeSlots"] = 2;
        var activeId = CanonicalWire.RowId("p_day_activity", "alice", "2026-10-31");
        fixture.Driver.Rows[("p_day_activity", activeId)] = new() { ["userId"] = "alice", ["day"] = "2026-10-31", ["active"] = true };
        var protectedId = CanonicalWire.RowId("p_day_activity", "alice", "2026-11-01");
        fixture.Driver.Rows[("p_day_activity", protectedId)] = new() { ["userId"] = "alice", ["day"] = "2026-11-01", ["protected"] = true };
        var operation = CanonicalWire.RowId("operation", "freeze-consume", "alice", "2026-11-02");
        var ledgerId = CanonicalWire.RowId("p_freeze_ledger", "alice", operation);
        fixture.Driver.Rows[("p_freeze_ledger", ledgerId)] = new() { ["userId"] = "alice", ["operationId"] = operation, ["action"] = "CONSUME", ["day"] = "2026-11-02", ["slotDelta"] = -1 };

        var result = await store.TransactAsync((tx, ct) => new ProgressRollover().ProcessAsync(tx, "alice", ct));

        Assert.Empty(result.ProtectedDays);
        Assert.Equal(7, result.LostStreak);
        var rewards = fixture.Driver.Rows[("p_rewards", rewardsId)];
        Assert.Equal("2026-11-01", rewards.Text("lastQualifiedDay"));
        Assert.Equal(0, rewards.Number("currentStreak"));
        Assert.Equal(2, rewards.Number("freezeSlots"));
        Assert.False(fixture.Driver.Rows.ContainsKey(("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-02"))));
        Assert.Single(fixture.Driver.Rows, row => row.Key.Table == "p_freeze_ledger");
    }

    [Fact]
    public async Task CatchUpStopsAtFourHundredDaysAndResumesOnTheNextTick()
    {
        await using var fixture = new ProgressApiFixture();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear();
        await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        var rewardsId = CanonicalWire.RowId("p_rewards", "alice");
        fixture.Driver.Rows[("p_rewards", rewardsId)]["lastQualifiedDay"] = "2025-09-27";
        fixture.Driver.Rows[("p_rewards", rewardsId)]["currentStreak"] = 5;
        var start = DateOnly.Parse("2025-09-27");
        for (var offset = 1; offset <= 401; offset++)
        {
            var key = start.AddDays(offset).ToString("yyyy-MM-dd");
            fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", key))] = new() { ["userId"] = "alice", ["day"] = key, ["active"] = true };
        }

        var first = await store.TransactAsync((tx, ct) => new ProgressRollover().ProcessAsync(tx, "alice", ct));
        Assert.Empty(first.ProtectedDays); Assert.Null(first.LostStreak);
        Assert.Equal("2026-11-01", fixture.Driver.Rows[("p_rewards", rewardsId)].Text("lastQualifiedDay"));
        Assert.Equal(5, fixture.Driver.Rows[("p_rewards", rewardsId)].Number("currentStreak"));

        var second = await store.TransactAsync((tx, ct) => new ProgressRollover().ProcessAsync(tx, "alice", ct));
        Assert.Empty(second.ProtectedDays); Assert.Null(second.LostStreak);
        Assert.Equal("2026-11-02", fixture.Driver.Rows[("p_rewards", rewardsId)].Text("lastQualifiedDay"));
    }

    [Fact]
    public async Task CandidateBatch_UsesOldestFirstAndHonorsRequestedLimit()
    {
        await using var fixture = new ProgressApiFixture(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear();
        var writes = new ProgressWrites();
        await store.TransactAsync((tx, ct) => writes.InitializeProfileAsync(tx, "alice", ct));
        await store.TransactAsync((tx, ct) => writes.InitializeProfileAsync(tx, "bob", ct));
        var aliceId = CanonicalWire.RowId("p_rewards", "alice"); var bobId = CanonicalWire.RowId("p_rewards", "bob");
        fixture.Driver.Rows[("p_rewards", aliceId)]["lastQualifiedDay"] = "2026-10-29";
        fixture.Driver.Rows[("p_rewards", bobId)]["lastQualifiedDay"] = "2026-10-31";
        fixture.Driver.Rows[("p_rewards", aliceId)]["currentStreak"] = 5;
        fixture.Driver.Rows[("p_rewards", bobId)]["currentStreak"] = 5;

        var report = await scope.ServiceProvider.GetRequiredService<ProgressJobRunner>().RunStreakRolloverAsync(
            new("11111111-1111-4111-8111-111111111111", 1, null), CancellationToken.None);

        Assert.Equal(1, report.Processed); Assert.Equal(1, report.Succeeded); Assert.Equal(0, report.Retried); Assert.Equal(0, report.Skipped);
        Assert.Equal(0, fixture.Driver.Rows[("p_rewards", aliceId)].Number("currentStreak"));
        Assert.Equal(5, fixture.Driver.Rows[("p_rewards", bobId)].Number("currentStreak"));
    }

    [Fact]
    public async Task CandidateWithoutActiveProfileIsReportedAsSkipped()
    {
        await using var fixture = new ProgressApiFixture(); using var scope = fixture.Services.CreateScope();
        fixture.Driver.Rows.Clear();
        fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "deleted-user"))] = new()
        { ["userId"] = "deleted-user", ["lastQualifiedDay"] = "2026-10-31", ["currentStreak"] = 5 };

        var report = await scope.ServiceProvider.GetRequiredService<ProgressJobRunner>().RunStreakRolloverAsync(
            new("11111111-1111-4111-8111-111111111111", 10, null), CancellationToken.None);

        Assert.Equal(1, report.Processed); Assert.Equal(0, report.Succeeded); Assert.Equal(0, report.Retried); Assert.Equal(1, report.Skipped);
        Assert.Equal(0, fixture.Driver.Commits);
    }

    [Fact]
    public async Task TransactionConflictsAreReportedForRetryOnTheNextTick()
    {
        await using var fixture = new ProgressApiFixture(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows.Clear(); await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        var rewards = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        rewards["lastQualifiedDay"] = "2026-10-31"; rewards["currentStreak"] = 5;
        fixture.Driver.Conflicts = 4;

        var report = await scope.ServiceProvider.GetRequiredService<ProgressJobRunner>().RunStreakRolloverAsync(
            new("11111111-1111-4111-8111-111111111111", 10, null), CancellationToken.None);

        Assert.Equal(1, report.Processed); Assert.Equal(0, report.Succeeded); Assert.Equal(1, report.Retried); Assert.Equal(0, report.Skipped);
        Assert.Equal(5, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("currentStreak"));
    }
}
