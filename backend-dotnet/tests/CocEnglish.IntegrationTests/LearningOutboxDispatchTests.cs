using System.Net;
using System.Net.Http.Json;
using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningOutboxDispatchTests
{
    [Fact]
    public async Task Dispatcher_RetryThenAckMatchesNodeReportsAndPersistedRows()
    {
        var scenarioText = Resource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());
        var spec = scenario["outbox"]!.AsObject();
        var now = DateTimeOffset.Parse(spec["now"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        var eventId = spec["eventId"]!.GetValue<string>();
        var envelope = new JsonObject
        {
            ["eventId"] = eventId, ["type"] = "lesson.completed.v1", ["schemaVersion"] = 1,
            ["producer"] = "learning", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now),
            ["requestId"] = eventId,
            ["payload"] = new JsonObject { ["userId"] = "alice", ["courseId"] = "vi_en", ["sessionId"] = "session-parity", ["originalCorrect"] = 8 }
        };
        var driver = new Driver("learning");
        driver.Seed("l_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId, ["type"] = "lesson.completed.v1", ["schemaVersion"] = 1,
            ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now),
            ["payloadJson"] = CanonicalWire.Stringify(envelope), ["attempt"] = 0,
            ["nextAttemptAt"] = OwnerSchema.Iso(now), ["leaseOwner"] = null, ["leaseUntil"] = null,
            ["status"] = "PENDING", ["ackAt"] = null, ["revision"] = 0,
            ["createdAt"] = OwnerSchema.Iso(now), ["updatedAt"] = OwnerSchema.Iso(now)
        });
        var clock = new Clock(now);
        var dispatcher = new LearningOutboxDispatcher(new OwnerStore(driver, clock), clock);
        var expected = baseline["outboxResults"]!.AsArray();
        var outcomes = new[] { LearningRelayOutcome.Retry, LearningRelayOutcome.Ack };

        for (var index = 0; index < outcomes.Length; index++)
        {
            if (index > 0) clock.Now = now.AddSeconds(1);
            var report = await dispatcher.RunAsync((payload, _) =>
            {
                Assert.Equal(eventId, payload.Text("eventId"));
                return Task.FromResult(outcomes[index]);
            }, new(Owner: spec["owner"]!.GetValue<string>(), Random: () => 0), CancellationToken.None);
            var reportNode = new JsonObject
            {
                ["leased"] = report.Leased, ["acked"] = report.Acked,
                ["retried"] = report.Retried, ["dead"] = report.Dead
            };
            var saved = (await driver.ReadAsync("l_outbox", eventId, CancellationToken.None))!.Data;
            var actualRow = ProjectRow("l_outbox", eventId, saved);
            Assert.True(JsonNode.DeepEquals(expected[index]!["report"], reportNode),
                $"dispatch report {index}: expected {expected[index]!["report"]}, actual {reportNode}");
            Assert.True(JsonNode.DeepEquals(expected[index]!["row"], actualRow),
                $"dispatch row {index}: expected {expected[index]!["row"]}, actual {actualRow}");
        }
    }

    [Fact]
    public async Task ImmediateRelay_RetryMatchesNodeDeliveryAndPersistedRow()
    {
        var scenarioText = Resource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var spec = scenario["immediateRelay"]!.AsObject();
        var now = DateTimeOffset.Parse(spec["now"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        var eventId = spec["eventId"]!.GetValue<string>();
        var sourceEvent = new JsonObject
        {
            ["eventId"] = scenario["outbox"]!["eventId"]!.DeepClone(),
            ["type"] = "lesson.completed.v1",
            ["schemaVersion"] = 1,
            ["producer"] = "learning",
            ["aggregateId"] = "alice",
            ["occurredAt"] = OwnerSchema.Iso(now),
            ["requestId"] = scenario["outbox"]!["eventId"]!.DeepClone(),
            ["payload"] = new JsonObject
            {
                ["userId"] = "alice",
                ["courseId"] = "vi_en",
                ["sessionId"] = "session-parity",
                ["originalCorrect"] = 8
            }
        };
        sourceEvent["eventId"] = eventId;
        sourceEvent["requestId"] = eventId;
        var driver = new Driver("learning");
        driver.Seed("l_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = sourceEvent["type"]!.DeepClone(),
            ["schemaVersion"] = sourceEvent["schemaVersion"]!.DeepClone(),
            ["aggregateId"] = sourceEvent["aggregateId"]!.DeepClone(),
            ["occurredAt"] = sourceEvent["occurredAt"]!.DeepClone(),
            ["payloadJson"] = CanonicalWire.Stringify(sourceEvent),
            ["attempt"] = 0,
            ["nextAttemptAt"] = OwnerSchema.Iso(now),
            ["leaseOwner"] = null,
            ["leaseUntil"] = null,
            ["status"] = "PENDING",
            ["ackAt"] = null,
            ["revision"] = 0,
            ["createdAt"] = OwnerSchema.Iso(now),
            ["updatedAt"] = OwnerSchema.Iso(now)
        });
        var clock = new Clock(now);
        var relay = new Relay();
        relay.Outcomes.Enqueue(LearningRelayOutcome.Retry);
        await LearningImmediateRelay.DispatchAsync(new OwnerStore(driver, clock), relay, clock,
            [eventId], "relay-node-parity", CancellationToken.None, random: () => 0);

        var expected = baseline["immediateRelay"]!;
        Assert.Equal(expected["deliveredEventIds"]!.AsArray().Select(item => item!.GetValue<string>()),
            relay.Delivered.Select(item => item["eventId"]!.GetValue<string>()));
        var actualRow = ProjectRow("l_outbox", eventId, (await driver.ReadAsync("l_outbox", eventId, CancellationToken.None))!.Data);
        Assert.True(JsonNode.DeepEquals(expected["row"], actualRow),
            $"Learning immediate relay row differs from Node: expected {expected["row"]}, actual {actualRow}");
    }

    [Fact]
    public async Task Dispatcher_RetriesWithBackoffThenAcknowledgesWhenDue()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z"); var clock = new Clock(now); var driver = new Driver("learning");
        var eventId = "11111111-1111-4111-8111-111111111111";
        var envelope = new JsonObject { ["eventId"] = eventId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
            ["producer"] = "learning", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["requestId"] = eventId,
            ["payload"] = new JsonObject { ["userId"] = "alice", ["requestId"] = "22222222-2222-4222-8222-222222222222", ["owner"] = "learning" } };
        driver.Seed("l_outbox", eventId, new() { ["eventId"] = eventId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
            ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["payloadJson"] = CanonicalWire.Stringify(envelope), ["attempt"] = 0,
            ["nextAttemptAt"] = OwnerSchema.Iso(now), ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null });
        var relay = new Relay(); relay.Outcomes.Enqueue(LearningRelayOutcome.Retry); relay.Outcomes.Enqueue(LearningRelayOutcome.Ack);
        var dispatcher = new LearningOutboxDispatcher(new OwnerStore(driver, clock), clock);

        var failed = await dispatcher.RunAsync(relay.DeliverAsync, new(Owner: "test", Random: () => 0), CancellationToken.None);
        Assert.Equal(new LearningDispatchReport(1, 0, 1, 0), failed);
        var delayed = (await driver.ReadAsync("l_outbox", eventId, CancellationToken.None))!.Data;
        Assert.Equal(1L, delayed["attempt"]!.GetValue<long>());
        Assert.Equal(OwnerSchema.Iso(now.AddSeconds(1)), delayed["nextAttemptAt"]!.GetValue<string>());

        var early = await dispatcher.RunAsync(relay.DeliverAsync, new(Owner: "test"), CancellationToken.None);
        Assert.Equal(new LearningDispatchReport(0, 0, 0, 0), early);
        Assert.Single(relay.Delivered);
        clock.Now = now.AddSeconds(1);
        var retried = await dispatcher.RunAsync(relay.DeliverAsync, new(Owner: "test"), CancellationToken.None);
        Assert.Equal(new LearningDispatchReport(1, 1, 0, 0), retried);
        Assert.Equal("ACK", (await driver.ReadAsync("l_outbox", eventId, CancellationToken.None))!.Data["status"]!.GetValue<string>());
    }

    [Fact]
    public async Task ScheduledDispatch_DeliversPendingEventAndAcknowledgesIt()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var driver = new Driver("learning");
        var eventId = "11111111-1111-4111-8111-111111111111";
        var envelope = new JsonObject { ["eventId"] = eventId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
            ["producer"] = "learning", ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["requestId"] = eventId,
            ["payload"] = new JsonObject { ["userId"] = "alice", ["requestId"] = "22222222-2222-4222-8222-222222222222", ["owner"] = "learning" } };
        var payloadJson = CanonicalWire.Stringify(envelope);
        driver.Seed("l_outbox", eventId, new() { ["eventId"] = eventId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
            ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(now), ["payloadJson"] = payloadJson, ["attempt"] = 0,
            ["nextAttemptAt"] = OwnerSchema.Iso(now), ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null });
        var relay = new Relay();
        using var app = CreateApp(driver, relay, now);
        using var client = app.CreateClient();
        using var response = await Send(client, "scheduler-key", "scheduler", new JsonObject {
            ["tickId"] = "33333333-3333-4333-8333-333333333333", ["scheduledAt"] = OwnerSchema.Iso(now) });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var report = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("LEARNING_OUTBOX_DISPATCH", report["job"]!.GetValue<string>());
        Assert.Equal(1, report["processed"]!.GetValue<int>());
        Assert.Equal(1, report["succeeded"]!.GetValue<int>());
        Assert.Equal(eventId, relay.Delivered.Single()["eventId"]!.GetValue<string>());
        Assert.Equal("ACK", (await driver.ReadAsync("l_outbox", eventId, CancellationToken.None))!.Data["status"]!.GetValue<string>());
    }

    [Fact]
    public async Task ScheduledDispatch_RejectsWrongSenderAndFailsClosedWithoutTransport()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        using var app = CreateApp(new Driver("learning"), new Relay { IsConfigured = false }, now);
        using var client = app.CreateClient();
        var tick = new JsonObject { ["tickId"] = "33333333-3333-4333-8333-333333333333", ["scheduledAt"] = OwnerSchema.Iso(now) };

        using var denied = await Send(client, "progress-key", "progress", tick);
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        using var unconfigured = await Send(client, "scheduler-key", "scheduler", tick);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, unconfigured.StatusCode);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await unconfigured.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }

    private static WebApplicationFactory<Learning.Program> CreateApp(Driver driver, Relay relay, DateTimeOffset now) =>
        new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"scheduler-key\",\"sender\":\"scheduler\",\"secretHex\":\"" + new string('9', 64) + "\"},{\"keyId\":\"progress-key\",\"sender\":\"progress\",\"secretHex\":\"" + new string('8', 64) + "\"}]" }));
            builder.ConfigureServices(s => {
                s.RemoveAll<IRowDriver>(); s.AddSingleton<IRowDriver>(driver);
                s.RemoveAll<TimeProvider>(); s.AddSingleton<TimeProvider>(new Clock(now));
                s.RemoveAll<ILearningRelayTransport>(); s.AddSingleton<ILearningRelayTransport>(relay);
            });
        });

    private static string Resource(string name)
    {
        using var stream = typeof(LearningOutboxDispatchTests).Assembly.GetManifestResourceStream($"CocEnglish.Learning.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }

    private static JsonObject ProjectRow(string table, string id, JsonObject data)
    {
        var row = data.DeepClone().AsObject();
        foreach (var key in row.Select(pair => pair.Key).ToArray())
            if (key.EndsWith("Json", StringComparison.Ordinal) && row.Text(key) is { } json)
                row[key] = JsonNode.Parse(json);
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private static async Task<HttpResponseMessage> Send(HttpClient client, string keyId, string sender, JsonObject body)
    {
        var key = new ServiceKey(keyId, sender, Convert.FromHexString(new string(sender == "scheduler" ? '9' : '8', 64)));
        var raw = body.ToJsonString();
        var signature = ServiceHmac.Sign(key, "POST", "/internal/jobs/learning-outbox-dispatch", "", new HashSet<string>(), raw,
            DateTimeOffset.Parse(body["scheduledAt"]!.GetValue<string>()).ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, "/internal/jobs/learning-outbox-dispatch") { Content = new StringContent(raw, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
        return await client.SendAsync(request);
    }

    private sealed class Clock(DateTimeOffset now) : TimeProvider { public DateTimeOffset Now { get; set; } = now; public override DateTimeOffset GetUtcNow() => Now; }

    private sealed class Relay : ILearningRelayTransport
    {
        public bool IsConfigured { get; set; } = true;
        public bool Configured => IsConfigured;
        public List<JsonObject> Delivered { get; } = [];
        public Queue<LearningRelayOutcome> Outcomes { get; } = new();
        public Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct)
        { Delivered.Add(envelope.DeepClone().AsObject()); return Task.FromResult(Outcomes.TryDequeue(out var outcome) ? outcome : LearningRelayOutcome.Ack); }
    }

    private sealed class Driver(string owner) : IRowDriver
    {
        private readonly Dictionary<(string Table, string Id), JsonObject> _rows = [];
        public string Owner => owner;
        public bool Configured => true;
        public void Seed(string table, string id, JsonObject row) => _rows[(table, id)] = row;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) =>
            Task.FromResult(_rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), null) : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct)
        {
            IEnumerable<KeyValuePair<(string Table, string Id), JsonObject>> rows = _rows.Where(p => p.Key.Table == table);
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
                rows = rows.Where(p => p.Value[key]?.ToString() == value?.ToString());
            foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>())
                rows = rows.Where(p => string.CompareOrdinal(p.Value[key]?.GetValue<string>(), value?.ToString()) < 0);
            foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>())
                rows = rows.Where(p => string.CompareOrdinal(p.Value[key]?.GetValue<string>(), value?.ToString()) >= 0);
            return Task.FromResult<IReadOnlyList<RowDocument>>(rows.Take(query.Limit).Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), null)).ToArray());
        }
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        {
            foreach (var write in writes)
                if (write.Action == "delete") _rows.Remove((write.Table, write.Id));
                else _rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            return Task.CompletedTask;
        }
    }
}
