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
                    var snapshot = await store.TransactAsync(async (session, ct) =>
                    {
                        var pending = await CountAsync(session, table, "PENDING", ct);
                        var leased = await CountAsync(session, table, "LEASED", ct);
                        var dead = await CountAsync(session, table, "DEAD", ct);
                        var oldestActiveEventAge = await OldestActiveEventAgeMillisecondsAsync(session, table, ct);
                        return (pending, leased, dead, oldestActiveEventAge);
                    }, stoppingToken);
                    WorkerTelemetry.RecordOutboxBacklog(service, snapshot.pending, snapshot.leased, snapshot.dead, snapshot.oldestActiveEventAge);
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

    private static Task<long> CountAsync(OwnerSession session, string table, string status, CancellationToken ct) =>
        session.CountAsync(table, new Dictionary<string, object?> { ["status"] = status }, ct);

    private async Task<double?> OldestActiveEventAgeMillisecondsAsync(OwnerSession session, string table, CancellationToken ct)
    {
        var rows = await session.ListAsync(table, new RowQuery(
            AnyOf: new Dictionary<string, string[]> { ["status"] = ["PENDING", "LEASED"] },
            OrderBy: [new RowOrder("occurredAt")],
            Limit: 1,
            Select: ["occurredAt"]), ct);
        if (rows.Count == 0) return null;

        var occurredAt = DateTimeOffset.Parse(rows[0].Data["occurredAt"]!.GetValue<string>(), CultureInfo.InvariantCulture);
        return Math.Max(0, (clock.GetUtcNow() - occurredAt).TotalMilliseconds);
    }
}
