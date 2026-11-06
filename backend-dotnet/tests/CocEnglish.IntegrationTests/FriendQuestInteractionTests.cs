using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class FriendQuestInteractionTests
{
    [Theory]
    [InlineData("child", "FORBIDDEN")]
    [InlineData("private", "PROFILE_UNAVAILABLE")]
    [InlineData("blocked", "USER_BLOCKED")]
    [InlineData("deleted", "PROFILE_UNAVAILABLE")]
    [InlineData("poor", "INSUFFICIENT_GEMS")]
    [InlineData("message", "VALIDATION_ERROR")]
    [InlineData("self", "VALIDATION_ERROR")]
    public async Task Interaction_DenialDoesNotSpendOrCreateBoost(string condition, string code)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        await Seed(fixture);
        if (condition == "child") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))]["ageBand"] = "CHILD";
        if (condition == "private") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))]["publicOptIn"] = false;
        if (condition == "deleted") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))]["deletedAt"] = "2026-11-03T00:00:00.000Z";
        if (condition == "blocked") fixture.Driver.Rows[("p_blocks", CanonicalWire.RowId("p_blocks", "bob", "alice"))] = new() { ["userId"] = "bob", ["targetUserId"] = "alice" };
        var commits = fixture.Driver.Commits;
        using var request = Request("/v1/interactions", "alice", new { targetUserId = condition == "self" ? "alice" : "bob", kind = "GIFT_BOOST", contextId = "lesson1", messageKey = condition == "message" ? "nudge.keep_going" : "gift_boost.enjoy" });
        using var response = await client.SendAsync(request);
        Assert.False(response.IsSuccessStatusCode);
        var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal(code, body["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_interactions" or "p_boosts");
        Assert.Equal(20, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
    }

    [Theory]
    [InlineData("NUDGE", "nudge.keep_going", 0)]
    [InlineData("GIFT_BOOST", "gift_boost.enjoy", 50)]
    public async Task Interaction_DeduplicatesByLocalDayAndContextAcrossRequestKeys(string kind, string messageKey, long cost)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        await Seed(fixture);
        fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))]["gems"] = 100;
        for (var i = 0; i < 2; i++)
        {
            using var request = Request("/v1/interactions", "alice", new { targetUserId = "bob", kind, contextId = "lesson1", messageKey });
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal(100 - cost, body["gems"]!.GetValue<long>());
            Assert.Equal(cost, body["gemsCost"]!.GetValue<long>());
            Assert.Equal("2026-11-03", body["day"]!.GetValue<string>());
        }
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_interactions");
        Assert.Equal(cost > 0 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_boosts"));
        if (cost > 0)
        {
            var boost = fixture.Driver.Rows.Single(r => r.Key.Table == "p_boosts").Value;
            Assert.Equal("bob", boost.Text("userId"));
            Assert.Equal("2026-11-03T10:15:00.000Z", boost.Text("endsAt"));
            Assert.Equal(2, boost.Number("multiplier"));
        }
    }

    [Fact]
    public async Task QuestOptIn_PairsMutualFriendAndPreservesSoloProgress()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        await Seed(fixture);
        foreach (var (a, b) in new[] { ("alice", "bob"), ("bob", "alice") })
            fixture.Driver.Rows[("p_follows", CanonicalWire.RowId("p_follows", a, b))] = new() { ["fromUserId"] = a, ["toUserId"] = b, ["status"] = "ACTIVE" };
        using (var request = Request("/v1/friend-quests/opt-in", "bob", new { }))
        using (var response = await client.SendAsync(request)) Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var soloId = CanonicalWire.RowId("p_quests", "bob", "WEEK", "2026-11-02", "friend_solo");
        fixture.Driver.Rows[("p_quests", soloId)]["metricValue"] = 4;
        for (var i = 0; i < 2; i++)
        {
            using var request = Request("/v1/friend-quests/opt-in", "alice", new { });
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
        var pair = Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_friend_quests").Value;
        Assert.Equal("[\"alice\",\"bob\"]", pair.Text("userIdsJson"));
        Assert.Equal(4, pair.Number("count"));
        Assert.Equal(10, pair.Number("target"));
        Assert.False(fixture.Driver.Rows.ContainsKey(("p_quests", soloId)));
        var quests = fixture.Driver.Rows.Where(r => r.Key.Table == "p_quests").ToArray();
        Assert.Equal(2, quests.Length);
        Assert.All(quests, q => Assert.Equal(4, q.Value.Number("metricValue")));
    }

    private static async Task Seed(ProgressApiFixture fixture)
    {
        fixture.Driver.Rows.Clear();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        foreach (var user in new[] { "alice", "bob" })
        {
            await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, user, ct));
            fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", user))]["publicOptIn"] = true;
        }
    }
    private static HttpRequestMessage Request(string path, string user, object body)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = JsonContent.Create(body) };
        request.Headers.Add("Authorization", "Bearer " + user + "-jwt");
        request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        return request;
    }
}
