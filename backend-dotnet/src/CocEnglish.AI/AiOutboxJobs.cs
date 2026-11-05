using System.Globalization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CocEnglish.AI;

public sealed record AiJobRunReport(string TickId, string StartedAt, string FinishedAt, AiDispatchReport Dispatch);

public sealed class AiOutboxJobRunner(OwnerStore store, IAiRelayTransport relay, TimeProvider clock)
{
    public async Task<AiJobRunReport> RunAsync(string tickId, TimeSpan deadline, CancellationToken ct)
    {
        var startedTimestamp = System.Diagnostics.Stopwatch.GetTimestamp();
        try
        {
            if (!relay.Configured)
                throw new ServiceException("SERVICE_NOT_CONFIGURED", new() { ["job"] = "ai-outbox-dispatch" });

            var started = OwnerSchema.Iso(clock.GetUtcNow());
            var dispatch = await new AiOutboxDispatcher(store, clock).RunAsync(relay.DeliverAsync,
                new(Owner: "tick-" + tickId[..8] + "-" + Guid.NewGuid().ToString("N")[..8], Limit: 20, Deadline: deadline), ct);
            var report = new AiJobRunReport(tickId, started, OwnerSchema.Iso(clock.GetUtcNow()), dispatch);

            WorkerTelemetry.RecordOutbox("ai", dispatch.Leased, dispatch.Acked, dispatch.Retried, dispatch.Dead);
            WorkerTelemetry.RecordTick("ai", "outbox_dispatch", "success", startedTimestamp);
            return report;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            WorkerTelemetry.RecordTick("ai", "outbox_dispatch", "cancelled", startedTimestamp);
            throw;
        }
        catch
        {
            WorkerTelemetry.RecordTick("ai", "outbox_dispatch", "failure", startedTimestamp);
            throw;
        }
    }
}

public interface IAiScheduledTick
{
    Task<AiJobRunReport> RunAsync(CancellationToken cancellationToken);
}

public sealed class AiScheduledTick(AiOutboxJobRunner runner, RuntimeSettings settings, IAiRelayTransport relay) : IAiScheduledTick
{
    public Task<AiJobRunReport> RunAsync(CancellationToken cancellationToken)
    {
        if (!settings.Admitted || !relay.Configured)
            return Task.FromException<AiJobRunReport>(new ServiceException("SERVICE_NOT_CONFIGURED", new() { ["job"] = "ai-outbox-dispatch" }));
        return runner.RunAsync(Guid.NewGuid().ToString(), TimeSpan.FromSeconds(20), cancellationToken);
    }
}

/// <summary>Runs serialized AI outbox ticks only when explicitly enabled on an admitted host.</summary>
public sealed class AiWorkerService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    TimeProvider clock,
    ILogger<AiWorkerService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!bool.TryParse(configuration["COC_AI_WORKER_ENABLED"], out var enabled) || !enabled) return;
        var interval = ParseInterval(configuration["COC_WORKER_INTERVAL_MS"]);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var worker = scope.ServiceProvider.GetRequiredService<IAiScheduledTick>();
                var report = await worker.RunAsync(stoppingToken);
                logger.LogInformation("AI outbox worker tick {TickId} completed: leased {Leased}, acked {Acked}, retried {Retried}, dead {Dead}",
                    report.TickId, report.Dispatch.Leased, report.Dispatch.Acked, report.Dispatch.Retried, report.Dispatch.Dead);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception error)
            {
                logger.LogWarning("AI outbox worker tick failed with {ErrorCode}", error is ServiceException serviceError ? serviceError.Code : "JOB_FAILED");
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
