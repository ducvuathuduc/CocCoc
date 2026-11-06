using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ProgressWorkerTests
{
    [Theory]
    [InlineData("2026-11-03T10:05:00Z", "streakRollover")]
    [InlineData("2026-11-03T10:15:00Z", "leagueSettlement")]
    [InlineData("2026-11-03T10:06:00Z", null)]
    public async Task ScheduledTick_FollowsNodeUtcCadenceAndAlwaysRetriesDeletion(string at, string? scheduledJob)
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse(at) };
        using var scope = fixture.Services.CreateScope();
        var report = await scope.ServiceProvider.GetRequiredService<ProgressJobRunner>().RunScheduledTickAsync(CancellationToken.None);

        Assert.Equal("progress", report.Worker);
        Assert.Contains("deletionPurge", report.Jobs.Select(job => job.Key));
        Assert.DoesNotContain("outboxRelay", report.Jobs.Select(job => job.Key)); // no Progress relay key is configured in the fixture
        foreach (var job in new[] { "streakRollover", "leagueSettlement" })
        {
            if (job == scheduledJob) Assert.Contains(job, report.Jobs.Select(entry => entry.Key));
            else Assert.DoesNotContain(job, report.Jobs.Select(entry => entry.Key));
        }
    }

    [Theory]
    [InlineData("15000", 15000)]
    [InlineData("999", 60000)]
    [InlineData("3600001", 60000)]
    [InlineData("invalid", 60000)]
    public void Interval_IsBoundedAndDefaultsLikeNode(string value, int expectedMilliseconds) =>
        Assert.Equal(TimeSpan.FromMilliseconds(expectedMilliseconds), ProgressWorkerService.ParseInterval(value));

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

    private static IHost BuildHost(BlockingTick tick, bool enabled) => new HostBuilder()
        .ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["COC_PROGRESS_WORKER_ENABLED"] = enabled.ToString(), ["COC_WORKER_INTERVAL_MS"] = "1000"
        }))
        .ConfigureServices(services =>
        {
            services.AddSingleton<TimeProvider>(TimeProvider.System);
            services.AddSingleton(tick);
            services.AddScoped<IProgressScheduledTick>(sp => sp.GetRequiredService<BlockingTick>());
            services.AddHostedService<ProgressWorkerService>();
        }).Build();

    private sealed class BlockingTick : IProgressScheduledTick
    {
        private int calls;
        public int Calls => Volatile.Read(ref calls);
        public bool CancellationObserved { get; private set; }
        public TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<ProgressWorkerReport> RunAsync(CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref calls);
            Started.TrySetResult();
            try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                CancellationObserved = true;
                throw;
            }
            return new("progress", "2026-11-03T10:00:00.000Z", []);
        }
    }
}
