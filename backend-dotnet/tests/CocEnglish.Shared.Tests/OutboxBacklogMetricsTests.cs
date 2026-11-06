using System.Diagnostics.Metrics;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class OutboxBacklogMetricsTests
{
    [Theory]
    [InlineData("progress", "p_outbox")]
    [InlineData("learning", "l_outbox")]
    [InlineData("ai", "a_outbox")]
    public async Task Refresh_ReadsOnlyOwnerQueueAndPublishesCountsAndOldestActiveAge(string owner, string table)
    {
        var driver = new Driver(owner, table);
        var clock = new Clock();
        using var provider = new ServiceCollection().AddScoped(_ => new OwnerStore(driver, clock)).BuildServiceProvider();
        var settings = new RuntimeSettings(owner, "test", null, null, null, true, new Dictionary<string, CocEnglish.Shared.Security.ServiceKey>(), new HashSet<string>());
        using var service = new OutboxBacklogMetricsService(owner, provider.GetRequiredService<IServiceScopeFactory>(), settings, clock, NullLogger<OutboxBacklogMetricsService>.Instance);
        var counts = new Dictionary<string, long>();
        double? age = null;
        using var listener = new MeterListener();
        listener.InstrumentPublished = (instrument, meter) =>
        {
            if (instrument.Meter.Name == "CocEnglish.Workers") meter.EnableMeasurementEvents(instrument);
        };
        listener.SetMeasurementEventCallback<long>((instrument, value, tags, _) =>
        {
            if (instrument.Name != "cocenglish.outbox.backlog") return;
            string? serviceTag = null, state = null;
            foreach (var tag in tags)
            {
                if (tag.Key == "service") serviceTag = (string?)tag.Value;
                if (tag.Key == "state") state = (string?)tag.Value;
            }
            if (serviceTag == owner) counts[state!] = value;
        });
        listener.SetMeasurementEventCallback<double>((instrument, value, tags, _) =>
        {
            if (instrument.Name != "cocenglish.outbox.oldest_event.age") return;
            foreach (var tag in tags) if (tag.Key == "service" && (string?)tag.Value == owner) age = value;
        });
        listener.Start();
        try
        {
            await service.StartAsync(default);
            await clock.Waiting.Task.WaitAsync(TimeSpan.FromSeconds(5));
            listener.RecordObservableInstruments();
            Assert.Equal(12L, counts["pending"]);
            Assert.Equal(3L, counts["leased"]);
            Assert.Equal(2L, counts["dead"]);
            Assert.Equal(120_000d, age);
            Assert.Equal(["PENDING", "LEASED", "DEAD"], driver.States);
        }
        finally
        {
            await service.StopAsync(default);
            WorkerTelemetry.ClearOutboxBacklog(owner);
        }
    }

    private sealed class Clock : TimeProvider
    {
        public TaskCompletionSource Waiting { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-05T10:00:00Z");
        public override ITimer CreateTimer(TimerCallback callback, object? state, TimeSpan dueTime, TimeSpan period)
        {
            var timer = TimeProvider.System.CreateTimer(callback, state, Timeout.InfiniteTimeSpan, Timeout.InfiniteTimeSpan);
            Waiting.TrySetResult();
            return timer;
        }
    }

    private sealed class Driver(string owner, string table) : IRowDriver
    {
        public string Owner => owner;
        public bool Configured => true;
        public List<string> States { get; } = [];
        public Task<RowDocument?> ReadAsync(string requestedTable, string id, CancellationToken ct) => throw new NotSupportedException();
        public Task<long> CountAsync(string requestedTable, IReadOnlyDictionary<string, object?> where, CancellationToken ct)
        {
            Assert.Equal(table, requestedTable);
            var status = Assert.IsType<string>(where["status"]);
            States.Add(status);
            return Task.FromResult(status switch { "PENDING" => 12L, "LEASED" => 3L, "DEAD" => 2L, _ => throw new NotSupportedException() });
        }
        public Task<IReadOnlyList<RowDocument>> ListAsync(string requestedTable, RowQuery query, CancellationToken ct)
        {
            Assert.Equal(table, requestedTable);
            Assert.Equal(["PENDING", "LEASED"], query.AnyOf!["status"]);
            Assert.Equal(new RowOrder("occurredAt"), Assert.Single(query.OrderBy!));
            Assert.Equal("occurredAt", Assert.Single(query.Select!));
            return Task.FromResult<IReadOnlyList<RowDocument>>([new("oldest", new JsonObject { ["occurredAt"] = "2026-11-05T09:58:00Z" }, null)]);
        }
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct) => throw new InvalidOperationException("Metrics must not write queue rows");
    }
}
