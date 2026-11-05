using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;
using Factory = CocEnglish.IntegrationTests.ProgressApiFixture;

namespace CocEnglish.IntegrationTests;

public sealed class ProgressMutationApiTests
{
    private const string Key = "11111111-1111-4111-8111-111111111111";

    [Fact]
    public async Task Claim_EncodedParameterAndPlainPathShareOneReceiptOnKestrel()
    {
        await using var factory = new Factory();
        factory.UseKestrel(0);
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initialize = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initialize.StatusCode);
        factory.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", "daily_lessons"))] = new()
        { ["userId"] = "alice", ["questId"] = "daily_lessons", ["period"] = "DAY", ["periodKey"] = "2026-11-03", ["metricValue"] = 2, ["target"] = 2, ["claimed"] = false, ["claimOperationId"] = null };
        const string body = """{"periodKey":"2026-11-03"}""";
        var uri = new Uri(client.BaseAddress!.GetLeftPart(UriPartial.Authority) + "/v1/quests/daily%5Flessons/claim", new UriCreationOptions { DangerousDisablePathAndQueryCanonicalization = true });
        using var request = new HttpRequestMessage(HttpMethod.Post, uri) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("Idempotency-Key", Key);
        using var first = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var reward = await Body(first);
        using var replay = await Send(client, "/v1/quests/daily_lessons/claim", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(reward, await Body(replay)));
        Assert.Equal(2, factory.Driver.Commits);
    }

    [Theory]
    [InlineData("/HEALTH")]
    [InlineData("/%68ealth")]
    [InlineData("/health/")]
    public async Task Health_AliasesNeverBecomePublicOnRealKestrel(string path)
    {
        await using var factory = new Factory();
        factory.UseKestrel(0);
        using var client = factory.CreateClient();
        var uri = new Uri(client.BaseAddress!.GetLeftPart(UriPartial.Authority) + path, new UriCreationOptions { DangerousDisablePathAndQueryCanonicalization = true });
        using var response = await client.GetAsync(uri);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("AUTH_REQUIRED", (await Body(response))["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Fact]
    public async Task Shop_HttpCatalogPurchaseActivationAndRepairPreserveReceiptsAndWireDates()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initialize = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initialize.StatusCode);
        var walletId = CanonicalWire.RowId("p_rewards", "alice");
        factory.Driver.Rows[("p_rewards", walletId)]["gems"] = 200;
        using var catalogResponse = await client.GetAsync("/v1/shop");
        Assert.Equal(HttpStatusCode.OK, catalogResponse.StatusCode);
        var catalog = await Body(catalogResponse);
        Assert.Equal("shop-v1", catalog["catalogVersion"]!.GetValue<string>());
        Assert.Equal(6, catalog["items"]!.AsArray().Count);
        Assert.Equal("2026-11-03T10:00:00.000Z", catalog["asOf"]!.GetValue<string>());
        const string purchaseBody = """{"itemId":"xp_boost_15","quantity":1,"catalogVersion":"shop-v1"}""";
        using var buy = await Send(client, "/v1/shop/purchases", purchaseBody);
        Assert.Equal(HttpStatusCode.OK, buy.StatusCode);
        var bought = await Body(buy);
        Assert.Equal(100, bought["gems"]!.GetValue<int>());
        Assert.Equal(100, bought["gemsSpent"]!.GetValue<int>());
        Assert.False(bought["energyGrantPending"]!.GetValue<bool>());
        Assert.Equal(1, bought["inventory"]!["quantity"]!.GetValue<int>());
        using var buyReplay = await Send(client, "/v1/shop/purchases", purchaseBody);
        Assert.True(JsonNode.DeepEquals(bought, await Body(buyReplay)));
        Assert.Equal(2, factory.Driver.Commits);
        const string activationBody = """{"itemId":"xp_boost_15"}""";
        using var activation = await Send(client, "/v1/me/boosts", activationBody);
        Assert.Equal(HttpStatusCode.OK, activation.StatusCode);
        var boost = await Body(activation);
        Assert.Equal("2026-11-03T10:00:00.000Z", boost["startsAt"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:15:00.000Z", boost["endsAt"]!.GetValue<string>());
        Assert.Equal(0, boost["inventory"]!["quantity"]!.GetValue<int>());
        using var activationReplay = await Send(client, "/v1/me/boosts", activationBody);
        Assert.Equal(HttpStatusCode.OK, activationReplay.StatusCode);
        Assert.True(JsonNode.DeepEquals(boost, await Body(activationReplay)));
        var wallet = factory.Driver.Rows[("p_rewards", walletId)];
        wallet["lostStreak"] = 5; wallet["lostStreakDay"] = "2026-11-02"; wallet["lastQualifiedDay"] = "2026-11-01";
        const string repairBody = """{"lostStreakDay":"2026-11-02","payWith":"GEMS"}""";
        using var repair = await Send(client, "/v1/me/streak-repair", repairBody);
        Assert.Equal(HttpStatusCode.OK, repair.StatusCode);
        var repaired = await Body(repair);
        Assert.Equal(0, repaired["gems"]!.GetValue<int>());
        Assert.Equal(0, factory.Driver.Rows[("p_rewards", walletId)].Number("lostStreak"));
        using var repairReplay = await Send(client, "/v1/me/streak-repair", repairBody);
        Assert.Equal(HttpStatusCode.OK, repairReplay.StatusCode);
        Assert.True(JsonNode.DeepEquals(repaired, await Body(repairReplay)));
        Assert.Equal(4, factory.Driver.Commits);
    }

    [Fact]
    public async Task Shop_HttpEnergyRefillQueuesOneOwnerGrantWithoutFakeLearningMutation()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initialize = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initialize.StatusCode);
        factory.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))]["gems"] = 50;
        const string body = """{"itemId":"energy_refill","quantity":1,"catalogVersion":"shop-v1"}""";
        using var first = await Send(client, "/v1/shop/purchases", body);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var purchase = await Body(first);
        Assert.True(purchase["energyGrantPending"]!.GetValue<bool>());
        Assert.Null(purchase["inventory"]);
        using var replay = await Send(client, "/v1/shop/purchases", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(purchase, await Body(replay)));
        Assert.Single(factory.Driver.Rows, r => r.Key.Table == "p_outbox");
        Assert.All(factory.Driver.Rows.Keys, row => Assert.StartsWith("p_", row.Table));
    }

    [Theory]
    [InlineData("/v1/shop/purchases", "{\"itemId\":\"timer_boost\",\"quantity\":0,\"catalogVersion\":\"shop-v1\"}", "quantity")]
    [InlineData("/v1/shop/purchases", "{\"itemId\":\"timer_boost\",\"quantity\":11,\"catalogVersion\":\"shop-v1\"}", "quantity")]
    [InlineData("/v1/shop/purchases", "{\"itemId\":\"timer_boost\",\"quantity\":\"1\",\"catalogVersion\":\"shop-v1\"}", "quantity")]
    [InlineData("/v1/shop/purchases", "{\"itemId\":\"bad/id\",\"quantity\":1,\"catalogVersion\":\"shop-v1\"}", "itemId")]
    [InlineData("/v1/me/boosts", "{}", "itemId")]
    [InlineData("/v1/me/boosts", "{\"itemId\":null}", "itemId")]
    [InlineData("/v1/me/streak-repair", "{\"lostStreakDay\":\"2026-11-03\",\"payWith\":\"FREE\"}", "payWith")]
    [InlineData("/v1/me/streak-repair", "{\"lostStreakDay\":\"2026-11\",\"payWith\":\"GEMS\"}", "lostStreakDay")]
    public async Task Shop_WireValidationFailsBeforeStorage(string path, string body, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, path, body);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(field, (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Fact]
    public async Task Freeze_HttpDebitsExactlyOnceAndKeepsRewardWireShape()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initial = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initial.StatusCode);
        using var first = await Send(client, "/v1/me/freezes", "");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var reward = (await Body(first)).AsObject();
        Assert.Equal(0, reward["gems"]!.GetValue<int>());
        Assert.Equal(1, reward["freezeSlots"]!.GetValue<int>());
        Assert.Null(reward["completionId"]);
        Assert.False(reward.ContainsKey("chest"));
        Assert.Equal(4, factory.Driver.LastWrites.Count);
        using var replay = await Send(client, "/v1/me/freezes", "{}");
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(reward, await Body(replay)));
        Assert.Equal(2, factory.Driver.Commits);
        using var insufficient = await Send(client, "/v1/me/freezes", "{}", "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.Conflict, insufficient.StatusCode);
        Assert.Equal("INSUFFICIENT_GEMS", (await Body(insufficient))["error"]!["code"]!.GetValue<string>());
        Assert.Equal(2, factory.Driver.Commits);
    }

    [Fact]
    public async Task Claim_HttpPermanentlyDeduplicatesQuestAndBindsReceiptToPathParameters()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initial = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initial.StatusCode);
        foreach (var (id, target) in new[] { ("daily_lessons", 2), ("daily_review", 1) })
            factory.Driver.Rows[("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-03", id))] = new()
            { ["userId"] = "alice", ["questId"] = id, ["period"] = "DAY", ["periodKey"] = "2026-11-03", ["metricValue"] = target, ["target"] = target, ["claimed"] = false, ["claimOperationId"] = null };
        const string body = """{"periodKey":"2026-11-03"}""";
        using var first = await Send(client, "/v1/quests/daily_lessons/claim", body);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var reward = await Body(first);
        Assert.Equal(25, reward["gems"]!.GetValue<int>());
        using var replay = await Send(client, "/v1/quests/daily_lessons/claim", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(reward, await Body(replay)));
        using var substitution = await Send(client, "/v1/quests/daily_review/claim", body);
        Assert.Equal(HttpStatusCode.Conflict, substitution.StatusCode);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await Body(substitution))["error"]!["code"]!.GetValue<string>());
        using var another = await Send(client, "/v1/quests/daily_lessons/claim", body, "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.OK, another.StatusCode);
        Assert.Equal(25, (await Body(another))["gems"]!.GetValue<int>());
        Assert.Single(factory.Driver.LastWrites);
        Assert.Equal("p_receipts", factory.Driver.LastWrites[0].Table);
    }

    [Theory]
    [InlineData("{}", "periodKey")]
    [InlineData("{\"periodKey\":null}", "periodKey")]
    [InlineData("{\"periodKey\":\"2026-11-03\",\"upgradeChest\":null}", "upgradeChest")]
    [InlineData("{\"periodKey\":\"2026-11-03\",\"userId\":\"bob\"}", "userId")]
    public async Task Claim_RejectsMalformedWireBeforeReadingStorage(string json, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/quests/daily_lessons/claim", json);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(field, (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Theory]
    [InlineData("/v1/quests/bad!id/claim")]
    [InlineData("/v1/quests/bad%2Fid/claim")]
    [InlineData("/v1/%71uests/daily_lessons/claim")]
    public async Task Claim_PathScopeRejectsInvalidIdsAndEncodedLiteralAliases(string path)
    {
        await using var factory = new Factory();
        factory.UseKestrel(0);
        using var client = Client(factory);
        // TestServer loses RawTarget; exercise Kestrel with an actual, unnormalized wire path.
        var uri = new Uri(client.BaseAddress!.GetLeftPart(UriPartial.Authority) + path,
            new UriCreationOptions { DangerousDisablePathAndQueryCanonicalization = true });
        using var request = new HttpRequestMessage(HttpMethod.Post, uri) { Content = new StringContent("{\"periodKey\":\"2026-11-03\"}", Encoding.UTF8, "application/json") };
        request.Headers.Add("Idempotency-Key", Key);
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("NOT_FOUND", (await Body(response))["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Fact]
    public async Task Deletion_HttpReturnsAcceptedAndReplaysWithoutDuplicatingOutbox()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initialize = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initialize.StatusCode);
        const string body = """{"confirmation":"DELETE"}""";
        using var response = await Send(client, "/v1/me/deletion", body);
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var receipt = await Body(response);
        Assert.Equal("REQUESTED", receipt["status"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", receipt["requestedAt"]!.GetValue<string>());
        Assert.Equal(new[] { "p_deletions", "p_outbox", "p_profiles", "p_receipts" }, factory.Driver.LastWrites.Select(w => w.Table).Order(StringComparer.Ordinal));
        using var replay = await Send(client, "/v1/me/deletion", body);
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(receipt, await Body(replay)));
        using var another = await Send(client, "/v1/me/deletion", body, "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.Accepted, another.StatusCode);
        Assert.True(JsonNode.DeepEquals(receipt, await Body(another)));
        Assert.Single(factory.Driver.Rows, p => p.Key.Table == "p_outbox");
        using var me = await client.GetAsync("/v1/me");
        Assert.Equal(HttpStatusCode.NotFound, me.StatusCode);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Body(me))["error"]!["code"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("{\"confirmation\":\"delete\"}")]
    [InlineData("{\"confirmation\":null}")]
    public async Task Deletion_RequiresExactConfirmationBeforeReadingStorage(string json)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/deletion", json);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("confirmation", (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
        Assert.Equal(0, factory.Driver.Commits);
    }

    [Fact]
    public async Task SameOperationKeyIsIsolatedBetweenVerifiedAccounts()
    {
        await using var factory = new Factory();
        factory.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["learningZone"] = "UTC" };
        using var alice = Client(factory);
        using var first = await Send(alice, "/v1/me/preferences", """{"expectedRevision":0,"soundEffects":false}""");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        using var bob = Client(factory);
        bob.DefaultRequestHeaders.Authorization = new("Bearer", "bob-jwt");
        bob.DefaultRequestHeaders.Remove("X-Appwrite-User-ID");
        bob.DefaultRequestHeaders.Add("X-Appwrite-User-ID", "alice");
        using var second = await Send(bob, "/v1/me/preferences", """{"expectedRevision":0,"haptics":false}""");
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.True((await Body(second))["soundEffects"]!.GetValue<bool>());
        Assert.False(factory.Driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))].Flag("soundEffects"));
        Assert.True(factory.Driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))].Flag("haptics"));
        Assert.False(factory.Driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "bob"))].Flag("haptics"));
        Assert.Equal(new[] { "alice", "bob" }, factory.Driver.Rows.Where(p => p.Key.Table == "p_receipts").Select(p => p.Value.Text("userId")).Order(StringComparer.Ordinal));
    }

    [Fact]
    public async Task ProfileUpdate_HttpNormalizesReplaysAndClearsAvatar()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var initial = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, initial.StatusCode);
        const string json = """{"expectedRevision":0,"nickname":" Cafe\u0301 ","avatarId":"avatar-1","dailyGoal":15,"publicOptIn":true}""";
        using var first = await Send(client, "/v1/me", json);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var profile = await Body(first);
        Assert.Equal("Café", profile["nickname"]!.GetValue<string>());
        Assert.Equal("avatar-1", profile["avatarId"]!.GetValue<string>());
        Assert.True(profile["publicOptIn"]!.GetValue<bool>());
        Assert.Equal(15, profile["dailyGoal"]!.GetValue<int>());
        Assert.Equal(1, profile["revision"]!.GetValue<int>());
        using var replay = await Send(client, "/v1/me", json);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(profile, await Body(replay)));
        Assert.Equal(2, factory.Driver.Commits);
        using var clear = await Send(client, "/v1/me", """{"expectedRevision":1,"avatarId":null}""", "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.OK, clear.StatusCode);
        var cleared = await Body(clear);
        Assert.Null(cleared["avatarId"]);
        Assert.Equal(2, cleared["revision"]!.GetValue<int>());
    }

    [Theory]
    [InlineData("{\"expectedRevision\":0,\"avatarId\":\"bad/id\"}", "avatarId")]
    [InlineData("{\"expectedRevision\":0,\"publicOptIn\":null}", "publicOptIn")]
    [InlineData("{\"expectedRevision\":0,\"dailyGoal\":11}", "dailyGoal")]
    [InlineData("{\"expectedRevision\":0,\"dailyGoal\":\"10\"}", "dailyGoal")]
    [InlineData("{\"expectedRevision\":0,\"nickname\":null}", "nickname")]
    [InlineData("{\"expectedRevision\":0,\"learningZone\":false}", "learningZone")]
    public async Task ProfileUpdate_InvalidWireFieldsFailBeforeStorage(string json, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me", json);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(field, (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Fact]
    public async Task Initialize_EmptyBodyCreatesOwnerRowsAndNewKeyNeverDuplicatesInitialCredit()
    {
        await using var factory = new Factory();
        factory.Driver.Rows.Clear();
        using var client = Client(factory);
        using var first = await Send(client, "/v1/me/initialize", "");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var profile = await Body(first);
        Assert.Equal("usera63f23edd9cc", profile["nickname"]!.GetValue<string>());
        Assert.Equal("alice", profile["userId"]!.GetValue<string>());
        Assert.Equal(8, factory.Driver.LastWrites.Count);
        Assert.Equal(20, factory.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        using var replay = await Send(client, "/v1/me/initialize", "{}");
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(profile, await Body(replay)));
        Assert.Equal(1, factory.Driver.Commits);
        using var another = await Send(client, "/v1/me/initialize", "{}", "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.OK, another.StatusCode);
        Assert.True(JsonNode.DeepEquals(profile, await Body(another)));
        Assert.Equal(20, factory.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        Assert.Single(factory.Driver.LastWrites);
        Assert.Equal("p_receipts", factory.Driver.LastWrites[0].Table);
    }

    [Theory]
    [InlineData("null", "body")]
    [InlineData("{\"userId\":\"bob\"}", "userId")]
    public async Task Initialize_RejectsExplicitNullAndUnexpectedBody(string json, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/initialize", json);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(field, (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    [Fact]
    public async Task Preferences_ReplaysCanonicalBodyAndRejectsChangedBodyWithoutAnotherWrite()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var first = await Send(client, "/v1/me/preferences", """{"expectedRevision":0,"soundEffects":false}""");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var created = await Body(first);
        Assert.False(created["soundEffects"]!.GetValue<bool>());
        Assert.Equal(0, created["revision"]!.GetValue<int>());
        Assert.Equal("2026-11-03T10:00:00.000Z", created["asOf"]!.GetValue<string>());
        Assert.Equal(1, factory.Driver.Commits);
        Assert.Equal(2, factory.Driver.LastWrites.Count);
        Assert.Equal(new[] { "p_preferences", "p_receipts" }, factory.Driver.LastWrites.Select(w => w.Table).Order(StringComparer.Ordinal));
        Assert.Equal("cabf24df7baf5ec5758bbfa5b4e2d7dab16af4101707c2f6185bcffb678caf7d", factory.Driver.LastWrites.Single(w => w.Table == "p_receipts").Data!.Text("bodyHash"));
        using var replay = await Send(client, "/v1/me/preferences", """{ "soundEffects":false, "expectedRevision":0.0 }""");
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.True(JsonNode.DeepEquals(created, await Body(replay)));
        Assert.Equal(1, factory.Driver.Commits);
        using var changed = await Send(client, "/v1/me/preferences", """{"expectedRevision":0,"soundEffects":true}""");
        Assert.Equal(HttpStatusCode.Conflict, changed.StatusCode);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await Body(changed))["error"]!["code"]!.GetValue<string>());
        Assert.Equal(1, factory.Driver.Commits);
        using var stale = await Send(client, "/v1/me/preferences", """{"expectedRevision":3}""", "22222222-2222-4222-8222-222222222222");
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
        Assert.Equal(0, (await Body(stale))["error"]!["details"]!["currentRevision"]!.GetValue<int>());
        Assert.Equal(1, factory.Driver.Commits);
    }

    [Fact]
    public async Task Preferences_DuplicateJsonKeysUseLastValueAsNodeDoes()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/preferences", """{"expectedRevision":1,"expectedRevision":0,"soundEffects":true,"soundEffects":false}""");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.False((await Body(response))["soundEffects"]!.GetValue<bool>());
        Assert.Equal(1, factory.Driver.Commits);
    }

    [Theory]
    [InlineData(1, HttpStatusCode.OK)]
    [InlineData(4, HttpStatusCode.Conflict)]
    public async Task ConflictingCommitRetriesAtomicallyAndNeverLeavesPartialRows(int conflicts, HttpStatusCode expected)
    {
        await using var factory = new Factory();
        factory.Driver.Conflicts = conflicts;
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/preferences", """{"expectedRevision":0,"haptics":false}""");
        Assert.Equal(expected, response.StatusCode);
        if (expected == HttpStatusCode.OK)
        {
            Assert.Equal(2, factory.Driver.Attempts);
            Assert.Equal(1, factory.Driver.Commits);
            Assert.Equal(3, factory.Driver.Rows.Count);
            Assert.Equal(0, factory.Driver.Rows[("p_preferences", CanonicalWire.RowId("p_preferences", "alice"))].Number("revision"));
        }
        else
        {
            Assert.Equal("REVISION_CONFLICT", (await Body(response))["error"]!["code"]!.GetValue<string>());
            Assert.Equal(4, factory.Driver.Attempts);
            Assert.Equal(0, factory.Driver.Commits);
            Assert.Single(factory.Driver.Rows);
        }
    }

    [Fact]
    public async Task Feedback_ReplayUsesCurrentRequestIdAndOperationScopedReceipt()
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        const string text = """{"topic":"bug","message":"Lỗi tiếng Việt 😀","appVersion":"1.0","platform":"ANDROID"}""";
        using var first = await Send(client, "/v1/feedback", text, requestId: "first-request");
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var body = await Body(first);
        Assert.Equal("completed", body["status"]!.GetValue<string>());
        Assert.Equal(Key, body["operationId"]!.GetValue<string>());
        Assert.Equal("first-request", body["requestId"]!.GetValue<string>());
        Assert.Equal("alice", factory.Driver.Rows[("p_feedback", CanonicalWire.RowId("p_feedback", "alice", Key))].Text("userId"));
        using var replay = await Send(client, "/v1/feedback", text, requestId: "replay-request");
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var replayBody = await Body(replay);
        Assert.Equal("replayed", replayBody["status"]!.GetValue<string>());
        Assert.Equal("replay-request", replayBody["requestId"]!.GetValue<string>());
        Assert.Equal(1, factory.Driver.Commits);
        // The same key may be used for a different operation without leaking/replaying feedback.
        using var preferences = await Send(client, "/v1/me/preferences", """{"expectedRevision":0}""");
        Assert.Equal(HttpStatusCode.OK, preferences.StatusCode);
        Assert.Equal(2, factory.Driver.Commits);
    }

    [Theory]
    [InlineData("{}", "expectedRevision")]
    [InlineData("null", "body")]
    [InlineData("[]", "body")]
    [InlineData("{\"expectedRevision\":0,\"userId\":\"bob\"}", "userId")]
    [InlineData("{\"expectedRevision\":-1}", "expectedRevision")]
    [InlineData("{\"expectedRevision\":2147483648}", "expectedRevision")]
    [InlineData("{\"expectedRevision\":0.5}", "expectedRevision")]
    [InlineData("{\"expectedRevision\":\"0\"}", "expectedRevision")]
    [InlineData("{\"expectedRevision\":0,\"soundEffects\":null}", "soundEffects")]
    [InlineData("{\"expectedRevision\":0,\"soundEffects\":1}", "soundEffects")]
    [InlineData("{\"expectedRevision\":0,\"reminderMinute\":1440}", "reminderMinute")]
    [InlineData("{\"expectedRevision\":0,\"notificationsOff\":null}", "notificationsOff")]
    [InlineData("{\"expectedRevision\":0,\"notificationsOff\":[\"bad key\"]}", "notificationsOff")]
    public async Task Preferences_ValidationRejectsBeforeStorage(string json, string field)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/preferences", json);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await Body(response);
        Assert.Equal("VALIDATION_ERROR", body["error"]!["code"]!.GetValue<string>());
        Assert.Equal(field, body["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
        Assert.Equal(0, factory.Driver.Commits);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("bad-key")]
    [InlineData("11111111-1111-0111-8111-111111111111")]
    public async Task MissingOrInvalidIdempotencyKeyDoesNotReadStorage(string? key)
    {
        await using var factory = new Factory();
        using var client = Client(factory);
        using var response = await Send(client, "/v1/me/preferences", """{"expectedRevision":0}""", key);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Idempotency-Key", (await Body(response))["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, factory.Driver.Reads);
    }

    private static HttpClient Client(Factory factory)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice-jwt");
        client.DefaultRequestHeaders.Add("X-Appwrite-User-ID", "bob");
        return client;
    }
    private static Task<HttpResponseMessage> Send(HttpClient client, string path, string json, string? key = Key, string requestId = "mutation-request")
    {
        var request = new HttpRequestMessage(path is "/v1/me" or "/v1/me/preferences" ? HttpMethod.Patch : HttpMethod.Post, path) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
        if (key is not null) request.Headers.Add("Idempotency-Key", key);
        request.Headers.Add("X-Request-ID", requestId);
        return client.SendAsync(request);
    }
    private static async Task<JsonNode> Body(HttpResponseMessage response) => JsonNode.Parse(await response.Content.ReadAsStringAsync())!;

}
