using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class FamilyTests
{
    [Theory]
    [InlineData("full", "REVISION_CONFLICT")]
    [InlineData("other-family", "REVISION_CONFLICT")]
    [InlineData("ended", "NOT_FOUND")]
    [InlineData("wrong-code", "NOT_FOUND")]
    public async Task Join_DenialsPreserveMembersAndEntitlements(string condition, string error)
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient(); Seed(fixture);
        var created = await Call(client, "POST", "/v1/family", "alice", new { plan = "MAX" });
        var group = created["groupId"]!.GetValue<string>(); var code = created["inviteCode"]!.GetValue<string>();
        var row = fixture.Driver.Rows[("p_family_groups", CanonicalWire.RowId("p_family_groups", group))];
        if (condition == "ended") row["status"] = "ENDED";
        if (condition == "full") row["memberIdsJson"] = new JsonArray(Enumerable.Range(0, 6).Select(i => (JsonNode)new JsonArray(JsonValue.Create(i == 0 ? "alice" : "u" + i), JsonValue.Create("2026-11-03T10:00:00.000Z"))).ToArray()).ToJsonString();
        if (condition == "other-family") fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))] = new() { ["familyGroupId"] = "other" };
        var previous = row.ToJsonString(); var commits = fixture.Driver.Commits;
        using var request = Request("POST", $"/v1/family/{group}/members", "bob", new { inviteCode = condition == "wrong-code" ? "WRONG" : code });
        using var response = await client.SendAsync(request);
        Assert.Equal(error, JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.Equal(previous, fixture.Driver.Rows[("p_family_groups", CanonicalWire.RowId("p_family_groups", group))].ToJsonString());
    }

    [Fact]
    public async Task Join_CapacityFiveAllowsSixthAndRejectsSeventhWithoutWrites()
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient();
        Seed(fixture);
        var created = await Call(client, "POST", "/v1/family", "alice", new { plan = "MAX" });
        var group = created["groupId"]!.GetValue<string>();
        var code = created["inviteCode"]!.GetValue<string>();
        var groupRow = fixture.Driver.Rows[("p_family_groups", CanonicalWire.RowId("p_family_groups", group))];
        groupRow["memberIdsJson"] = new JsonArray(Enumerable.Range(0, 5)
            .Select(i => (JsonNode)new JsonArray(JsonValue.Create(i == 0 ? "alice" : "m" + i), JsonValue.Create("2026-11-03T10:00:00.000Z")))
            .ToArray()).ToJsonString();
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "carol"))] = new()
        { ["userId"] = "carol", ["nickname"] = "Carol", ["learningZone"] = "UTC" };

        var sixth = await Call(client, "POST", $"/v1/family/{group}/members", "bob", new { inviteCode = code });
        Assert.Equal(6, sixth["members"]!.AsArray().Count);
        Assert.Contains(sixth["members"]!.AsArray(), member => member?["userId"]?.GetValue<string>() == "bob");
        Assert.Equal(group, fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))].Text("familyGroupId"));

        var membersBeforeSeventh = groupRow["memberIdsJson"]!.GetValue<string>();
        var commitsBeforeSeventh = fixture.Driver.Commits;
        using var request = Request("POST", $"/v1/family/{group}/members", "carol", new { inviteCode = code });
        using var response = await client.SendAsync(request);
        var error = JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!;
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("REVISION_CONFLICT", error["code"]!.GetValue<string>());
        Assert.Equal("FAMILY_FULL", error["details"]!["reason"]!.GetValue<string>());
        Assert.Equal(commitsBeforeSeventh, fixture.Driver.Commits);
        Assert.Equal(membersBeforeSeventh, groupRow["memberIdsJson"]!.GetValue<string>());
        Assert.DoesNotContain(fixture.Driver.Rows, row => row.Key.Table == "p_entitlements" && row.Value["userId"]?.GetValue<string>() == "carol");
    }

    [Fact]
    public async Task Join_ConcurrentRequestsForLastSeatAdmitOnlyOneMember()
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        fixture.Driver.EnforceReadVersions = true;
        using var client = fixture.CreateClient();
        Seed(fixture);
        var created = await Call(client, "POST", "/v1/family", "alice", new { plan = "MAX" });
        var group = created["groupId"]!.GetValue<string>();
        var code = created["inviteCode"]!.GetValue<string>();
        var groupId = CanonicalWire.RowId("p_family_groups", group);
        var groupRow = fixture.Driver.Rows[("p_family_groups", groupId)];
        groupRow["memberIdsJson"] = new JsonArray(Enumerable.Range(0, 5)
            .Select(i => (JsonNode)new JsonArray(JsonValue.Create(i == 0 ? "alice" : "m" + i), JsonValue.Create("2026-11-03T10:00:00.000Z")))
            .ToArray()).ToJsonString();
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "carol"))] = new()
        { ["userId"] = "carol", ["nickname"] = "Carol", ["learningZone"] = "UTC" };
        fixture.Driver.ArmReadBarrier("p_family_groups", groupId, 2);
        var commitsBefore = fixture.Driver.Commits;

        using var bobRequest = Request("POST", $"/v1/family/{group}/members", "bob", new { inviteCode = code });
        using var carolRequest = Request("POST", $"/v1/family/{group}/members", "carol", new { inviteCode = code });
        var responses = await Task.WhenAll(client.SendAsync(bobRequest), client.SendAsync(carolRequest));
        try
        {
            Assert.Equal(2, fixture.Driver.BarrierReads);
            var joined = Assert.Single(responses, response => response.StatusCode == HttpStatusCode.OK);
            var rejected = Assert.Single(responses, response => response.StatusCode == HttpStatusCode.Conflict);
            var failure = JsonNode.Parse(await rejected.Content.ReadAsStringAsync())!["error"]!;
            Assert.Equal("REVISION_CONFLICT", failure["code"]!.GetValue<string>());
            Assert.Equal("FAMILY_FULL", failure["details"]!["reason"]!.GetValue<string>());
            Assert.Equal(6, JsonNode.Parse(await joined.Content.ReadAsStringAsync())!["members"]!.AsArray().Count);

            var persistedGroup = fixture.Driver.Rows[("p_family_groups", groupId)];
            var persistedMembers = JsonNode.Parse(persistedGroup["memberIdsJson"]!.GetValue<string>())!.AsArray();
            var memberIds = persistedMembers.Select(member => member![0]!.GetValue<string>()).ToHashSet(StringComparer.Ordinal);
            Assert.Equal(6, memberIds.Count);
            Assert.NotEqual(memberIds.Contains("bob"), memberIds.Contains("carol"));
            var admittedUser = memberIds.Contains("bob") ? "bob" : "carol";
            var deniedUser = admittedUser == "bob" ? "carol" : "bob";
            Assert.Equal(group, fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", admittedUser))].Text("familyGroupId"));
            Assert.DoesNotContain(fixture.Driver.Rows, row => row.Key.Table == "p_entitlements" && row.Value["userId"]?.GetValue<string>() == deniedUser);
            Assert.Equal(commitsBefore + 1, fixture.Driver.Commits);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [Theory]
    [InlineData("alice", "alice", "VALIDATION_ERROR")]
    [InlineData("bob", "other", "FORBIDDEN")]
    public async Task Remove_ProtectsManagerAndRejectsUnrelatedActor(string actor, string target, string error)
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient(); Seed(fixture);
        var group = (await Call(client, "POST", "/v1/family", "alice", new { plan = "MAX" }))["groupId"]!.GetValue<string>();
        var commits = fixture.Driver.Commits;
        using var request = Request("DELETE", $"/v1/family/{group}/members/{target}", actor, new { });
        using var response = await client.SendAsync(request);
        Assert.Equal(error, JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(commits, fixture.Driver.Commits);
    }

    [Fact]
    public async Task CreateJoinLeave_PreservesManagerCodeAndRevokesMemberAccess()
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> { ["COC_PROGRESS_CODE_SECRET"] = "local-test-code-secret" })));
        using var client = app.CreateClient();
        Seed(fixture);
        var created = await Call(client, "POST", "/v1/family", "alice", new { plan = "MAX" });
        var group = created["groupId"]!.GetValue<string>(); var code = created["inviteCode"]!.GetValue<string>();
        Assert.Equal(8, code.Length);
        Assert.Equal("MANAGER", created["members"]![0]!["role"]!.GetValue<string>());
        var joined = await Call(client, "POST", $"/v1/family/{group}/members", "bob", new { inviteCode = code.ToLowerInvariant() });
        Assert.Null(joined["inviteCode"]);
        Assert.Equal(2, joined["members"]!.AsArray().Count);
        Assert.Equal("FAMILY", fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))].Text("source"));
        Assert.Equal("MAX", fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))].Text("plan"));
        var replay = await Call(client, "POST", $"/v1/family/{group}/members", "bob", new { inviteCode = code });
        Assert.Equal(2, replay["members"]!.AsArray().Count);
        Assert.Equal(2, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
        var removed = await Call(client, "DELETE", $"/v1/family/{group}/members/bob", "bob", new { });
        Assert.Single(removed["members"]!.AsArray());
        var entitlement = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))];
        Assert.Equal("FREE", entitlement.Text("plan")); Assert.Equal("REVOKED", entitlement.Text("status")); Assert.Null(entitlement["familyGroupId"]);
        Assert.Equal(3, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
    }

    [Theory]
    [InlineData("free", "ENTITLEMENT_REQUIRED")]
    [InlineData("family", "ENTITLEMENT_REQUIRED")]
    [InlineData("super", "ENTITLEMENT_REQUIRED")]
    [InlineData("already", "REVISION_CONFLICT")]
    [InlineData("secret", "SERVICE_NOT_CONFIGURED")]
    public async Task Create_DenialsLeaveNoGroupOrEvent(string condition, string error)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> { ["COC_PROGRESS_CODE_SECRET"] = condition == "secret" ? null : "local-test-code-secret" })));
        using var client = app.CreateClient(); Seed(fixture);
        var entitlement = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))];
        if (condition == "free") entitlement["plan"] = "FREE";
        if (condition == "family") entitlement["source"] = "FAMILY";
        if (condition == "super") entitlement["plan"] = "SUPER";
        if (condition == "already") entitlement["familyGroupId"] = "other";
        using var request = Request("POST", "/v1/family", "alice", new { plan = "MAX" });
        using var response = await client.SendAsync(request);
        Assert.False(response.IsSuccessStatusCode);
        Assert.Equal(error, JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_family_groups" or "p_outbox");
    }

    [Fact]
    public async Task Create_ActiveSuperPurchaseCanCreateSuperFamily()
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient();
        Seed(fixture);
        var ownerEntitlement = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))];
        ownerEntitlement["plan"] = "SUPER";

        var created = await Call(client, "POST", "/v1/family", "alice", new { plan = "SUPER" });
        var group = created["groupId"]!.GetValue<string>();
        var groupRow = fixture.Driver.Rows[("p_family_groups", CanonicalWire.RowId("p_family_groups", group))];
        var persistedEntitlement = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))];

        Assert.Equal("SUPER", groupRow.Text("plan"));
        Assert.Equal("ACTIVE", groupRow.Text("status"));
        Assert.Equal(group, persistedEntitlement.Text("familyGroupId"));
        Assert.Equal("SUPER", persistedEntitlement.Text("plan"));
        Assert.Equal("2026-12-01T00:00:00.000Z", persistedEntitlement.Text("expiresAt"));
    }

    [Fact]
    public async Task Create_ExpiryAtNowDeniesFamilyWithoutWrites()
    {
        await using var fixture = new ProgressApiFixture { CodeSecret = "local-test-code-secret" };
        using var client = fixture.CreateClient();
        Seed(fixture);
        fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))]["expiresAt"] = "2026-11-03T10:00:00.000Z";
        var commits = fixture.Driver.Commits;

        using var request = Request("POST", "/v1/family", "alice", new { plan = "MAX" });
        using var response = await client.SendAsync(request);
        var error = JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!;

        Assert.Equal("ENTITLEMENT_REQUIRED", error["code"]!.GetValue<string>());
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, row => row.Key.Table is "p_family_groups" or "p_outbox" or "p_receipts");
    }

    private static void Seed(ProgressApiFixture fixture)
    {
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["nickname"] = "Bob", ["learningZone"] = "UTC" };
        fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new() { ["userId"] = "alice", ["plan"] = "MAX", ["source"] = "PURCHASE", ["status"] = "ACTIVE", ["expiresAt"] = "2026-12-01T00:00:00.000Z", ["autoRenew"] = true, ["familyGroupId"] = null, ["purchaseId"] = "purchase1", ["giftId"] = null, ["revision"] = 0 };
    }
    private static HttpRequestMessage Request(string method, string path, string user, object body)
    {
        var request = new HttpRequestMessage(new HttpMethod(method), path) { Content = JsonContent.Create(body) };
        request.Headers.Add("Authorization", "Bearer " + user + "-jwt"); request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        return request;
    }
    private static async Task<JsonNode> Call(HttpClient client, string method, string path, string user, object body)
    {
        using var request = Request(method, path, user, body); using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
    }
}
