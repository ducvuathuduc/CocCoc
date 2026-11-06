using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    private const string EventKeyId = "progress-event-test";
    private static readonly byte[] EventSecret = Convert.FromHexString(new string('9', 64));

    [Fact]
    public async Task EntitlementEvent_IsSignedIdempotentAndKeepsTheNewestRevision()
    {
        var driver = new Driver();
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        var first = Event("entitlement.changed.v1", "11111111-1111-4111-8111-111111111111", "alice", new JsonObject
        {
            ["userId"] = "alice", ["plan"] = "MAX", ["status"] = "ACTIVE", ["expiresAt"] = null, ["entitlementRevision"] = 5
        });

        using var accepted = await Send(client, first);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        Assert.Equal("accepted", (await accepted.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        var projectionId = CanonicalWire.RowId("entitlement", "alice");
        var projection = (await driver.ReadAsync("a_usage", projectionId, CancellationToken.None))!.Data;
        Assert.Equal("ENTITLED", projection.Text("utcDay"));
        var entitlement = JsonNode.Parse(projection.Text("reservationIdsJson")!)!.AsObject();
        Assert.Equal("MAX", entitlement.Text("plan"));
        Assert.Equal(5, entitlement.Number("entitlementRevision"));

        var commits = driver.Commits;
        using var replay = await Send(client, first);
        Assert.Equal("replayed", (await replay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Equal(commits, driver.Commits);

        var older = Event("entitlement.changed.v1", "22222222-2222-4222-8222-222222222222", "alice", new JsonObject
        {
            ["userId"] = "alice", ["plan"] = "FREE", ["status"] = "ACTIVE", ["expiresAt"] = null, ["entitlementRevision"] = 4
        });
        using var olderAccepted = await Send(client, older);
        Assert.Equal(HttpStatusCode.OK, olderAccepted.StatusCode);
        var unchanged = JsonNode.Parse((await driver.ReadAsync("a_usage", projectionId, CancellationToken.None))!.Data.Text("reservationIdsJson")!)!.AsObject();
        Assert.Equal("MAX", unchanged.Text("plan"));
        Assert.Equal(5, unchanged.Number("entitlementRevision"));

        first["payload"]!["plan"] = "SUPER";
        using var conflict = await Send(client, first);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await conflict.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task AccountDeletedEvent_PurgesOnlyTheOwnerAcrossBatchesAndStagesOneAcknowledgement()
    {
        var driver = new Driver();
        for (var index = 0; index < 82; index++)
            driver.Seed("a_conversations", "alice-conversation-" + index, new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_conversations", "bob-conversation", new JsonObject { ["userId"] = "bob" });
        driver.Seed("a_voice_sessions", "alice-voice", new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_active_slots", "alice-slot", new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_jobs", "alice-job", new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_usage", "alice-usage", new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_receipts", "alice-receipt", new JsonObject { ["userId"] = "alice" });
        driver.Seed("a_outbox", "alice-practice-event", new JsonObject { ["aggregateId"] = "alice", ["type"] = "ai.practice.completed.v1" });
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        var eventId = "33333333-3333-4333-8333-333333333333";
        var requestId = "44444444-4444-4444-8444-444444444444";
        var deletion = Event("account.deleted.v1", eventId, "alice", new JsonObject { ["userId"] = "alice", ["requestId"] = requestId });

        using var accepted = await Send(client, deletion);
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        Assert.Equal("accepted", (await accepted.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        foreach (var table in new[] { "a_conversations", "a_voice_sessions", "a_active_slots", "a_jobs", "a_usage", "a_receipts" })
            Assert.DoesNotContain(driver.Rows, row => row.Key.Table == table && row.Value.Text("userId") == "alice");
        Assert.DoesNotContain(driver.Rows, row => row.Key.Table == "a_outbox" && row.Value.Text("aggregateId") == "alice" && row.Value.Text("type") == "ai.practice.completed.v1");
        Assert.Contains(driver.Rows, row => row.Key == ("a_conversations", "bob-conversation"));

        var acknowledgement = Assert.Single(driver.Rows, row => row.Key.Table == "a_outbox" && row.Value.Text("type") == "account.purged.v1");
        var envelope = JsonNode.Parse(acknowledgement.Value.Text("payloadJson")!)!.AsObject();
        Assert.Equal("ai", envelope.Text("producer"));
        Assert.Equal("alice", envelope["payload"]!.AsObject().Text("userId"));
        Assert.Equal(requestId, envelope["payload"]!.AsObject().Text("requestId"));
        Assert.Equal("ai", envelope["payload"]!.AsObject().Text("owner"));
        Assert.NotNull(await driver.ReadAsync("a_inbox", CanonicalWire.RowId("inbox", eventId), CancellationToken.None));

        var commits = driver.Commits;
        using var replay = await Send(client, deletion);
        Assert.Equal("replayed", (await replay.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
        Assert.Equal(commits, driver.Commits);
        Assert.Single(driver.Rows, row => row.Key.Table == "a_outbox" && row.Value.Text("type") == "account.purged.v1");
    }

    [Fact]
    public async Task AccountDeletedEvent_RelaysPurgeAcknowledgementOnlyAfterDurableCommit()
    {
        var driver = new Driver();
        driver.Seed("a_conversations", "alice-conversation", new JsonObject { ["userId"] = "alice" });
        var relay = new TestAiRelay { Configured = true };
        using var app = CreateApp(driver, relay);
        using var client = app.CreateClient();
        var eventId = "88888888-8888-4888-8888-888888888888";
        var requestId = "99999999-9999-4999-8999-999999999999";
        var deletion = Event("account.deleted.v1", eventId, "alice", new JsonObject { ["userId"] = "alice", ["requestId"] = requestId });

        using var accepted = await Send(client, deletion);

        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        var acknowledgement = Assert.Single(relay.Events);
        Assert.Equal("account.purged.v1", acknowledgement.Text("type"));
        var outbox = Assert.Single(driver.Rows, row => row.Key.Table == "a_outbox").Value;
        Assert.Equal("ACK", outbox.Text("status"));
        Assert.NotNull(await driver.ReadAsync("a_inbox", CanonicalWire.RowId("inbox", eventId), CancellationToken.None));
    }

    private static JsonObject Event(string type, string eventId, string userId, JsonObject payload) => new()
    {
        ["eventId"] = eventId,
        ["type"] = type,
        ["schemaVersion"] = 1,
        ["producer"] = "progress",
        ["aggregateId"] = userId,
        ["occurredAt"] = OwnerSchema.Iso(Now),
        ["requestId"] = "trace",
        ["payload"] = payload
    };

    private static async Task<HttpResponseMessage> Send(HttpClient client, JsonObject envelope)
    {
        var body = envelope.ToJsonString();
        var key = new ServiceKey(EventKeyId, "progress", EventSecret);
        var signature = ServiceHmac.Sign(key, "POST", "/internal/events", "", new HashSet<string>(), body, Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/events") { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        return await client.SendAsync(request);
    }
}
