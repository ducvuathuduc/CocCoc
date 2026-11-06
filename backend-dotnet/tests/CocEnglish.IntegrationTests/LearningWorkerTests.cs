using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningWorkerTests
{
    [Theory]
    [InlineData("15000", 15000)]
    [InlineData("999", 60000)]
    [InlineData("3600001", 60000)]
    [InlineData("invalid", 60000)]
    public void Interval_IsBoundedAndDefaultsToOneMinute(string value, int expectedMilliseconds) =>
        Assert.Equal(TimeSpan.FromMilliseconds(expectedMilliseconds), LearningWorkerService.ParseInterval(value));

    [Fact]
    public async Task EnabledWorker_NeverOverlapsAndCancelsTheActiveTickOnShutdown()
    {
        var tick = new BlockingTick();
        using var host = BuildHost(tick, enabled: true);
        await host.StartAsync();
        await tick.Started.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await Task.Delay(50);
        Assert.Equal(1, tick.Calls);

        await host.StopAsync(TimeSpan.FromSeconds(5));
        Assert.True(tick.CancellationObserved);
        Assert.Equal(1, tick.Calls);
    }

    [Fact]
    public async Task DisabledWorker_DoesNotRunScheduledJobs()
    {
        var tick = new BlockingTick();
        using var host = BuildHost(tick, enabled: false);
        await host.StartAsync();
        await Task.Delay(50);
        Assert.Equal(0, tick.Calls);
        await host.StopAsync(TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task ScheduledTick_FailsClosedUntilHostIsAdmittedAndRelayIsConfigured()
    {
        var driver = new EmptyDriver();
        var clock = TimeProvider.System;
        var relay = new Relay { Configured = true };
        var runner = new LearningOutboxJobRunner(new OwnerStore(driver, clock), relay, clock);
        var keyring = new Dictionary<string, CocEnglish.Shared.Security.ServiceKey>();
        var cors = new HashSet<string>(StringComparer.Ordinal);
        var unadmitted = new RuntimeSettings("learning", "test", null, null, null, false, keyring, cors);
        var worker = new LearningScheduledTick(runner, unadmitted, relay);

        var rejected = await Assert.ThrowsAsync<ServiceException>(() => worker.RunAsync(CancellationToken.None));
        Assert.Equal("SERVICE_NOT_CONFIGURED", rejected.Code);
        Assert.Empty(relay.Deliveries);

        var admitted = unadmitted with { Admitted = true };
        relay.Configured = false;
        worker = new LearningScheduledTick(runner, admitted, relay);
        var noRelay = await Assert.ThrowsAsync<ServiceException>(() => worker.RunAsync(CancellationToken.None));
        Assert.Equal("SERVICE_NOT_CONFIGURED", noRelay.Code);
        Assert.Empty(relay.Deliveries);
    }

    private static IHost BuildHost(BlockingTick tick, bool enabled) => new HostBuilder()
        .ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["COC_LEARNING_WORKER_ENABLED"] = enabled.ToString(), ["COC_WORKER_INTERVAL_MS"] = "1000"
        }))
        .ConfigureServices(services =>
        {
            services.AddSingleton<TimeProvider>(TimeProvider.System);
            services.AddSingleton(tick);
            services.AddScoped<ILearningScheduledTick>(sp => sp.GetRequiredService<BlockingTick>());
            services.AddHostedService<LearningWorkerService>();
        }).Build();

    private sealed class BlockingTick : ILearningScheduledTick
    {
        private int calls;
        public int Calls => Volatile.Read(ref calls);
        public bool CancellationObserved { get; private set; }
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<LearningJobRunReport> RunAsync(CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref calls);
            Started.TrySetResult();
            try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                CancellationObserved = true;
                throw;
            }
            return new("LEARNING_OUTBOX_DISPATCH", "11111111-1111-4111-8111-111111111111", "", "", 0, 0, 0, 0, 0, null, false);
        }
    }

    private sealed class Relay : ILearningRelayTransport
    {
        public bool Configured { get; set; }
        public List<System.Text.Json.Nodes.JsonObject> Deliveries { get; } = [];
        public Task<LearningRelayOutcome> DeliverAsync(System.Text.Json.Nodes.JsonObject envelope, CancellationToken ct)
        {
            Deliveries.Add(envelope);
            return Task.FromResult(LearningRelayOutcome.Ack);
        }
    }

    private sealed class EmptyDriver : IRowDriver
    {
        public string Owner => "learning";
        public bool Configured => true;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => throw new NotSupportedException();
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => throw new NotSupportedException();
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct) => throw new NotSupportedException();
    }
}
