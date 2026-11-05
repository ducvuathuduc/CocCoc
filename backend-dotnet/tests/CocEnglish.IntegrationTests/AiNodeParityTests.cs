using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    [Fact]
    public async Task SignedEventConsumerSequence_MatchesNodeResponsesAndRows()
    {
        var scenario = JsonNode.Parse(ReadAiParityResource("Scenarios"))!["eventParity"]!.AsObject();
        var baseline = JsonNode.Parse(ReadAiParityResource("Node"))!;
        var expectedResults = Assert.IsType<JsonArray>(baseline["eventParityResults"]);
        var steps = scenario["steps"]!.AsArray();
        Assert.Equal(steps.Count, expectedResults.Count);

        var driver = new Driver();
        var seed = scenario["seed"]!.AsObject();
        for (var index = 0; index < seed["aliceConversations"]!.GetValue<int>(); index++)
            driver.Seed("a_conversations", $"alice-conversation-{index:D3}", new JsonObject { ["userId"] = "alice" });
        for (var index = 0; index < seed["bobConversations"]!.GetValue<int>(); index++)
            driver.Seed("a_conversations", $"bob-conversation-{index:D3}", new JsonObject { ["userId"] = "bob" });
        for (var index = 0; index < seed["alicePracticeOutbox"]!.GetValue<int>(); index++)
            driver.Seed("a_outbox", $"alice-practice-{index:D3}", new JsonObject
            {
                ["aggregateId"] = "alice", ["type"] = "ai.practice.completed.v1"
            });

        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        var inspect = scenario["inspect"]!.AsArray().Select(node => node!.GetValue<string>()).ToArray();
        for (var index = 0; index < steps.Count; index++)
        {
            var step = steps[index]!.AsObject();
            var eventId = step["eventId"]!.GetValue<string>();
            var sender = step["sender"]?.GetValue<string>() ?? "progress";
            var payload = step["payload"]!.DeepClone().AsObject();
            var envelope = new JsonObject
            {
                ["eventId"] = eventId,
                ["type"] = step["type"]!.GetValue<string>(),
                ["schemaVersion"] = 1,
                ["producer"] = sender,
                ["aggregateId"] = payload["userId"]!.DeepClone(),
                ["occurredAt"] = scenario["now"]!.DeepClone(),
                ["requestId"] = eventId,
                ["payload"] = payload
            };
            using var response = await SendNodeParityEvent(client, envelope, sender);
            var expected = expectedResults[index]!.AsObject();
            Assert.Equal(expected["status"]!.GetValue<int>(), (int)response.StatusCode);

            var actualBody = JsonNode.Parse(await response.Content.ReadAsStringAsync())!.AsObject();
            if (actualBody.ContainsKey("requestId")) actualBody["requestId"] = "<request-id>";
            if (actualBody["error"] is JsonObject error && error.ContainsKey("requestId")) error["requestId"] = "<request-id>";
            Assert.True(JsonNode.DeepEquals(expected["body"], actualBody),
                $"AI event {index} ({step["type"]}) response differs from Node: expected {expected["body"]?.ToJsonString()}, actual {actualBody.ToJsonString()}");

            var actualTables = new JsonObject();
            foreach (var table in inspect)
            {
                var rows = driver.Rows
                    .Where(pair => pair.Key.Table == table)
                    .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                    .Select(pair => (JsonNode?)ProjectRow(pair.Key.Id, pair.Value))
                    .ToArray();
                actualTables[table] = new JsonArray(rows);
            }
            Assert.True(JsonNode.DeepEquals(expected["tables"], actualTables),
                $"AI event {index} ({step["type"]}) rows differ from Node: expected {expected["tables"]?.ToJsonString()}, actual {actualTables.ToJsonString()}");
        }
    }

    [Fact]
    public async Task DisabledSpeechRouteSequence_MatchesNodeResponses()
    {
        var scenarioText = ReadAiParityResource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(ReadAiParityResource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var driver = new Driver();
        if (scenario["seedEntitlements"] is JsonArray entitlements)
            foreach (var entitlement in entitlements)
                driver.SeedEntitlement(entitlement!["user"]!.GetValue<string>(), entitlement["plan"]!.GetValue<string>());
        if (scenario["seedVoiceSession"] is JsonObject voiceSession)
            driver.SeedVoiceSession(voiceSession);
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        var steps = scenario["steps"]!.AsArray();
        var expectedResults = baseline["results"]!.AsArray();
        Assert.Equal(steps.Count, expectedResults.Count);
        var variables = new Dictionary<string, string>(StringComparer.Ordinal);

        for (var index = 0; index < steps.Count; index++)
        {
            var step = steps[index]!.AsObject();
            var expected = expectedResults[index]!;
            if (step["inspect"] is JsonArray tables)
            {
                var user = step["user"]!.GetValue<string>();
                var actualTables = new JsonObject();
                foreach (var tableNode in tables)
                {
                    var table = tableNode!.GetValue<string>();
                    var rows = driver.Rows
                        .Where(pair => pair.Key.Table == table &&
                            (pair.Value.Text("userId") == user || pair.Value.Text("aggregateId") == user))
                        .OrderBy(pair => pair.Key.Id, StringComparer.Ordinal)
                        .Select(pair => (JsonNode?)ProjectRow(pair.Key.Id, pair.Value))
                        .ToArray();
                    actualTables[table] = new JsonArray(rows);
                }
                Assert.True(JsonNode.DeepEquals(expected["tables"], actualTables),
                    $"AI persisted rows at step {index} differ from Node: expected {expected["tables"]?.ToJsonString()}, actual {actualTables.ToJsonString()}");
                continue;
            }
            var path = step["path"]!.GetValue<string>();
            foreach (var (name, value) in variables)
                path = path.Replace("{" + name + "}", value, StringComparison.Ordinal);
            if (step["queryString"] is JsonValue query && query.GetValue<string>() is { Length: > 0 } queryString)
                path += "?" + queryString;

            using var request = new HttpRequestMessage(
                new HttpMethod(step["method"]!.GetValue<string>()), path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", step["user"]!.GetValue<string>());
            request.Headers.TryAddWithoutValidation("x-request-id", scenario["requestId"]!.GetValue<string>());
            if (step["key"] is JsonValue key)
                request.Headers.TryAddWithoutValidation("Idempotency-Key", key.GetValue<string>());
            if (step["body"] is JsonObject body)
                request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");

            using var response = await client.SendAsync(request);
            var actual = JsonNode.Parse(await response.Content.ReadAsStringAsync());
            Assert.Equal(expected["status"]!.GetValue<int>(), (int)response.StatusCode);
            Assert.True(JsonNode.DeepEquals(expected["body"], actual),
                $"AI route {index} ({step["method"]} {step["path"]}) differs from Node: expected {expected["body"]?.ToJsonString()}, actual {actual?.ToJsonString()}");
            if (step["capture"] is JsonValue capture)
            {
                var name = capture.GetValue<string>();
                variables[name] = actual![name]!.GetValue<string>();
            }
        }

        var tutorReceipts = driver.Rows.Count(row => row.Key.Table == "a_receipts" && row.Value["operation"]?.GetValue<string>() == "tutorFeedback");
        Assert.Equal(5, tutorReceipts); // One fallback and four authored turns; replay adds none.
    }

    private static JsonObject ProjectRow(string id, JsonObject source)
    {
        var row = source.DeepClone().AsObject();
        foreach (var key in new[] { "feedbackJson", "payloadJson", "reservationIdsJson", "responseJson" })
            if (row[key] is JsonValue value && value.TryGetValue<string>(out var json)) row[key] = JsonNode.Parse(json);
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private static async Task<HttpResponseMessage> SendNodeParityEvent(HttpClient client, JsonObject envelope, string sender)
    {
        var keyId = sender == "progress" ? "p-to-ai" : "l-to-ai";
        var secret = Enumerable.Repeat(sender == "progress" ? (byte)4 : (byte)5, 32).ToArray();
        var key = new ServiceKey(keyId, sender, secret);
        var body = envelope.ToJsonString();
        var signature = ServiceHmac.Sign(key, "POST", "/internal/events", "", new HashSet<string>(), body, Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/events")
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        return await client.SendAsync(request);
    }

    private sealed partial class Driver
    {
        public void SeedVoiceSession(JsonObject seed)
        {
            var user = seed["user"]!.GetValue<string>();
            var sessionId = seed["sessionId"]!.GetValue<string>();
            var createdAt = seed["createdAt"]!.GetValue<string>();
            var expiresAt = seed["expiresAt"]!.GetValue<string>();
            var epoch = seed["epoch"]!.GetValue<int>();
            var consumedSeconds = seed["consumedSeconds"]!.GetValue<int>();
            Seed("a_voice_sessions", CanonicalWire.RowId("voice", sessionId), new JsonObject
            {
                ["userId"] = user,
                ["sessionId"] = sessionId,
                ["providerAlias"] = "scripted",
                ["mode"] = "TURN",
                ["status"] = "ACTIVE",
                ["createdAt"] = createdAt,
                ["expiresAt"] = expiresAt,
                ["lastHeartbeatAt"] = createdAt,
                ["epoch"] = epoch,
                ["consumedSeconds"] = consumedSeconds,
                ["configVersion"] = "scripted-v1",
                ["revision"] = 0,
                ["updatedAt"] = createdAt
            });
            Seed("a_active_slots", CanonicalWire.RowId("slot", user), new JsonObject
            {
                ["userId"] = user,
                ["sessionId"] = sessionId,
                ["expiresAt"] = expiresAt,
                ["epoch"] = epoch,
                ["revision"] = 0,
                ["createdAt"] = createdAt,
                ["updatedAt"] = createdAt
            });
        }
    }

    private static string ReadAiParityResource(string name)
    {
        using var stream = typeof(AiConversationTests).Assembly.GetManifestResourceStream($"CocEnglish.AI.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }
}
