using System.Globalization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CocEnglish.Progress.Application;

/// <summary>Runs one serialized tick loop on the explicitly designated Progress worker instance.</summary>
public sealed class ProgressWorkerService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    TimeProvider clock,
    ILogger<ProgressWorkerService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!bool.TryParse(configuration["COC_PROGRESS_WORKER_ENABLED"], out var enabled) || !enabled) return;

        var interval = ParseInterval(configuration["COC_WORKER_INTERVAL_MS"]);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var worker = scope.ServiceProvider.GetRequiredService<IProgressScheduledTick>();
                var report = await worker.RunAsync(stoppingToken);
                logger.LogInformation("Progress worker tick completed at {At}: {Jobs}", report.At, report.Jobs.ToJsonString());
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception error)
            {
                logger.LogWarning("Progress worker tick failed with {ErrorCode}", error is ServiceException serviceError ? serviceError.Code : "JOB_FAILED");
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
