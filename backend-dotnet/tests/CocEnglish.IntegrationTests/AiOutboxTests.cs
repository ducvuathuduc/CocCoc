using System.Text.Json.Nodes;
using System.Net;
using System.Text;
using System.Globalization;
using CocEnglish.AI;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed partial class AiConversationTests
{
    [Fact]
    public async Task HttpRelay_MatchesNodeSignedRequestAndOutcome()
    {
        var scenario = JsonNode.Parse(ReadAiParityResource("Scenarios"))!;
        var scenarioText = ReadAiParityResource("Scenarios");
        var baseline = JsonNode.Parse(ReadAiParityResource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var relaySpec = scenario["httpRelay"]!.AsObject();
        var relayClock = new MutableClock(DateTimeOffset.Parse(relaySpec["now"]!.GetValue<string>(), CultureInfo.InvariantCulture));
        var key = new ServiceKey(
            relaySpec["keyId"]!.GetValue<string>(),
            "ai",
            Convert.FromHexString(relaySpec["secretHex"]!.GetValue<string>()));
        var handler = new CapturingHandler();
        using var client = new HttpClient(handler);
        var relay = new HttpAiRelay(client, new Uri(relaySpec["baseUrl"]!.GetValue<string>()), key, relayClock);
        var outboxSpec = scenario["outbox"]!.AsObject();
        var envelope = new JsonObject { ["eventId"] = outboxSpec["eventId"]!.GetValue<string>() };
        foreach (var (name, value) in outboxSpec["event"]!.AsObject()) envelope[name] = value!.DeepClone();

        var expected = baseline["httpRelay"]!["request"]!;
        var expectedOutcomes = baseline["httpRelay"]!["outcomes"]!.AsArray();
        foreach (var expectedOutcome in expectedOutcomes)
        {
            handler.ResponseStatus = expectedOutcome!["status"]!.GetValue<int>();
            handler.ResponseBody = expectedOutcome["body"]!.ToJsonString();
            var outcome = await relay.DeliverAsync(envelope, CancellationToken.None);
            Assert.Equal(expectedOutcome["outcome"]!.GetValue<string>(), outcome.ToString().ToLowerInvariant());
        }
        Assert.Equal(expected["method"]!.GetValue<string>(), handler.Method!.Method);
        Assert.Equal(expected["url"]!.GetValue<string>(), handler.Url);
        Assert.Equal(expected["body"]!.GetValue<string>(), handler.Body);
        Assert.Equal(expected["keyId"]!.GetValue<string>(), handler.KeyId);
        Assert.Equal(expected["timestamp"]!.GetValue<string>(), handler.Timestamp);
        Assert.Equal(expected["signature"]!.GetValue<string>(), handler.Signature);
        Assert.Equal(expected["contentType"]!.GetValue<string>(), handler.ContentType);
    }

    [Fact]
    public async Task Dispatcher_RetryThenAckMatchesNodeReportsAndPersistedRows()
    {
        var scenarioText = ReadAiParityResource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(ReadAiParityResource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var spec = scenario["outbox"]!.AsObject();
        var now = DateTimeOffset.Parse(spec["now"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        var eventId = spec["eventId"]!.GetValue<string>();
        var envelope = spec["event"]!.DeepClone().AsObject();
        envelope["eventId"] = eventId;
        var driver = new Driver();
        driver.Seed("a_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = envelope["type"]!.DeepClone(),
            ["schemaVersion"] = envelope["schemaVersion"]!.DeepClone(),
            ["aggregateId"] = envelope["aggregateId"]!.DeepClone(),
            ["occurredAt"] = envelope["occurredAt"]!.DeepClone(),
            ["payloadJson"] = envelope.ToJsonString(),
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
        var clock = new MutableClock(now);
        var dispatcher = new AiOutboxDispatcher(new OwnerStore(driver, clock), clock);
        var expectedResults = baseline["outboxResults"]!.AsArray();

        foreach (var expected in expectedResults)
        {
            if (expected!["index"]!.GetValue<int>() > 0) clock.Advance(TimeSpan.FromSeconds(1));
            var outcome = expected["index"]!.GetValue<int>() == 0 ? AiRelayOutcome.Retry : AiRelayOutcome.Ack;
            var report = await dispatcher.RunAsync((_, _) => Task.FromResult(outcome),
                new(Owner: spec["owner"]!.GetValue<string>(), Random: () => 0), CancellationToken.None);
            var actualReport = new JsonObject
            {
                ["leased"] = report.Leased,
                ["acked"] = report.Acked,
                ["retried"] = report.Retried,
                ["dead"] = report.Dead
            };
            Assert.True(JsonNode.DeepEquals(expected["report"], actualReport),
                $"AI outbox report at step {expected["index"]} differs from Node: expected {expected["report"]}, actual {actualReport}");

            var actualRow = ProjectRow(eventId, driver.Rows[("a_outbox", eventId)]);
            Assert.True(JsonNode.DeepEquals(expected["row"], actualRow),
                $"AI outbox row at step {expected["index"]} differs from Node: expected {expected["row"]}, actual {actualRow}");
        }
    }

    [Fact]
    public async Task ImmediateRelay_RetryMatchesNodeDeliveryAndPersistedRow()
    {
        var scenarioText = ReadAiParityResource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(ReadAiParityResource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());

        var spec = scenario["immediateRelay"]!.AsObject();
        var now = DateTimeOffset.Parse(spec["now"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        var eventId = spec["eventId"]!.GetValue<string>();
        var sourceEvent = scenario["outbox"]!["event"]!.AsObject();
        var envelope = new JsonObject { ["eventId"] = eventId };
        foreach (var (name, value) in sourceEvent) envelope[name] = value!.DeepClone();
        envelope["requestId"] = eventId;

        var driver = new Driver();
        driver.Seed("a_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = envelope["type"]!.DeepClone(),
            ["schemaVersion"] = envelope["schemaVersion"]!.DeepClone(),
            ["aggregateId"] = envelope["aggregateId"]!.DeepClone(),
            ["occurredAt"] = envelope["occurredAt"]!.DeepClone(),
            ["payloadJson"] = envelope.ToJsonString(),
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
        var clock = new MutableClock(now);
        var relay = new TestAiRelay { Configured = true, Outcome = AiRelayOutcome.Retry };
        await AiImmediateRelay.DispatchAsync(
            new OwnerStore(driver, clock), relay, clock, [eventId], CancellationToken.None,
            random: () => 0);

        var expected = baseline["immediateRelay"]!;
        Assert.Equal(expected["deliveredEventIds"]!.AsArray().Select(item => item!.GetValue<string>()),
            relay.Events.Select(item => item["eventId"]!.GetValue<string>()));
        var actualRow = ProjectRow(eventId, driver.Rows[("a_outbox", eventId)]);
        Assert.True(JsonNode.DeepEquals(expected["row"], actualRow),
            $"AI immediate relay row differs from Node: expected {expected["row"]}, actual {actualRow}");
    }

    [Fact]
    public async Task Dispatcher_RetriesWithBackoffThenAcknowledgesTheSameOutboxEvent()
    {
        var driver = new Driver();
        var clock = new MutableClock(Now);
        var eventId = "77777777-7777-4777-8777-777777777777";
        var envelope = new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = "ai.practice.completed.v1",
            ["schemaVersion"] = 1,
            ["producer"] = "ai",
            ["aggregateId"] = "alice",
            ["occurredAt"] = OwnerSchema.Iso(Now),
            ["requestId"] = eventId,
            ["payload"] = new JsonObject { ["userId"] = "alice" }
        };
        driver.Seed("a_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId,
            ["type"] = "ai.practice.completed.v1",
            ["schemaVersion"] = 1,
            ["aggregateId"] = "alice",
            ["occurredAt"] = OwnerSchema.Iso(Now),
            ["payloadJson"] = envelope.ToJsonString(),
            ["attempt"] = 0,
            ["nextAttemptAt"] = OwnerSchema.Iso(Now.AddSeconds(-1)),
            ["leaseOwner"] = null,
            ["leaseUntil"] = null,
            ["status"] = "PENDING",
            ["ackAt"] = null
        });
        var dispatcher = new AiOutboxDispatcher(new OwnerStore(driver, clock), clock);
        var delivered = new List<string>();

        var first = await dispatcher.RunAsync((eventEnvelope, _) =>
        {
            delivered.Add(eventEnvelope["eventId"]!.GetValue<string>());
            return Task.FromResult(AiRelayOutcome.Retry);
        }, new(Owner: "test-worker", Random: () => 0), CancellationToken.None);

        Assert.Equal(new AiDispatchReport(1, 0, 1, 0), first);
        var pending = driver.Rows[("a_outbox", eventId)];
        Assert.Equal("PENDING", pending.Text("status"));
        Assert.Equal(1, pending.Number("attempt"));
        Assert.Null(pending["leaseOwner"]);
        Assert.Equal(OwnerSchema.Iso(Now.AddSeconds(1)), pending.Text("nextAttemptAt"));

        clock.Advance(TimeSpan.FromSeconds(1));
        var second = await dispatcher.RunAsync((eventEnvelope, _) =>
        {
            delivered.Add(eventEnvelope["eventId"]!.GetValue<string>());
            return Task.FromResult(AiRelayOutcome.Ack);
        }, new(Owner: "test-worker"), CancellationToken.None);

        Assert.Equal(new AiDispatchReport(1, 1, 0, 0), second);
        Assert.Equal([eventId, eventId], delivered);
        Assert.Equal("ACK", driver.Rows[("a_outbox", eventId)].Text("status"));
        Assert.Equal(1, driver.Rows[("a_outbox", eventId)].Number("attempt"));
    }

    [Fact]
    public async Task Dispatcher_DeadLettersAtTheTenthFailedDelivery()
    {
        var driver = new Driver();
        var eventId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
        var envelope = new JsonObject { ["eventId"] = eventId, ["type"] = "ai.practice.completed.v1" };
        driver.Seed("a_outbox", eventId, new JsonObject
        {
            ["eventId"] = eventId, ["type"] = "ai.practice.completed.v1", ["schemaVersion"] = 1,
            ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(Now), ["payloadJson"] = envelope.ToJsonString(),
            ["attempt"] = 9, ["nextAttemptAt"] = OwnerSchema.Iso(Now.AddSeconds(-1)), ["leaseOwner"] = null,
            ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null
        });

        var report = await new AiOutboxDispatcher(new OwnerStore(driver, new MutableClock(Now)), new MutableClock(Now))
            .RunAsync((_, _) => Task.FromResult(AiRelayOutcome.Retry), new(Owner: "test-worker", Random: () => 0), CancellationToken.None);

        Assert.Equal(new AiDispatchReport(1, 0, 1, 0), report);
        Assert.Equal("DEAD", driver.Rows[("a_outbox", eventId)].Text("status"));
        Assert.Equal(10, driver.Rows[("a_outbox", eventId)].Number("attempt"));
        Assert.Null(driver.Rows[("a_outbox", eventId)]["leaseUntil"]);
    }

    [Fact]
    public async Task HttpRelay_SignsTheCanonicalEventForTheAiSender()
    {
        var key = new ServiceKey("ai-test", "ai", Convert.FromHexString(new string('8', 64)));
        var handler = new CapturingHandler();
        using var client = new HttpClient(handler);
        var clock = new MutableClock(Now);
        var relay = new HttpAiRelay(client, new Uri("https://progress.test"), key, clock);
        var envelope = new JsonObject
        {
            ["eventId"] = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            ["type"] = "ai.practice.completed.v1",
            ["producer"] = "ai",
            ["payload"] = new JsonObject { ["sentence"] = "Tiếng Việt" }
        };
        var canonicalBody = CanonicalWire.Stringify(envelope);

        Assert.True(relay.Configured);
        Assert.Equal(AiRelayOutcome.Ack, await relay.DeliverAsync(envelope, CancellationToken.None));
        var signature = ServiceHmac.Sign(key, "POST", "/internal/events", "", new HashSet<string>(), canonicalBody, Now.ToUnixTimeSeconds());
        Assert.Equal(HttpMethod.Post, handler.Method);
        Assert.Equal("https://progress.test/internal/events", handler.Url);
        Assert.Equal(canonicalBody, handler.Body);
        Assert.Equal(signature.KeyId, handler.KeyId);
        Assert.Equal(signature.Timestamp, handler.Timestamp);
        Assert.Equal(signature.Signature, handler.Signature);
        Assert.Equal("application/json", handler.ContentType);
    }

    [Theory]
    [InlineData(200, null, null, AiRelayOutcome.Ack)]
    [InlineData(409, "IDEMPOTENCY_CONFLICT", null, AiRelayOutcome.Dead)]
    [InlineData(400, "VALIDATION_ERROR", "type", AiRelayOutcome.Retry)]
    [InlineData(400, "VALIDATION_ERROR", "event", AiRelayOutcome.Dead)]
    [InlineData(503, null, null, AiRelayOutcome.Retry)]
    public void RelayOutcome_UsesProgressEventCompatibilityRules(int status, string? code, string? field, AiRelayOutcome expected)
    {
        JsonObject? body = code is null ? null : new JsonObject
        {
            ["error"] = new JsonObject
            {
                ["code"] = code,
                ["details"] = field is null ? null : new JsonObject { ["field"] = field }
            }
        };

        Assert.Equal(expected, HttpAiRelay.OutcomeForStatus(status, body));
    }

    [Theory]
    [InlineData("15000", 15000)]
    [InlineData("999", 60000)]
    [InlineData("3600001", 60000)]
    [InlineData("invalid", 60000)]
    public void WorkerInterval_IsBoundedAndDefaultsToOneMinute(string value, int expectedMilliseconds) =>
        Assert.Equal(TimeSpan.FromMilliseconds(expectedMilliseconds), AiWorkerService.ParseInterval(value));

    [Fact]
    public async Task ScheduledWorker_FailsClosedUntilHostIsAdmittedAndRelayIsConfigured()
    {
        var driver = new Driver();
        var clock = new MutableClock(Now);
        var relay = new TestAiRelay { Configured = true };
        var runner = new AiOutboxJobRunner(new OwnerStore(driver, clock), relay, clock);
        var unadmitted = new RuntimeSettings("ai", "test", null, null, null, false,
            new Dictionary<string, CocEnglish.Shared.Security.ServiceKey>(), new HashSet<string>(StringComparer.Ordinal));
        var worker = new AiScheduledTick(runner, unadmitted, relay);

        var rejected = await Assert.ThrowsAsync<CocEnglish.Shared.Errors.ServiceException>(() => worker.RunAsync(CancellationToken.None));
        Assert.Equal("SERVICE_NOT_CONFIGURED", rejected.Code);
        Assert.Empty(relay.Events);

        var admitted = unadmitted with { Admitted = true };
        relay.Configured = false;
        worker = new AiScheduledTick(runner, admitted, relay);
        var noRelay = await Assert.ThrowsAsync<CocEnglish.Shared.Errors.ServiceException>(() => worker.RunAsync(CancellationToken.None));
        Assert.Equal("SERVICE_NOT_CONFIGURED", noRelay.Code);
        Assert.Empty(relay.Events);
    }

    [Fact]
    public async Task EnabledWorker_SerializesTicksAndCancelsCurrentTickOnShutdown()
    {
        var tick = new BlockingAiTick();
        using var host = BuildAiWorkerHost(tick, enabled: true);
        await host.StartAsync();
        await tick.Started.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await Task.Delay(50);
        Assert.Equal(1, tick.Calls);

        await host.StopAsync(TimeSpan.FromSeconds(5));
        Assert.True(tick.CancellationObserved);
        Assert.Equal(1, tick.Calls);
    }

    [Fact]
    public async Task DisabledWorker_DoesNotRunScheduledTicks()
    {
        var tick = new BlockingAiTick();
        using var host = BuildAiWorkerHost(tick, enabled: false);
        await host.StartAsync();
        await Task.Delay(50);
        Assert.Equal(0, tick.Calls);
        await host.StopAsync(TimeSpan.FromSeconds(5));
    }

    private static IHost BuildAiWorkerHost(BlockingAiTick tick, bool enabled) => new HostBuilder()
        .ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["COC_AI_WORKER_ENABLED"] = enabled.ToString(), ["COC_WORKER_INTERVAL_MS"] = "1000"
        }))
        .ConfigureServices(services =>
        {
            services.AddSingleton<TimeProvider>(TimeProvider.System);
            services.AddSingleton(tick);
            services.AddScoped<IAiScheduledTick>(sp => sp.GetRequiredService<BlockingAiTick>());
            services.AddHostedService<AiWorkerService>();
        }).Build();

    private sealed class BlockingAiTick : IAiScheduledTick
    {
        private int _calls;
        public int Calls => Volatile.Read(ref _calls);
        public bool CancellationObserved { get; private set; }
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<AiJobRunReport> RunAsync(CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref _calls);
            Started.TrySetResult();
            try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                CancellationObserved = true;
                throw;
            }
            return new("11111111-1111-4111-8111-111111111111", "", "", new(0, 0, 0, 0));
        }
    }

    private sealed class MutableClock(DateTimeOffset now) : TimeProvider
    {
        private DateTimeOffset _now = now;
        public override DateTimeOffset GetUtcNow() => _now;
        public void Advance(TimeSpan amount) => _now += amount;
    }

    private sealed class CapturingHandler : HttpMessageHandler
    {
        public int ResponseStatus { get; set; } = (int)HttpStatusCode.OK;
        public string ResponseBody { get; set; } = "{}";
        public HttpMethod? Method { get; private set; }
        public string? Url { get; private set; }
        public string? Body { get; private set; }
        public string? KeyId { get; private set; }
        public string? Timestamp { get; private set; }
        public string? Signature { get; private set; }
        public string? ContentType { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Method = request.Method;
            Url = request.RequestUri!.AbsoluteUri;
            Body = await request.Content!.ReadAsStringAsync(cancellationToken);
            KeyId = request.Headers.GetValues("X-Service-Key-Id").Single();
            Timestamp = request.Headers.GetValues("X-Service-Timestamp").Single();
            Signature = request.Headers.GetValues("X-Service-Signature").Single();
            ContentType = request.Content.Headers.ContentType?.MediaType;
            return new HttpResponseMessage((HttpStatusCode)ResponseStatus) { Content = new StringContent(ResponseBody, Encoding.UTF8, "application/json") };
        }
    }

}
