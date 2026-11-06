using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ProgressSocialTests
{
    [Theory]
    [InlineData("PENDING", "ENDED")]
    [InlineData("ACTIVE", "ENDED")]
    [InlineData("DECLINED", "DECLINED")]
    [InlineData("ENDED", "ENDED")]
    public async Task Block_EndsOnlyOpenFriendStreakAndPreservesHistoricalState(string status, string expected)
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var pair = CanonicalWire.RowId("operation", "friend-streak", "alice", "bob");
        var id = CanonicalWire.RowId("p_friend_streaks", pair);
        factory.Driver.Rows[("p_friend_streaks", id)] = new()
        {
            ["pairId"] = pair, ["userAId"] = "alice", ["userBId"] = "bob", ["inviterId"] = "bob", ["status"] = status,
            ["startDay"] = "2026-11-01", ["length"] = 2, ["lastExtendedDay"] = "2026-11-02", ["endedAt"] = null,
            ["revision"] = 3, ["createdAt"] = "2026-11-01T00:00:00.000Z", ["updatedAt"] = "2026-11-02T00:00:00.000Z"
        };
        await store.TransactAsync((tx, ct) => new ProgressSocial().BlockAsync(tx, "alice", "bob", ct));
        var row = factory.Driver.Rows[("p_friend_streaks", id)];
        Assert.Equal(expected, row.Text("status"));
        Assert.Equal(2, row.Number("length"));
        Assert.Equal(status is "PENDING" or "ACTIVE" ? 4 : 3, row.Number("revision"));
        if (status is "PENDING" or "ACTIVE") Assert.Equal("2026-11-03T10:00:00.000Z", row.Text("endedAt"));
        else Assert.Null(row["endedAt"]);
        Assert.Equal("2026-11-01T00:00:00.000Z", row.Text("createdAt"));
    }

    [Theory]
    [InlineData("/v1/blocks", "{}", "targetUserId")]
    [InlineData("/v1/blocks", "{\"targetUserId\":\"bad/id\"}", "targetUserId")]
    [InlineData("/v1/user-reports", "{\"targetUserId\":\"bob\",\"reason\":\"OTHER\"}", "note")]
    [InlineData("/v1/user-reports", "{\"targetUserId\":\"bob\",\"reason\":\"other\",\"note\":null}", "reason")]
    [InlineData("/v1/user-reports", "{\"targetUserId\":\"bob\",\"reason\":\"SPAM\",\"note\":3}", "note")]
    public async Task SafetyHttp_InvalidWireNeverReadsStorage(string path, string json, string field)
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        using var response = await client.PostAsync(path, new StringContent(json, System.Text.Encoding.UTF8, "application/json"));
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
        var body = System.Text.Json.Nodes.JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal(field, body["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
        Assert.Equal(0, factory.Driver.Commits);
    }
    [Theory]
    [InlineData("/v1/blocks", "{\"targetUserId\":\"bob\"}", "p_blocks")]
    [InlineData("/v1/user-reports", "{\"targetUserId\":\"bob\",\"reason\":\"OTHER\",\"note\":null}", "p_user_reports")]
    public async Task SafetyHttp_ReplaysReceiptWithoutDuplicateWrites(string path, string json, string table)
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        for (var i = 0; i < 2; i++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json") };
            request.Headers.Add("Idempotency-Key", "11111111-1111-4111-8111-111111111111");
            using var response = await client.SendAsync(request);
            Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
            var body = System.Text.Json.Nodes.JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal(i == 0 ? "completed" : "replayed", body["status"]!.GetValue<string>());
        }
        Assert.Single(factory.Driver.Rows, p => p.Key.Table == table);
        Assert.Equal(1, factory.Driver.Commits);
    }
    [Fact]
    public async Task Block_RemovesBothFollowsAndUnblockDoesNotRestoreThem()
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        foreach (var (from, to) in new[] { ("alice", "bob"), ("bob", "alice") })
            factory.Driver.Rows[("p_follows", CanonicalWire.RowId("p_follows", from, to))] = new() { ["fromUserId"] = from, ["toUserId"] = to, ["status"] = "ACTIVE" };
        var app = new ProgressSocial();
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.BlockAsync(tx, "alice", "bob", ct)));
        Assert.Equal(3, factory.Driver.LastWrites.Count);
        Assert.All(factory.Driver.Rows.Where(p => p.Key.Table == "p_follows"), p => Assert.Equal("REMOVED", p.Value.Text("status")));
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => app.BlockAsync(tx, "alice", "bob", ct)));
        Assert.Equal(1, factory.Driver.Commits);
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.UnblockAsync(tx, "alice", "bob", ct)));
        Assert.DoesNotContain(factory.Driver.Rows, p => p.Key.Table == "p_blocks");
        Assert.All(factory.Driver.Rows.Where(p => p.Key.Table == "p_follows"), p => Assert.Equal("REMOVED", p.Value.Text("status")));
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => app.UnblockAsync(tx, "alice", "bob", ct)));
        Assert.Equal(2, factory.Driver.Commits);
    }

    [Fact]
    public async Task Report_IsUniqueByReporterTargetAndReasonAndNeverOverwritesOriginalNote()
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var app = new ProgressSocial();
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.ReportAsync(tx, "alice", "unknown", "OTHER", "Lỗi 😀", ct)));
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => app.ReportAsync(tx, "alice", "unknown", "OTHER", "changed", ct)));
        var row = Assert.Single(factory.Driver.Rows, p => p.Key.Table == "p_user_reports").Value;
        Assert.Equal("Lỗi 😀", row.Text("note"));
        Assert.Equal("OPEN", row.Text("status"));
        Assert.Equal("alice", row.Text("reporterId"));
        Assert.Equal(1, factory.Driver.Commits);
        Assert.Equal("VALIDATION_ERROR", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.ReportAsync(tx, "alice", "alice", "OTHER", null, ct)))).Code);
        Assert.Equal("VALIDATION_ERROR", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.BlockAsync(tx, "alice", "alice", ct)))).Code);
        Assert.Equal(1, factory.Driver.Commits);
    }
    [Fact]
    public async Task Friends_SkipsPrivateMutualAccountsAndCursorTracksScannedCandidates()
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        foreach (var target in new[] { "a-private", "bob", "carol" })
        {
            factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", target))] = new()
            { ["userId"] = target, ["nickname"] = target, ["ageBand"] = "ADULT", ["publicOptIn"] = target != "a-private" };
            foreach (var (from, to) in new[] { ("alice", target), (target, "alice") })
                factory.Driver.Rows[("p_follows", CanonicalWire.RowId("p_follows", from, to))] = new() { ["fromUserId"] = from, ["toUserId"] = to, ["status"] = "ACTIVE" };
        }
        var app = new ProgressSocial();
        var first = await store.TransactAsync((tx, ct) => app.FriendsAsync(tx, "alice", 0, 1, ct));
        Assert.Equal("bob", Assert.Single(first.Items).UserId);
        Assert.Equal("friend", first.Items[0].FollowStatus);
        Assert.Equal("eyJvIjoyfQ", first.NextCursor);
        var next = await store.TransactAsync((tx, ct) => app.FriendsAsync(tx, "alice", 2, 1, ct));
        Assert.Equal("carol", Assert.Single(next.Items).UserId);
        Assert.Null(next.NextCursor);
        Assert.Equal(0, factory.Driver.Commits);
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        using var response = await client.GetAsync("/v1/friends?limit=1");
        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        var json = System.Text.Json.Nodes.JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal("bob", json["items"]![0]!["userId"]!.GetValue<string>());
        Assert.Equal("eyJvIjoyfQ", json["nextCursor"]!.GetValue<string>());
    }

    [Fact]
    public async Task Activity_FiltersAuthorPrivacyAndVisibilityButIncludesOwnPrivateActivity()
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        foreach (var user in new[] { "bob", "private", "blocked" })
        {
            factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", user))] = new() { ["userId"] = user, ["publicOptIn"] = user != "private", ["ageBand"] = "ADULT" };
            factory.Driver.Rows[("p_follows", user)] = new() { ["fromUserId"] = "alice", ["toUserId"] = user, ["status"] = "ACTIVE" };
        }
        factory.Driver.Rows[("p_blocks", CanonicalWire.RowId("p_blocks", "blocked", "alice"))] = new();
        foreach (var (id, user, visible, kind) in new[] { ("a", "alice", false, "QUEST"), ("b", "bob", true, "STREAK"), ("c", "bob", false, "QUEST"), ("d", "private", true, "QUEST"), ("e", "blocked", true, "QUEST"), ("f", "alice", true, "UNKNOWN") })
            factory.Driver.Rows[("p_activity", id)] = new() { ["eventId"] = id, ["userId"] = user, ["visible"] = visible, ["kind"] = kind, ["publicSummary"] = id, ["createdAt"] = "2026-11-03T10:00:00.000Z" };
        var app = new ProgressSocial();
        var page = await store.TransactAsync((tx, ct) => app.ActivityAsync(tx, "alice", 0, 10, ct));
        Assert.Equal(new[] { "a", "b" }, page.Items.Select(i => i.EventId));
        Assert.Null(page.NextCursor);
        Assert.Equal(0, factory.Driver.Commits);
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        using var response = await client.GetAsync("/v1/activity?limit=10");
        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        var json = System.Text.Json.Nodes.JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal(new[] { "a", "b" }, json["items"]!.AsArray().Select(i => i!["eventId"]!.GetValue<string>()));
        Assert.Equal("2026-11-03T10:00:00.000Z", json["items"]![0]!["createdAt"]!.GetValue<string>());
    }
    [Theory]
    [InlineData(999, true)]
    [InlineData(1000, false)]
    [InlineData(1001, false)]
    public async Task Follow_LimitCountsOnlyActiveOutgoingRows(int count, bool allowed)
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new()
        { ["userId"] = "bob", ["publicOptIn"] = true, ["ageBand"] = "ADULT" };
        for (var i = 0; i < count; i++) factory.Driver.Rows[("p_follows", "out-" + i)] = new()
        { ["fromUserId"] = "alice", ["toUserId"] = "target-" + i, ["status"] = "ACTIVE" };
        factory.Driver.Rows[("p_follows", "removed")] = new() { ["fromUserId"] = "alice", ["status"] = "REMOVED" };
        factory.Driver.Rows[("p_follows", "incoming")] = new() { ["fromUserId"] = "bob", ["toUserId"] = "alice", ["status"] = "ACTIVE" };
        var app = new ProgressSocial();
        if (allowed)
        {
            Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.FollowAsync(tx, "alice", "bob", ct)));
            Assert.Equal(1, factory.Driver.Commits);
        }
        else
        {
            var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.FollowAsync(tx, "alice", "bob", ct)));
            Assert.Equal("VALIDATION_ERROR", error.Code);
            Assert.Equal("FOLLOW_LIMIT", error.Details.Text("reason"));
            Assert.Equal(0, factory.Driver.Commits);
        }
    }
    [Fact]
    public async Task Http_ProjectsOnlyPublicFieldsAndReplaysFollowReceipt()
    {
        await using var factory = new ProgressApiFixture();
        factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new()
        { ["userId"] = "bob", ["nickname"] = "Bob", ["publicOptIn"] = true, ["ageBand"] = "ADULT", ["email"] = "hidden@example.test" };
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        const string key = "11111111-1111-4111-8111-111111111111";
        for (var i = 0; i < 2; i++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/follows") { Content = new StringContent("{\"targetUserId\":\"bob\"}", System.Text.Encoding.UTF8, "application/json") };
            request.Headers.Add("Idempotency-Key", key);
            using var response = await client.SendAsync(request);
            Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
            var receipt = System.Text.Json.Nodes.JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal(i == 0 ? "completed" : "replayed", receipt["status"]!.GetValue<string>());
        }
        using var profileResponse = await client.GetAsync("/v1/profiles/bob");
        Assert.Equal(System.Net.HttpStatusCode.OK, profileResponse.StatusCode);
        var profile = System.Text.Json.Nodes.JsonNode.Parse(await profileResponse.Content.ReadAsStringAsync())!.AsObject();
        Assert.Equal(new[] { "achievementIds", "avatarId", "followStatus", "nickname", "streak", "studyXp", "userId" }, profile.Select(p => p.Key).Order(StringComparer.Ordinal));
        Assert.Equal("following", profile["followStatus"]!.GetValue<string>());
        Assert.Equal(1, factory.Driver.Commits);
        using var unfollow = new HttpRequestMessage(HttpMethod.Delete, "/v1/follows/bob");
        unfollow.Headers.Add("Idempotency-Key", key);
        using var removed = await client.SendAsync(unfollow);
        Assert.Equal(System.Net.HttpStatusCode.OK, removed.StatusCode);
        Assert.Equal("REMOVED", factory.Driver.Rows[("p_follows", CanonicalWire.RowId("p_follows", "alice", "bob"))].Text("status"));
    }
    [Fact]
    public async Task Follow_TransitionsFromNoneToFollowingToFriendAndUnfollowIsSilent()
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var social = new ProgressSocial();
        foreach (var user in new[] { "alice", "bob" })
        {
            factory.Driver.Rows.Remove(("p_profiles", CanonicalWire.RowId("p_profiles", user)));
            await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, user, ct));
            factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", user))]["publicOptIn"] = true;
        }
        Assert.Equal("none", (await store.TransactAsync((tx, ct) => social.GetProfileAsync(tx, "alice", "bob", ct))).FollowStatus);
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => social.FollowAsync(tx, "alice", "bob", ct)));
        Assert.Equal("following", (await store.TransactAsync((tx, ct) => social.GetProfileAsync(tx, "alice", "bob", ct))).FollowStatus);
        var commits = factory.Driver.Commits;
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => social.FollowAsync(tx, "alice", "bob", ct)));
        Assert.Equal(commits, factory.Driver.Commits);
        await store.TransactAsync((tx, ct) => social.FollowAsync(tx, "bob", "alice", ct));
        Assert.Equal("friend", (await store.TransactAsync((tx, ct) => social.GetProfileAsync(tx, "alice", "bob", ct))).FollowStatus);
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => social.UnfollowAsync(tx, "alice", "bob", ct)));
        Assert.Equal("none", (await store.TransactAsync((tx, ct) => social.GetProfileAsync(tx, "alice", "bob", ct))).FollowStatus);
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => social.UnfollowAsync(tx, "alice", "unknown", ct)));
    }

    [Theory]
    [InlineData("private", "PROFILE_UNAVAILABLE")]
    [InlineData("child-target", "PROFILE_UNAVAILABLE")]
    [InlineData("blocked", "USER_BLOCKED")]
    [InlineData("reverse-blocked", "USER_BLOCKED")]
    [InlineData("deleted", "PROFILE_UNAVAILABLE")]
    [InlineData("child-viewer", "FORBIDDEN")]
    public async Task Privacy_DeniesFollowWithoutWritesAndHidesTargetWithoutReason(string scenario, string followCode)
    {
        await using var factory = new ProgressApiFixture();
        using var client = factory.CreateClient();
        using var scope = factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new()
        { ["userId"] = "bob", ["nickname"] = "Bob", ["publicOptIn"] = scenario != "private", ["ageBand"] = scenario == "child-target" ? "CHILD" : "ADULT" };
        if (scenario == "child-viewer") factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["ageBand"] = "CHILD";
        if (scenario == "deleted") factory.Driver.Rows[("p_deletions", CanonicalWire.RowId("p_deletions", "bob"))] = new() { ["userId"] = "bob" };
        if (scenario.Contains("blocked", StringComparison.Ordinal))
        {
            var reverse = scenario == "reverse-blocked";
            factory.Driver.Rows[("p_blocks", CanonicalWire.RowId("p_blocks", reverse ? "bob" : "alice", reverse ? "alice" : "bob"))] = new();
        }
        var app = new ProgressSocial();
        Assert.Equal(followCode, (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.FollowAsync(tx, "alice", "bob", ct)))).Code);
        if (scenario != "child-viewer") Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.GetProfileAsync(tx, "alice", "bob", ct)))).Code);
        Assert.Equal(0, factory.Driver.Commits);
    }
}
