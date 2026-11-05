using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class RelayTests
{
    [Theory]
    [InlineData(-1, 1)]
    [InlineData(0, 0)]
    [InlineData(1, 0)]
    public async Task LeaseExpiry_RequiresStrictlyEarlierThanServerTime(int delta, int expected)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var id = Seed(fixture, "energy.granted.v1"); var row = fixture.Driver.Rows[("p_outbox", id)]; row["status"] = "LEASED"; row["leaseOwner"] = "old"; row["leaseUntil"] = OwnerSchema.Iso(fixture.Now.AddMilliseconds(delta));
        var report = await new ProgressOutboxRelay(scope.ServiceProvider.GetRequiredService<OwnerStore>(), fixture.Services.GetRequiredService<TimeProvider>()).RunAsync((_, _, _) => Task.FromResult(RelayOutcome.Ack), new(Owner: "new"), CancellationToken.None);
        Assert.Equal(expected, report.Leased); Assert.Equal(expected, report.Acked);
        Assert.Equal(expected == 1 ? "ACK" : "LEASED", fixture.Driver.Rows[("p_outbox", id)].Text("status"));
        if (expected == 0) Assert.Equal("old", fixture.Driver.Rows[("p_outbox", id)].Text("leaseOwner"));
    }

    [Fact]
    public async Task LostLease_DoesNotOverwriteNewOwnersState()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var id = Seed(fixture, "energy.granted.v1");
        await new ProgressOutboxRelay(scope.ServiceProvider.GetRequiredService<OwnerStore>(), fixture.Services.GetRequiredService<TimeProvider>()).RunAsync((_, _, _) => {
            fixture.Driver.Rows[("p_outbox", id)]["leaseOwner"] = "other-worker";
            return Task.FromResult(RelayOutcome.Ack);
        }, new(Owner: "first-worker"), CancellationToken.None);
        Assert.Equal("LEASED", fixture.Driver.Rows[("p_outbox", id)].Text("status"));
        Assert.Equal("other-worker", fixture.Driver.Rows[("p_outbox", id)].Text("leaseOwner"));
        Assert.Null(fixture.Driver.Rows[("p_outbox", id)]["ackAt"]);
    }

    [Fact]
    public async Task Deadline_LeavesUnattemptedRowsLeasedAndRecoverableAfterExpiry()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        Seed(fixture, "energy.granted.v1"); Seed(fixture, "energy.granted.v1");
        var relay = new ProgressOutboxRelay(scope.ServiceProvider.GetRequiredService<OwnerStore>(), fixture.Services.GetRequiredService<TimeProvider>());
        var calls = 0;
        var first = await relay.RunAsync((_, _, _) => { calls++; fixture.Now = fixture.Now.AddSeconds(21); return Task.FromResult(RelayOutcome.Ack); }, new(Owner: "first", Deadline: TimeSpan.FromSeconds(20)), CancellationToken.None);
        Assert.Equal(new RelayReport(2, 1, 0, 0), first); Assert.Equal(1, calls);
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_outbox" && r.Value.Text("status") == "LEASED");
        fixture.Now = fixture.Now.AddSeconds(10);
        var recovered = await relay.RunAsync((_, _, _) => { calls++; return Task.FromResult(RelayOutcome.Ack); }, new(Owner: "restarted"), CancellationToken.None);
        Assert.Equal(new RelayReport(1, 1, 0, 0), recovered); Assert.Equal(2, calls);
        Assert.All(fixture.Driver.Rows.Where(r => r.Key.Table == "p_outbox"), r => Assert.Equal("ACK", r.Value.Text("status")));
    }

    [Fact]
    public async Task Relay_ClampsBatchToTwenty()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var ids = Enumerable.Range(0, 21).Select(_ => Seed(fixture, "energy.granted.v1")).ToArray();
        var calls = 0;
        var relay = new ProgressOutboxRelay(store, fixture.Services.GetRequiredService<TimeProvider>());
        var capped = await relay.RunAsync((_, _, _) => { calls++; return Task.FromResult(RelayOutcome.Ack); }, new(Owner: "capped", Limit: 500), CancellationToken.None);
        Assert.Equal(new RelayReport(20, 20, 0, 0), capped);
        Assert.Equal(20, calls);
        Assert.Equal(1, fixture.Driver.Rows.Count(row => row.Key.Table == "p_outbox" && row.Value.Text("status") == "PENDING"));
    }

    [Fact]
    public async Task RowIds_RestrictSelectionToRequestedPendingEvent()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var ids = Enumerable.Range(0, 3).Select(_ => Seed(fixture, "energy.granted.v1")).ToArray();
        var requested = ids[1];
        var eventId = fixture.Driver.Rows[("p_outbox", requested)].Text("eventId");
        var relay = new ProgressOutboxRelay(store, fixture.Services.GetRequiredService<TimeProvider>());
        var selected = await relay.RunAsync((_, envelope, _) =>
        {
            Assert.Equal(eventId, envelope.Text("eventId"));
            return Task.FromResult(RelayOutcome.Ack);
        }, new(Owner: "selected", Limit: 1, RowIds: [requested]), CancellationToken.None);
        Assert.Equal(new RelayReport(1, 1, 0, 0), selected);
        Assert.Equal("ACK", fixture.Driver.Rows[("p_outbox", requested)].Text("status"));
        Assert.Equal(2, fixture.Driver.Rows.Count(row => row.Key.Table == "p_outbox" && row.Value.Text("status") == "PENDING"));
    }

    [Fact]
    public async Task CancellationDuringDeliveryLeavesLeaseRecoverable()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var ids = new[] { Seed(fixture, "energy.granted.v1"), Seed(fixture, "energy.granted.v1") };
        var relay = new ProgressOutboxRelay(store, fixture.Services.GetRequiredService<TimeProvider>());
        using var cancellation = new CancellationTokenSource();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => relay.RunAsync((_, _, _) =>
        {
            cancellation.Cancel();
            throw new OperationCanceledException(cancellation.Token);
        }, new(Owner: "cancelled"), cancellation.Token));

        Assert.All(ids, id =>
        {
            var row = fixture.Driver.Rows[("p_outbox", id)];
            Assert.Equal("LEASED", row.Text("status"));
            Assert.Equal("cancelled", row.Text("leaseOwner"));
            Assert.Equal(0, row.Number("attempt"));
        });
        fixture.Now = fixture.Now.AddSeconds(31);
        var recovered = await relay.RunAsync((_, _, _) => Task.FromResult(RelayOutcome.Ack), new(Owner: "recovered"), CancellationToken.None);
        Assert.Equal(new RelayReport(2, 2, 0, 0), recovered);
    }

    [Theory]
    [InlineData("account.deleted.v1", 2)]
    [InlineData("entitlement.changed.v1", 2)]
    [InlineData("energy.granted.v1", 1)]
    public async Task Ack_RequiresAllTargetsAndRebuildsStableEnvelope(string type, int targets)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var id = Seed(fixture, type); var calls = new List<string>();
        var relay = new ProgressOutboxRelay(store, fixture.Services.GetRequiredService<TimeProvider>());
        async Task<RelayOutcome> Deliver(string target, JsonObject envelope, CancellationToken ct)
        {
            calls.Add(target); Assert.Equal("progress", envelope.Text("producer")); Assert.Equal(type, envelope.Text("type"));
            Assert.Equal(envelope.Text("eventId"), envelope.Text("requestId")); Assert.Equal("alice", envelope["payload"]!["userId"]!.GetValue<string>());
            await Task.CompletedTask; return RelayOutcome.Ack;
        }
        var result = await relay.RunAsync(Deliver, new(Owner: "test"), CancellationToken.None);
        Assert.Equal(new RelayReport(1, 1, 0, 0), result); Assert.Equal(targets, calls.Count); Assert.Equal("learning", calls[0]);
        if (targets == 2) Assert.Equal("ai", calls[1]);
        var row = fixture.Driver.Rows[("p_outbox", id)]; Assert.Equal("ACK", row.Text("status")); Assert.Null(row["leaseOwner"]); Assert.Equal(0, row.Number("attempt")); Assert.Equal("2026-11-03T10:00:00.000Z", row.Text("ackAt"));
        Assert.Equal(new RelayReport(0, 0, 0, 0), await relay.RunAsync(Deliver, new(), CancellationToken.None));
        Assert.Equal(targets, calls.Count);
    }

    [Theory]
    [InlineData(0, "PENDING", 1)]
    [InlineData(9, "DEAD", 10)]
    public async Task FailedTarget_RequeuesWithBackoffOrStopsAtTenthAttempt(int attempt, string status, int nextAttempt)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>(); var id = Seed(fixture, "account.deleted.v1");
        fixture.Driver.Rows[("p_outbox", id)]["attempt"] = attempt; var calls = 0;
        var report = await new ProgressOutboxRelay(store, fixture.Services.GetRequiredService<TimeProvider>()).RunAsync((target, _, _) => { calls++; return Task.FromResult(target == "learning" ? RelayOutcome.Ack : RelayOutcome.Retry); }, new(Owner: "test", Random: () => 0), CancellationToken.None);
        Assert.Equal(new RelayReport(1, 0, 1, 0), report); Assert.Equal(2, calls);
        var row = fixture.Driver.Rows[("p_outbox", id)]; Assert.Equal(status, row.Text("status")); Assert.Equal(nextAttempt, row.Number("attempt")); Assert.Null(row["leaseUntil"]);
        if (attempt == 0) Assert.Equal("2026-11-03T10:00:01.000Z", row.Text("nextAttemptAt"));
    }

    [Theory]
    [InlineData("unknown.v1", "{}")]
    [InlineData("energy.granted.v1", "bad-json")]
    public async Task InvalidStoredEvent_DeadLettersWithoutNetwork(string type, string payload)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient(); using var scope = fixture.Services.CreateScope();
        var id = Seed(fixture, type); fixture.Driver.Rows[("p_outbox", id)]["payloadJson"] = payload;
        var calls = 0;
        var result = await new ProgressOutboxRelay(scope.ServiceProvider.GetRequiredService<OwnerStore>(), fixture.Services.GetRequiredService<TimeProvider>()).RunAsync((_, _, _) => { calls++; return Task.FromResult(RelayOutcome.Ack); }, new(), CancellationToken.None);
        Assert.Equal(new RelayReport(1, 0, 0, 1), result); Assert.Equal(0, calls); Assert.Equal("DEAD", fixture.Driver.Rows[("p_outbox", id)].Text("status"));
    }

    private static string Seed(ProgressApiFixture fixture, string type)
    {
        var eventId = Guid.NewGuid().ToString(); var id = CanonicalWire.RowId("p_outbox", eventId);
        fixture.Driver.Rows[("p_outbox", id)] = new() { ["eventId"] = eventId, ["type"] = type, ["schemaVersion"] = 1, ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now),
            ["payloadJson"] = "{\"userId\":\"alice\"}", ["attempt"] = 0, ["nextAttemptAt"] = OwnerSchema.Iso(fixture.Now), ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null, ["revision"] = 0 };
        return id;
    }
}
