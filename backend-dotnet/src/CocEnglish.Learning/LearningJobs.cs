using System.Globalization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CocEnglish.Learning;

/// <summary>Shared bounded dispatch path used by both the signed route and the scheduled worker.</summary>
public sealed class LearningOutboxJobRunner(OwnerStore store, ILearningRelayTransport transport, TimeProvider clock)
{
    public async Task<LearningJobRunReport> RunAsync(string tickId, int? limit, TimeSpan deadline, CancellationToken ct)
    {
        var startedTimestamp = System.Diagnostics.Stopwatch.GetTimestamp();
        try
        {
            if (!transport.Configured)
                throw new ServiceException("SERVICE_NOT_CONFIGURED", new() { ["job"] = "dispatch" });

            var started = OwnerSchema.Iso(clock.GetUtcNow());
            var owner = "tick-" + tickId[..8] + "-" + Guid.NewGuid().ToString("N")[..8];
            var dispatch = await new LearningOutboxDispatcher(store, clock).RunAsync(transport.DeliverAsync,
                new(Owner: owner, Limit: Math.Min(limit ?? 20, 20), Deadline: deadline), ct);
            var finished = OwnerSchema.Iso(clock.GetUtcNow());
            var report = new LearningJobRunReport("LEARNING_OUTBOX_DISPATCH", tickId, started, finished,
                dispatch.Leased, dispatch.Acked, dispatch.Retried, dispatch.Dead,
                dispatch.Leased - dispatch.Acked - dispatch.Retried - dispatch.Dead, null, false);

            WorkerTelemetry.RecordOutbox("learning", dispatch.Leased, dispatch.Acked, dispatch.Retried, dispatch.Dead);
            WorkerTelemetry.RecordTick("learning", "outbox_dispatch", "success", startedTimestamp);
            return report;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            WorkerTelemetry.RecordTick("learning", "outbox_dispatch", "cancelled", startedTimestamp);
            throw;
        }
        catch
        {
            WorkerTelemetry.RecordTick("learning", "outbox_dispatch", "failure", startedTimestamp);
            throw;
        }
    }
}

public interface ILearningScheduledTick
{
    Task<LearningJobRunReport> RunAsync(CancellationToken cancellationToken);
}

public sealed class LearningScheduledTick(
    LearningOutboxJobRunner runner,
    RuntimeSettings settings,
    ILearningRelayTransport transport) : ILearningScheduledTick
{
    public Task<LearningJobRunReport> RunAsync(CancellationToken cancellationToken)
    {
        if (!settings.Admitted || !transport.Configured)
            return Task.FromException<LearningJobRunReport>(new ServiceException("SERVICE_NOT_CONFIGURED", new() { ["job"] = "dispatch" }));
        var tick = new LearningJobTick(Guid.NewGuid().ToString(), 20);
        return runner.RunAsync(tick.TickId, tick.Limit, TimeSpan.FromSeconds(20), cancellationToken);
    }
}

/// <summary>Runs one serialized Learning outbox tick on the explicitly designated host instance.</summary>
public sealed class LearningWorkerService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    TimeProvider clock,
    ILogger<LearningWorkerService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!bool.TryParse(configuration["COC_LEARNING_WORKER_ENABLED"], out var enabled) || !enabled) return;

        var interval = ParseInterval(configuration["COC_WORKER_INTERVAL_MS"]);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var worker = scope.ServiceProvider.GetRequiredService<ILearningScheduledTick>();
                var report = await worker.RunAsync(stoppingToken);
                logger.LogInformation("Learning worker tick completed at {At}: processed {Processed}, succeeded {Succeeded}, retried {Retried}, dead {Dead}",
                    report.FinishedAt, report.Processed, report.Succeeded, report.Retried, report.Dead);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception error)
            {
                logger.LogWarning("Learning worker tick failed with {ErrorCode}", error is ServiceException serviceError ? serviceError.Code : "JOB_FAILED");
            }

            try { await Task.Delay(interval, clock, stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }

    public static TimeSpan ParseInterval(string? raw)
    {
        if (double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var milliseconds) &&
            double.IsFinite(milliseconds) && Math.Truncate(milliseconds) == milliseconds && milliseconds is >= 1000 and <= 3_600_000)
            return TimeSpan.FromMilliseconds(milliseconds);
        return TimeSpan.FromMinutes(1);
    }
}
