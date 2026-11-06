using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class AppwriteOutboxLiveTests
{
    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task ExpiredLease_NewClientAcknowledgesAndOldWorkerCannotOverwriteIt()
    {
        var connection = AppwriteStorageLiveConfiguration.FromEnvironment();
        using var originalClient = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        using var recoveryClient = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        await OutboxLeaseProbe.RunAsync(new AppwriteRowDriver(originalClient, connection, "progress"),
            new AppwriteRowDriver(recoveryClient, connection, "progress"), deadline.Token);
    }
}

public sealed class OutboxLeaseProbeTests
{
    [Fact]
    public async Task Probe_ExercisesLeaseBoundaryAndLateWorkerWithoutTouchingOtherEvents()
    {
        await using var fixture = new ProgressApiFixture();
        fixture.Driver.Rows.Clear();
        var sentinelId = CanonicalWire.RowId("p_outbox", "unrelated-event");
        var sentinel = new JsonObject { ["eventId"] = "unrelated-event", ["aggregateId"] = "another-user", ["status"] = "PENDING" };
        fixture.Driver.Rows[("p_outbox", sentinelId)] = sentinel.DeepClone().AsObject();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        await OutboxLeaseProbe.RunAsync(fixture.Driver, fixture.Driver, deadline.Token);
        Assert.Single(fixture.Driver.Rows);
        Assert.True(JsonNode.DeepEquals(sentinel, fixture.Driver.Rows[("p_outbox", sentinelId)]));
    }
}

internal static class OutboxLeaseProbe
{
    internal static async Task RunAsync(IRowDriver originalDriver, IRowDriver recoveryDriver, CancellationToken ct)
    {
        var clock = new ProbeClock();
        var eventId = Guid.NewGuid().ToString();
        var userId = "dn_" + Guid.NewGuid().ToString("N");
        var id = CanonicalWire.RowId("p_outbox", eventId);
        var originalStore = new OwnerStore(originalDriver, clock);
        var recoveryStore = new OwnerStore(recoveryDriver, clock);
        var attempted = false;
        try
        {
            Assert.Null(await originalDriver.ReadAsync("p_outbox", id, ct));
            attempted = true;
            await originalStore.TransactAsync((tx, token) =>
            {
                tx.Put("p_outbox", id, new()
                {
                    ["eventId"] = eventId, ["type"] = "energy.granted.v1", ["schemaVersion"] = 1, ["aggregateId"] = userId,
                    ["occurredAt"] = tx.NowIso, ["payloadJson"] = CanonicalWire.Stringify(new JsonObject
                    { ["userId"] = userId, ["operationId"] = eventId, ["amount"] = null, ["refillToCapacity"] = true, ["reason"] = "SHOP" }),
                    ["attempt"] = 0, ["nextAttemptAt"] = tx.NowIso, ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null
                });
                return Task.FromResult(0);
            }, ct);
            var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var release = new TaskCompletionSource<RelayOutcome>(TaskCreationOptions.RunContinuationsAsynchronously);
            var oldTask = new ProgressOutboxRelay(originalStore, clock).RunAsync(async (target, envelope, token) =>
            {
                Assert.Equal("learning", target);
                Assert.Equal(eventId, envelope.Text("eventId"));
                entered.TrySetResult();
                return await release.Task.WaitAsync(token);
            }, new(Owner: "probe-old", RowIds: [id]), ct);
            try
            {
                await entered.Task.WaitAsync(ct);
                var leased = Assert.IsType<RowDocument>(await recoveryDriver.ReadAsync("p_outbox", id, ct));
                Assert.Equal("LEASED", leased.Data.Text("status"));
                Assert.Equal("probe-old", leased.Data.Text("leaseOwner"));
                var expiry = DateTimeOffset.Parse(leased.Data.Text("leaseUntil")!, System.Globalization.CultureInfo.InvariantCulture);
                var recoveryCalls = 0;
                Task<RelayOutcome> Deliver(string target, JsonObject envelope, CancellationToken token)
                {
                    recoveryCalls++;
                    Assert.Equal("learning", target);
                    Assert.Equal(eventId, envelope.Text("eventId"));
                    Assert.Equal(userId, envelope["payload"]!["userId"]!.GetValue<string>());
                    return Task.FromResult(RelayOutcome.Ack);
                }
                var recovery = new ProgressOutboxRelay(recoveryStore, clock);
                Assert.Equal(new RelayReport(0, 0, 0, 0), await recovery.RunAsync(Deliver, new(Owner: "probe-new", RowIds: [id]), ct));
                clock.Now = expiry;
                Assert.Equal(new RelayReport(0, 0, 0, 0), await recovery.RunAsync(Deliver, new(Owner: "probe-new", RowIds: [id]), ct));
                Assert.Equal(0, recoveryCalls);
                clock.Now = expiry.AddMilliseconds(1);
                Assert.Equal(new RelayReport(1, 1, 0, 0), await recovery.RunAsync(Deliver, new(Owner: "probe-new", RowIds: [id]), ct));
                Assert.Equal(1, recoveryCalls);
                var acknowledged = Assert.IsType<RowDocument>(await recoveryDriver.ReadAsync("p_outbox", id, ct));
                Assert.Equal("ACK", acknowledged.Data.Text("status"));
                Assert.Equal(0, acknowledged.Data.Number("attempt"));
                Assert.Null(acknowledged.Data.Text("leaseOwner"));
                Assert.Null(acknowledged.Data.Text("leaseUntil"));
                Assert.Equal(OwnerSchema.Iso(clock.Now), acknowledged.Data.Text("ackAt"));
                release.TrySetResult(RelayOutcome.Retry);
                await oldTask;
                var afterOldWorker = Assert.IsType<RowDocument>(await originalDriver.ReadAsync("p_outbox", id, ct));
                Assert.True(JsonNode.DeepEquals(acknowledged.Data, afterOldWorker.Data), "Late worker changed the new owner's acknowledged event.");
                Assert.Equal(new RelayReport(0, 0, 0, 0), await recovery.RunAsync(Deliver, new(Owner: "probe-third", RowIds: [id]), ct));
                Assert.Equal(1, recoveryCalls);
            }
            finally
            {
                release.TrySetResult(RelayOutcome.Retry);
                await oldTask;
            }
        }
        finally
        {
            if (attempted)
            {
                using var cleanup = new CancellationTokenSource(TimeSpan.FromSeconds(30));
                var row = await recoveryDriver.ReadAsync("p_outbox", id, cleanup.Token);
                if (row is not null)
                {
                    if (row.Data.Text("eventId") != eventId || row.Data.Text("aggregateId") != userId ||
                        JsonNode.Parse(row.Data.Text("payloadJson")!)?["operationId"]?.GetValue<string>() != eventId)
                        throw new InvalidOperationException("Outbox probe cleanup refused a row without its synthetic markers.");
                    await recoveryDriver.CommitAsync([new("p_outbox", id, "delete")], [("p_outbox", id, row)], cleanup.Token);
                    Assert.Null(await originalDriver.ReadAsync("p_outbox", id, cleanup.Token));
                }
            }
        }
    }

    private sealed class ProbeClock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow() => Now;
    }
}
