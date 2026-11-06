using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text;
using CocEnglish.Shared.Errors;

namespace CocEnglish.IntegrationTests;

public sealed class DeletionPurgeTests
{
    [Theory]
    [InlineData("learning", "learning", 200)]
    [InlineData("ai", "learning", 403)]
    public async Task SignedPurgeEvent_RequiresMatchingProducerAndDeduplicates(string sender, string producer, int status)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> {
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"event-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('8', 64) + "\"}]"
        })));
        using var client = app.CreateClient(); var id = Seed(fixture);
        const string requestId = "22222222-2222-4222-8222-222222222222";
        fixture.Driver.Rows[("p_deletions", id)]["requestId"] = requestId;
        const string path = "/internal/events";
        var body = new JsonObject { ["eventId"] = "11111111-1111-4111-8111-111111111111", ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
            ["producer"] = producer, ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now), ["requestId"] = "trace", ["payload"] = new JsonObject { ["userId"] = "alice", ["requestId"] = requestId, ["owner"] = producer } }.ToJsonString();
        for (var i = 0; i < 2; i++)
        {
            var signed = ServiceHmac.Sign(new("event-test", sender, Convert.FromHexString(new string('8', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signed.KeyId); request.Headers.Add("X-Service-Timestamp", signed.Timestamp); request.Headers.Add("X-Service-Signature", signed.Signature);
            using var response = await client.SendAsync(request); Assert.Equal(status, (int)response.StatusCode);
            if (status == 200) Assert.Equal(i == 0 ? "accepted" : "replayed", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["status"]!.GetValue<string>());
        }
        Assert.Equal(status == 200 ? "[\"learning\"]" : "[]", fixture.Driver.Rows[("p_deletions", id)].Text("ownerAcksJson"));
        Assert.Equal("REQUESTED", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
        if (status == 200)
        {
            var changed = JsonNode.Parse(body)!.AsObject();
            changed["payload"]!.AsObject()["requestId"] = "33333333-3333-4333-8333-333333333333";
            var changedBody = changed.ToJsonString();
            var signature = ServiceHmac.Sign(new("event-test", sender, Convert.FromHexString(new string('8', 64))), "POST", path, "", new HashSet<string>(), changedBody, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(changedBody, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request);
            Assert.Equal(409, (int)response.StatusCode);
            Assert.Equal("IDEMPOTENCY_CONFLICT", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
            Assert.Equal("[\"learning\"]", fixture.Driver.Rows[("p_deletions", id)].Text("ownerAcksJson"));
        }
    }

    [Fact]
    public async Task PurgeAcknowledgement_InboxCommitsWithAckAndRejectsChangedPayload()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>(); var deletion = new ProgressDeletion(store); var id = Seed(fixture);
        async Task Apply(OwnerSession tx, CancellationToken ct) => await deletion.RecordAckAsync(tx, "alice", "request", "learning", ct);
        Assert.Equal("accepted", await store.ApplyInboxAsync("event-1", "account.purged.v1", "hash-1", Apply));
        Assert.Equal("[\"learning\"]", fixture.Driver.Rows[("p_deletions", id)].Text("ownerAcksJson"));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_inbox", "event-1")));
        var commits = fixture.Driver.Commits;
        Assert.Equal("replayed", await store.ApplyInboxAsync("event-1", "account.purged.v1", "hash-1", Apply));
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.ApplyInboxAsync("event-1", "account.purged.v1", "hash-2", Apply));
        Assert.Equal("IDEMPOTENCY_CONFLICT", error.Code); Assert.Equal(commits, fixture.Driver.Commits);
        Assert.Equal("REQUESTED", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
    }

    [Theory]
    [InlineData("scheduler", 200)]
    [InlineData("maintainer", 200)]
    [InlineData("learning", 403)]
    public async Task SignedJob_PurgesOnlyReadyAccountsAndRetainsTombstone(string sender, int expectedStatus)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> {
            ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"purge-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('5', 64) + "\"}]"
        })));
        using var client = app.CreateClient();
        var deletionId = Seed(fixture);
        fixture.Driver.Rows[("p_deletions", deletionId)]["status"] = "PURGING";
        var bobId = CanonicalWire.RowId("p_deletions", "bob");
        fixture.Driver.Rows[("p_deletions", bobId)] = new() { ["userId"] = "bob", ["requestId"] = "request-bob", ["status"] = "REQUESTED", ["requestedAt"] = OwnerSchema.Iso(fixture.Now), ["ownerAcksJson"] = "[]" };
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob" };
        const string path = "/internal/jobs/deletion-purge";
        const string body = "{\"tickId\":\"11111111-1111-4111-8111-111111111111\",\"scheduledAt\":\"2026-11-03T10:00:00Z\"}";
        var signature = ServiceHmac.Sign(new("purge-test", sender, Convert.FromHexString(new string('5', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
        using var response = await client.SendAsync(request);
        Assert.Equal(expectedStatus, (int)response.StatusCode);
        if (expectedStatus == 200)
        {
            var report = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal("DELETION_PURGE", report["job"]!.GetValue<string>());
            Assert.Equal(1, report["processed"]!.GetValue<int>()); Assert.Equal(1, report["succeeded"]!.GetValue<int>());
        }
        Assert.Equal(expectedStatus == 200 ? "COMPLETED" : "PURGING", fixture.Driver.Rows[("p_deletions", deletionId)].Text("status"));
        Assert.Equal(expectedStatus != 200, fixture.Driver.Rows.ContainsKey(("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))));
        Assert.Equal("REQUESTED", fixture.Driver.Rows[("p_deletions", bobId)].Text("status"));
    }

    [Fact]
    public async Task Acknowledgements_IgnoreStaleRequestsAndWaitForBothOwners()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>(); var service = new ProgressDeletion(store); var id = Seed(fixture);
        var commits = fixture.Driver.Commits;
        await store.TransactAsync(async (tx, ct) => { await service.RecordAckAsync(tx, "alice", "stale", "learning", ct); return 0; });
        Assert.Equal(commits, fixture.Driver.Commits);
        await store.TransactAsync(async (tx, ct) => { await service.RecordAckAsync(tx, "alice", "request", "learning", ct); return 0; });
        Assert.Equal("REQUESTED", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
        Assert.False(await service.PurgeAsync("alice", 50, CancellationToken.None));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))));
        await store.TransactAsync(async (tx, ct) => { await service.RecordAckAsync(tx, "alice", "request", "ai", ct); return 0; });
        Assert.Equal("PURGING", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
        Assert.Equal("[\"ai\",\"learning\"]", fixture.Driver.Rows[("p_deletions", id)].Text("ownerAcksJson"));
        Assert.True(await service.PurgeAsync("alice", 50, CancellationToken.None));
        Assert.Equal("COMPLETED", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
        Assert.False(fixture.Driver.Rows.ContainsKey(("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))));
        await store.TransactAsync(async (tx, ct) => { await service.RecordAckAsync(tx, "alice", "request", "learning", ct); return 0; });
        Assert.Equal("COMPLETED", fixture.Driver.Rows[("p_deletions", id)].Text("status"));
    }

    [Fact]
    public async Task BoundedPurge_ResumesAcrossBatchesAndPreservesOtherUsersAndTombstone()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var service = new ProgressDeletion(scope.ServiceProvider.GetRequiredService<OwnerStore>()); var deletion = Seed(fixture);
        fixture.Driver.Rows[("p_deletions", deletion)]["status"] = "PURGING";
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob" };
        for (var i = 0; i < 85; i++) fixture.Driver.Rows[("p_feedback", "feedback" + i)] = new() { ["userId"] = "alice" };
        fixture.Driver.Rows[("p_feedback", "bob-feedback")] = new() { ["userId"] = "bob" };
        fixture.Driver.Rows[("p_follows", "outgoing")] = new() { ["fromUserId"] = "alice", ["toUserId"] = "bob" };
        fixture.Driver.Rows[("p_follows", "incoming")] = new() { ["fromUserId"] = "bob", ["toUserId"] = "alice" };
        Assert.False(await service.PurgeAsync("alice", 1, CancellationToken.None));
        Assert.Equal(8, fixture.Driver.Rows.Count(r => r.Key.Table == "p_feedback" && r.Value.Text("userId") == "alice"));
        Assert.Equal("PURGING", fixture.Driver.Rows[("p_deletions", deletion)].Text("status"));
        Assert.True(await service.PurgeAsync("alice", 50, CancellationToken.None));
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_feedback" && r.Value.Text("userId") == "alice");
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_follows");
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_feedback", "bob-feedback")));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))));
        Assert.True(fixture.Driver.Rows.ContainsKey(("p_deletions", deletion)));
        var commits = fixture.Driver.Commits; Assert.True(await service.PurgeAsync("alice", 50, CancellationToken.None)); Assert.Equal(commits, fixture.Driver.Commits);
    }
    private static string Seed(ProgressApiFixture fixture)
    {
        var id = CanonicalWire.RowId("p_deletions", "alice"); fixture.Driver.Rows[("p_deletions", id)] = new JsonObject { ["userId"] = "alice", ["requestId"] = "request", ["status"] = "REQUESTED",
            ["requestedAt"] = OwnerSchema.Iso(fixture.Now), ["ownerAcksJson"] = "[]", ["completedAt"] = null, ["revision"] = 0 }; return id;
    }
}
