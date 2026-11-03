using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ProgressMutationApiTests
{
    private const string Key = "11111111-1111-4111-8111-111111111111";

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
        var request = new HttpRequestMessage(path is "/v1/feedback" or "/v1/me/initialize" or "/v1/me/deletion" ? HttpMethod.Post : HttpMethod.Patch, path) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
        if (key is not null) request.Headers.Add("Idempotency-Key", key);
        request.Headers.Add("X-Request-ID", requestId);
        return client.SendAsync(request);
    }
    private static async Task<JsonNode> Body(HttpResponseMessage response) => JsonNode.Parse(await response.Content.ReadAsStringAsync())!;

    private sealed class Factory : WebApplicationFactory<Progress.Program>
    {
        public Driver Driver { get; } = new();
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "isolated-test", ["COC_PROGRESS_APPWRITE_KEY"] = "not-real",
                ["COC_PROGRESS_PERSISTENCE"] = "appwrite", ["COC_PROGRESS_ADMITTED"] = "reviewed-cloud-gate"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IIdentityVerifier>(); services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>(); services.AddSingleton<TimeProvider>(new Clock());
                services.RemoveAll<IRowDriver>(); services.AddSingleton<IRowDriver>(Driver);
            });
        }
    }
    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T10:00:00Z"); }
    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken ct) => jwt switch
        {
            "alice-jwt" => Task.FromResult(new VerifiedSubject("alice")),
            "bob-jwt" => Task.FromResult(new VerifiedSubject("bob")),
            _ => throw new ServiceException("AUTH_EXPIRED")
        };
    }
    private sealed class Driver : IRowDriver
    {
        public string Owner => "progress";
        public bool Configured => true;
        public int Reads { get; private set; }
        public int Commits { get; private set; }
        public int Attempts { get; private set; }
        public int Conflicts { get; set; }
        public IReadOnlyList<RowWrite> LastWrites { get; private set; } = [];
        public Dictionary<(string Table, string Id), JsonObject> Rows { get; } = new()
        { [("p_profiles", CanonicalWire.RowId("p_profiles", "alice"))] = new() { ["userId"] = "alice", ["learningZone"] = "UTC" } };
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct)
        {
            Reads++;
            return Task.FromResult(Rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "v1") : null);
        }
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => Task.FromResult<IReadOnlyList<RowDocument>>(Rows.Where(p => p.Key.Table == table && (query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString()))).Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), "v1")).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        {
            Attempts++;
            if (Conflicts-- > 0) throw new TransactionConflictException();
            Commits++; LastWrites = writes;
            foreach (var write in writes) Rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            return Task.CompletedTask;
        }
    }
}
