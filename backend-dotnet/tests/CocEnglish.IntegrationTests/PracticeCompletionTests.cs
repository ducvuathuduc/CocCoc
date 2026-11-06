using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text;
using System.Net;

namespace CocEnglish.IntegrationTests;

public sealed class PracticeCompletionTests
{
    [Fact]
    public async Task PracticeCap_StillRecordsActiveDayButNeverExceedsDailyLimit()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        for (var i = 0; i < 3; i++)
        {
            var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "conversation" + i, ["scenarioId"] = "scenario1", ["xp"] = 50 };
            await store.TransactAsync(async (tx, ct) => { await ProgressPractice.ApplyAsync(tx, "event" + i, DateTimeOffset.Parse("2026-11-03T10:00:00Z"), payload, ct); return 0; });
        }
        var rewards = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        Assert.Equal(100, rewards.Number("studyXp"));
        var capped = fixture.Driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", "conversation2", "PRACTICE"))];
        Assert.Equal(0, capped.Number("studyXpDelta")); Assert.True(capped.Flag("capped"));
        Assert.Equal(1, fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "MONTH", "2026-11", "monthly_active_days"))].Number("metricValue"));
    }

    [Fact]
    public async Task DeletedAccount_ReceivesNoPracticeEffects()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        fixture.Driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))] = new() { ["userId"] = "alice" };
        var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "conversation", ["scenarioId"] = "scenario", ["xp"] = 50 };
        await scope.ServiceProvider.GetRequiredService<OwnerStore>().TransactAsync(async (tx, ct) => { await ProgressPractice.ApplyAsync(tx, "event", fixture.Now, payload, ct); return 0; });
        Assert.Equal(0, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_reward_ledger" or "p_day_activity" or "p_notifications");
    }

    [Theory]
    [InlineData("ai", 200)]
    [InlineData("learning", 403)]
    public async Task SignedEvent_RequiresAiAndDeduplicatesInbox(string sender, int expected)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> {
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('9', 64) + "\"}]" })));
        using var client = app.CreateClient(); const string path = "/internal/events";
        var body = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "ai.practice.completed.v1", ["schemaVersion"] = 1,
            ["producer"] = "ai", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now), ["requestId"] = "trace",
            ["payload"] = new JsonObject { ["userId"] = "alice", ["completionId"] = "conversation1", ["courseId"] = "course1", ["scenarioId"] = "scenario1", ["kind"] = "ROLEPLAY", ["xp"] = 15, ["wordsUsed"] = 3, ["stars"] = 2 } }.ToJsonString();
        for (var i = 0; i < 2; i++)
        {
            var sig = ServiceHmac.Sign(new("test", sender, Convert.FromHexString(new string('9', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", sig.KeyId); request.Headers.Add("X-Service-Timestamp", sig.Timestamp); request.Headers.Add("X-Service-Signature", sig.Signature);
            using var response = await client.SendAsync(request); Assert.Equal(expected, (int)response.StatusCode);
            if (expected == 200) Assert.Equal(i == 0 ? "accepted" : "replayed", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["status"]!.GetValue<string>());
        }
        Assert.Equal(expected == 200 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_inbox"));
        Assert.Equal(expected == 200 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
        if (expected == 200)
        {
            var changed = JsonNode.Parse(body)!.AsObject();
            changed["payload"]!.AsObject()["xp"] = 14;
            var changedBody = changed.ToJsonString();
            var signature = ServiceHmac.Sign(new("test", sender, Convert.FromHexString(new string('9', 64))), "POST", path, "", new HashSet<string>(), changedBody, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(changedBody, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request);
            Assert.Equal(409, (int)response.StatusCode);
            Assert.Equal("IDEMPOTENCY_CONFLICT", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
            Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_reward_ledger");
        }
    }

    [Fact]
    public async Task SignedPracticeEvent_RejectsAggregateMismatchBeforeInboxWrites()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); const string path = "/internal/events";
        var body = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "ai.practice.completed.v1", ["schemaVersion"] = 1,
            ["producer"] = "ai", ["aggregateId"] = "bob", ["occurredAt"] = OwnerSchema.Iso(fixture.Now), ["requestId"] = "trace",
            ["payload"] = new JsonObject { ["userId"] = "alice", ["completionId"] = "conversation1", ["courseId"] = "course1", ["scenarioId"] = "scenario1", ["kind"] = "ROLEPLAY", ["xp"] = 15, ["wordsUsed"] = 3, ["stars"] = 2 } }.ToJsonString();
        var signature = ServiceHmac.Sign(new("parity-ai", "ai", Convert.FromHexString(string.Concat(Enumerable.Repeat("0c", 32)))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
        using var response = await client.SendAsync(request);
        Assert.Equal(400, (int)response.StatusCode);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_inbox" or "p_reward_ledger" or "p_day_activity");
    }

    [Fact]
    public async Task Completion_CreditsOnceAndAdvancesOnlyPracticeEligibleProgress()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "conversation1", ["scenarioId"] = "scenario1", ["xp"] = 15 };
        for (var i = 0; i < 2; i++) await store.TransactAsync(async (tx, ct) => { await ProgressPractice.ApplyAsync(tx, "event1", DateTimeOffset.Parse("2026-11-03T10:00:00Z"), payload, ct); return 0; });
        var rewards = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        Assert.Equal(15, rewards.Number("studyXp")); Assert.Equal(1, rewards.Number("currentStreak"));
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_reward_ledger");
        var day = fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-03"))];
        Assert.True(day.Flag("active")); Assert.Equal(0, day.Number("completedLessons"));
        Assert.Equal(1, fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "MONTH", "2026-11", "monthly_active_days"))].Number("metricValue"));
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_quests" && r.Value.Text("questId") == "daily_lessons");
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_notifications", CanonicalWire.RowId("p_notifications", "alice", "conversation1"))));
    }
}
