using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Globalization;

namespace CocEnglish.Shared.Hosting;

/// <summary>Refreshes owner-scoped queue counts only for an admitted host with metrics export enabled.</summary>
public sealed class OutboxBacklogMetricsService(
    string service,
    IServiceScopeFactory scopeFactory,
    RuntimeSettings settings,
    TimeProvider clock,
    ILogger<OutboxBacklogMetricsService> logger) : BackgroundService
{
    private static readonly TimeSpan RefreshInterval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var table = service switch
        {
            "progress" => "p_outbox",
            "learning" => "l_outbox",
            "ai" => "a_outbox",
            _ => throw new ArgumentOutOfRangeException(nameof(service))
        };

        while (!stoppingToken.IsCancellationRequested)
        {
            if (settings.Admitted)
            {
                try
                {
                    using var scope = scopeFactory.CreateScope();
                    var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
                    var pending = await CountAsync(store, table, "PENDING", stoppingToken);
                    var leased = await CountAsync(store, table, "LEASED", stoppingToken);
                    var dead = await CountAsync(store, table, "DEAD", stoppingToken);
                    var oldestActiveEventAge = await OldestActiveEventAgeMillisecondsAsync(store, table, stoppingToken);
                    WorkerTelemetry.RecordOutboxBacklog(service, pending, leased, dead, oldestActiveEventAge);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception error)
                {
                    WorkerTelemetry.ClearOutboxBacklog(service);
                    logger.LogWarning("Outbox backlog metrics refresh failed with {ErrorCode}",
                        error is ServiceException serviceError ? serviceError.Code : "METRIC_REFRESH_FAILED");
                }
            }
            else
            {
                WorkerTelemetry.ClearOutboxBacklog(service);
            }

            try { await Task.Delay(RefreshInterval, clock, stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }

    private static Task<long> CountAsync(OwnerStore store, string table, string status, CancellationToken ct) =>
        store.CountAsync(table, new Dictionary<string, object?> { ["status"] = status }, ct);

    private async Task<double?> OldestActiveEventAgeMillisecondsAsync(OwnerStore store, string table, CancellationToken ct)
    {
        var rows = await store.ListAsync(table, new RowQuery(
            AnyOf: new Dictionary<string, string[]> { ["status"] = ["PENDING", "LEASED"] },
            OrderBy: [new RowOrder("occurredAt")],
            Limit: 1,
            Select: ["occurredAt"]), ct);
        if (rows.Count == 0) return null;

        var occurredAt = DateTimeOffset.Parse(rows[0].Data["occurredAt"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        return Math.Max(0, (clock.GetUtcNow() - occurredAt).TotalMilliseconds);
    }
}
