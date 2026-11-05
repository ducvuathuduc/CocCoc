using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text;

namespace CocEnglish.IntegrationTests;

public sealed class LessonCompletionTests
{
    [Theory]
    [InlineData("REVIEW", "ONLINE", 5, 0, 1)]
    [InlineData("LESSON", "OFFLINE", 20, 0, 0)]
    [InlineData("CHECKPOINT", "ONLINE", 0, 0, 0)]
    public async Task Modes_ApplyExpectedXpAndReviewProgress(string mode, string source, int xp, int league, int review)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "completion", ["rewardIdentity"] = "lesson1", ["mode"] = mode, ["source"] = source, ["originalCount"] = 10, ["originalCorrect"] = 10, ["assisted"] = false };
        await store.TransactAsync(async (tx, ct) => { await ProgressLesson.ApplyAsync(tx, "event", fixture.Now, payload, ct); return 0; });
        if (mode == "CHECKPOINT")
        {
            Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_reward_ledger" or "p_day_activity" or "p_rewards");
            return;
        }
        var rewards = fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))];
        Assert.Equal(xp, rewards.Number("studyXp")); Assert.Equal(league, rewards.Number("leagueXpLifetime"));
        var day = fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-03"))];
        Assert.Equal(review, day.Number("reviewSessions"));
    }

    [Fact]
    public async Task Tombstone_PreventsAllLessonEffects()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        fixture.Driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "alice"))] = new() { ["userId"] = "alice" };
        var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "completion", ["rewardIdentity"] = "lesson1", ["mode"] = "LESSON", ["source"] = "ONLINE", ["originalCount"] = 10, ["originalCorrect"] = 10, ["assisted"] = false };
        await scope.ServiceProvider.GetRequiredService<OwnerStore>().TransactAsync(async (tx, ct) => { await ProgressLesson.ApplyAsync(tx, "event", fixture.Now, payload, ct); return 0; });
        Assert.Equal(0, fixture.Driver.Commits); Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_reward_ledger" or "p_day_activity");
    }

    [Theory]
    [InlineData("learning", 200)]
    [InlineData("ai", 403)]
    public async Task SignedLessonEvent_RequiresLearningAndReplaysWithoutDoubleCredit(string sender, int status)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> {
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"lesson-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('a', 64) + "\"}]" })));
        using var client = app.CreateClient(); const string path = "/internal/events";
        var body = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "lesson.completed.v1", ["schemaVersion"] = 1,
            ["producer"] = "learning", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now), ["requestId"] = "trace", ["payload"] = new JsonObject {
                ["userId"] = "alice", ["completionId"] = "completion1", ["courseId"] = "course1", ["lessonVersion"] = "v1", ["rewardIdentity"] = "lesson1",
                ["source"] = "ONLINE", ["mode"] = "LESSON", ["originalCount"] = 10, ["originalCorrect"] = 10, ["assisted"] = false } }.ToJsonString();
        for (var i = 0; i < 2; i++)
        {
            var signature = ServiceHmac.Sign(new("lesson-test", sender, Convert.FromHexString(new string('a', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request); Assert.Equal(status, (int)response.StatusCode);
            if (status == 200) Assert.Equal(i == 0 ? "accepted" : "replayed", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["status"]!.GetValue<string>());
        }
        Assert.Equal(status == 200 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
        if (status == 200) Assert.Equal(25, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("studyXp"));
        if (status == 200)
        {
            var changed = JsonNode.Parse(body)!.AsObject();
            changed["payload"]!.AsObject()["originalCorrect"] = 9;
            var changedBody = changed.ToJsonString();
            var signature = ServiceHmac.Sign(new("lesson-test", sender, Convert.FromHexString(new string('a', 64))), "POST", path, "", new HashSet<string>(), changedBody, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(changedBody, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request);
            Assert.Equal(409, (int)response.StatusCode);
            Assert.Equal("IDEMPOTENCY_CONFLICT", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
            Assert.Equal(1, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
        }
    }

    [Fact]
    public async Task SignedLessonEvent_RejectsUnknownPayloadFieldsBeforeInboxWrites()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient(); const string path = "/internal/events";
        var body = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "lesson.completed.v1", ["schemaVersion"] = 1,
            ["producer"] = "learning", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now), ["requestId"] = "trace", ["payload"] = new JsonObject {
                ["userId"] = "alice", ["completionId"] = "completion1", ["courseId"] = "course1", ["lessonVersion"] = "v1", ["rewardIdentity"] = "lesson1",
                ["source"] = "ONLINE", ["mode"] = "LESSON", ["originalCount"] = 10, ["originalCorrect"] = 10, ["assisted"] = false, ["clientXp"] = 999 } }.ToJsonString();
        var signature = ServiceHmac.Sign(new("parity-learning", "learning", Convert.FromHexString(string.Concat(Enumerable.Repeat("0d", 32)))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
        using var response = await client.SendAsync(request);
        Assert.Equal(400, (int)response.StatusCode);
        Assert.Equal("VALIDATION_ERROR", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_inbox" or "p_reward_ledger" or "p_day_activity");
    }

    [Fact]
    public async Task FirstAndRepeatedCompletion_UseOneFirstMarkerAndNeverCreditSameCompletionTwice()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var payload = new JsonObject { ["userId"] = "alice", ["completionId"] = "first", ["rewardIdentity"] = "lesson1", ["mode"] = "LESSON", ["source"] = "ONLINE", ["originalCount"] = 10, ["originalCorrect"] = 10, ["assisted"] = false };
        await store.TransactAsync(async (tx, ct) => { await ProgressLesson.ApplyAsync(tx, "event1", fixture.Now, payload, ct); return 0; });
        await store.TransactAsync(async (tx, ct) => { await ProgressLesson.ApplyAsync(tx, "event2", fixture.Now, payload, ct); return 0; });
        payload["completionId"] = "second";
        await store.TransactAsync(async (tx, ct) => { await ProgressLesson.ApplyAsync(tx, "event3", fixture.Now, payload, ct); return 0; });
        Assert.Equal(30, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("studyXp"));
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_first_rewards"); Assert.Equal(2, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
        Assert.Equal(2, fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-03"))].Number("completedLessons"));
        Assert.Equal(20, fixture.Driver.Rows[("p_day_activity", CanonicalWire.RowId("p_day_activity", "alice", "2026-11-03"))].Number("trackedOriginalCount"));
        Assert.Equal(2, fixture.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", "daily_lessons"))].Number("metricValue"));
    }
}
