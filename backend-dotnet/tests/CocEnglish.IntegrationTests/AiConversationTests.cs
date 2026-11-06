using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.AI;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-11-03T12:00:00.000Z");

    [Fact]
    public async Task Tutor_FallbackUsesDailyQuotaAndReceiptReplayDoesNotCountTwice()
    {
        var driver = new Driver();
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        var body = new
        {
            requestId = "11111111-1111-4111-8111-111111111111",
            learnerText = "",
            level = "A1",
            locale = "en-US",
            feedbackLocale = "vi-VN"
        };

        using var first = await client.PostAsJsonAsync("/v1/tutor", body);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        var result = (await first.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("Write a short sentence in English and I will help you.", result["tutorText"]!.GetValue<string>());
        Assert.Equal("fallback", result["source"]!.GetValue<string>());
        Assert.False(result["assessedPronunciation"]!.GetValue<bool>());
        var usageId = CanonicalWire.RowId("usage", "alice", "2026-11-03");
        Assert.Equal(1, driver.Rows[("a_usage", usageId)].Number("textRequests"));
        var commits = driver.Commits;

        using var replay = await client.PostAsJsonAsync("/v1/tutor", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(commits, driver.Commits);
        Assert.Equal(1, driver.Rows[("a_usage", usageId)].Number("textRequests"));
    }

    [Fact]
    public async Task Conversation_StartIsEntitlementGatedAndTutorAdvancesOnlyOwnedAuthoredScenario()
    {
        var driver = new Driver();
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "22222222-2222-4222-8222-222222222222");
        var startBody = new { kind = "ROLEPLAY", courseId = "course1", scenarioId = "rp_cafe_order", voiceSessionId = (string?)null };

        using var denied = await client.PostAsJsonAsync("/v1/conversations", startBody);
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        Assert.Equal("ENTITLEMENT_REQUIRED", (await denied.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, driver.Commits);

        driver.SeedEntitlement("alice", "MAX");
        using var started = await client.PostAsJsonAsync("/v1/conversations", startBody);
        Assert.Equal(HttpStatusCode.OK, started.StatusCode);
        var conversation = (await started.Content.ReadFromJsonAsync<JsonObject>())!;
        var conversationId = conversation["conversationId"]!.GetValue<string>();
        Assert.Equal("ACTIVE", conversation["status"]!.GetValue<string>());

        using var turn = await client.PostAsJsonAsync("/v1/tutor", new
        {
            requestId = "33333333-3333-4333-8333-333333333333",
            scenarioId = "rp_cafe_order",
            learnerText = "I would like a coffee, please.",
            level = "A1",
            locale = "en-US",
            feedbackLocale = "vi-VN"
        });
        Assert.Equal(HttpStatusCode.OK, turn.StatusCode);
        var turnResult = (await turn.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("authored", turnResult["source"]!.GetValue<string>());
        Assert.Equal("Sure. Small or large?", turnResult["tutorText"]!.GetValue<string>());
        Assert.Null(turnResult["correction"]);
        Assert.False(turnResult["assessedPronunciation"]!.GetValue<bool>());

        var mine = await client.GetFromJsonAsync<JsonObject>("/v1/conversations?kind=ROLEPLAY&scenarioId=rp_cafe_order&limit=1");
        Assert.Single(mine!["items"]!.AsArray());
        Assert.Equal(conversationId, mine["items"]![0]!["conversationId"]!.GetValue<string>());
        Assert.Null(mine["nextCursor"]);

        client.DefaultRequestHeaders.Authorization = new("Bearer", "bob");
        var foreign = await client.GetFromJsonAsync<JsonObject>("/v1/conversations?kind=ROLEPLAY");
        Assert.Empty(foreign!["items"]!.AsArray());
    }

    [Fact]
    public async Task Conversation_CompletionScoresServerTurnsAndStagesOneOutboxEvent()
    {
        var driver = new Driver();
        var relay = new TestAiRelay { Configured = true };
        driver.SeedEntitlement("alice", "MAX");
        using var app = CreateApp(driver, relay);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "44444444-4444-4444-8444-444444444444");
        using var started = await client.PostAsJsonAsync("/v1/conversations", new { kind = "ROLEPLAY", courseId = "course1", scenarioId = "rp_cafe_order", voiceSessionId = (string?)null });
        Assert.Equal(HttpStatusCode.OK, started.StatusCode);
        var conversationId = (await started.Content.ReadFromJsonAsync<JsonObject>())!["conversationId"]!.GetValue<string>();

        var answers = new[]
        {
            "I would like a coffee, please.",
            "A small one, please.",
            "Milk, no sugar, thank you.",
            "To go, please. Here you are."
        };
        for (var index = 0; index < answers.Length; index++)
        {
            using var turn = await client.PostAsJsonAsync("/v1/tutor", new
            {
                requestId = $"55555555-5555-4555-8555-{index + 1:000000000000}",
                scenarioId = "rp_cafe_order",
                learnerText = answers[index],
                level = "A1",
                locale = "en-US",
                feedbackLocale = "vi-VN"
            });
            Assert.Equal(HttpStatusCode.OK, turn.StatusCode);
        }

        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", "66666666-6666-4666-8666-666666666666");
        var body = new { endReason = "COMPLETED" };
        using var completed = await client.PostAsJsonAsync($"/v1/conversations/{conversationId}/complete", body);
        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var result = (await completed.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("COMPLETED", result["status"]!.GetValue<string>());
        Assert.Equal(4, result["turnCount"]!.GetValue<int>());
        Assert.Equal(3, result["stars"]!.GetValue<int>());
        Assert.Equal(20, result["xpAwarded"]!.GetValue<int>());
        var eventRow = Assert.Single(driver.Rows, row => row.Key.Item1 == "a_outbox").Value;
        Assert.Equal("ai.practice.completed.v1", eventRow["type"]!.GetValue<string>());
        Assert.Equal("ACK", eventRow["status"]!.GetValue<string>());
        Assert.Single(relay.Events);
        Assert.Equal("ai.practice.completed.v1", relay.Events[0].Text("type"));

        var commits = driver.Commits;
        using var replay = await client.PostAsJsonAsync($"/v1/conversations/{conversationId}/complete", body);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(result.ToJsonString(), (await replay.Content.ReadFromJsonAsync<JsonObject>())!.ToJsonString());
        Assert.Equal(commits, driver.Commits);
        Assert.Single(driver.Rows, row => row.Key.Item1 == "a_outbox");
    }

    private static WebApplicationFactory<CocEnglish.AI.Program> CreateApp(Driver driver, TestAiRelay? relay = null) =>
        new WebApplicationFactory<CocEnglish.AI.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_AI_APPWRITE_KEY"] = "test-key",
                ["COC_AI_PERSISTENCE"] = "appwrite",
                ["COC_AI_ADMITTED"] = "reviewed-cloud-gate",
                ["COC_SERVICE_KEYS"] = JsonSerializer.Serialize(new[]
                {
                    new { keyId = "progress-event-test", sender = "progress", secretHex = new string('9', 64) },
                    new { keyId = "p-to-ai", sender = "progress", secretHex = Convert.ToHexString(Enumerable.Repeat((byte)4, 32).ToArray()) },
                    new { keyId = "l-to-ai", sender = "learning", secretHex = Convert.ToHexString(Enumerable.Repeat((byte)5, 32).ToArray()) }
                })
            }));
            builder.ConfigureServices(services =>
            {
                if (relay is not null)
                {
                    services.RemoveAll<IAiRelayTransport>();
                    services.AddSingleton<IAiRelayTransport>(relay);
                }
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(new FixedClock(Now));
            });
        });

    private sealed class TestAiRelay : IAiRelayTransport
    {
        public bool Configured { get; set; }
        public AiRelayOutcome Outcome { get; set; } = AiRelayOutcome.Ack;
        public List<JsonObject> Events { get; } = [];
        public Task<AiRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            Events.Add(envelope.DeepClone().AsObject());
            return Task.FromResult(Outcome);
        }
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now; }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => Task.FromResult(new VerifiedSubject(jwt));
    }

    private sealed partial class Driver : IRowDriver
    {
        private readonly Dictionary<(string Table, string Id), JsonObject> _rows = [];
        public string Owner => "ai";
        public bool Configured => true;
        public int Commits { get; private set; }
        public IReadOnlyDictionary<(string Table, string Id), JsonObject> Rows => _rows;

        public void SeedEntitlement(string userId, string plan)
        {
            var projection = new JsonObject { ["plan"] = plan, ["status"] = "ACTIVE", ["expiresAt"] = null, ["entitlementRevision"] = 1 };
            Seed("a_usage", CanonicalWire.RowId("entitlement", userId), new JsonObject
            {
                ["userId"] = userId,
                ["utcDay"] = "ENTITLED",
                ["liveReservedSeconds"] = 0,
                ["liveUsedSeconds"] = 0,
                ["liveGrants"] = 0,
                ["textRequests"] = 0,
                ["recordedSpeechSeconds"] = 0,
                ["recordedReservedSeconds"] = 0,
                ["reservationIdsJson"] = projection.ToJsonString()
            });
        }

        public void Seed(string table, string id, JsonObject row) => _rows[(table, id)] = row;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken) =>
            Task.FromResult(_rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), null) : null);

        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
        {
            IEnumerable<RowDocument> rows = _rows.Where(pair => pair.Key.Table == table).Select(pair => new RowDocument(pair.Key.Id, pair.Value.DeepClone().AsObject(), null));
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
            {
                var expected = JsonSerializer.SerializeToNode(value);
                rows = rows.Where(row => JsonNode.DeepEquals(row.Data[key], expected));
            }
            foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>())
                rows = rows.Where(row => row.Data[key] is not null && StringComparer.Ordinal.Compare(row.Data[key]!.GetValue<string>(), Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture)) >= 0);
            var ordered = rows.ToArray();
            Array.Sort(ordered, (left, right) =>
            {
                foreach (var order in query.OrderBy ?? [])
                {
                    var compare = StringComparer.Ordinal.Compare(left.Data[order.Column]?.ToString(), right.Data[order.Column]?.ToString());
                    if (compare != 0) return order.Descending ? -compare : compare;
                }
                return StringComparer.Ordinal.Compare(left.Id, right.Id);
            });
            rows = ordered;
            return Task.FromResult<IReadOnlyList<RowDocument>>(rows.Skip(query.Offset).Take(query.Limit).ToArray());
        }

        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken) =>
            Task.FromResult((long)_rows.Count(pair => pair.Key.Table == table && where.All(filter => pair.Value[filter.Key]?.ToString() == Convert.ToString(filter.Value, System.Globalization.CultureInfo.InvariantCulture))));

        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken)
        {
            Commits++;
            foreach (var write in writes)
            {
                if (write.Action == "delete") _rows.Remove((write.Table, write.Id));
                else _rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            }
            return Task.CompletedTask;
        }
    }
}
