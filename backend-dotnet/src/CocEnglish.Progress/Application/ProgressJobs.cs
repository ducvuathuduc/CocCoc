using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Domain;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed record ProgressJobTick(string TickId, int? Limit, string? WeekId);
public sealed record JobRunReport(string Job, string TickId, string StartedAt, string FinishedAt, int Processed, int Succeeded,
    int Retried, int Dead, int Skipped, string? NextCursor, bool NeedsIntervention);
public sealed record ProgressWorkerReport(string Worker, string At, JsonObject Jobs);

public interface IProgressScheduledTick
{
    Task<ProgressWorkerReport> RunAsync(CancellationToken cancellationToken);
}

public sealed class ProgressJobRunner(
    OwnerStore store,
    ProgressSettlement settlement,
    ILearningWatermark watermark,
    IProgressRelayTransport transport,
    TimeProvider clock,
    IRelayJitterSource relayJitter)
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);

    public Task<JobRunReport> RunStreakRolloverAsync(ProgressJobTick tick, CancellationToken ct) =>
        RunMeasuredJobAsync("streak_rollover", () => RunStreakRolloverCoreAsync(tick, ct), ct);

    private async Task<JobRunReport> RunStreakRolloverCoreAsync(ProgressJobTick tick, CancellationToken ct)
    {
        var started = OwnerSchema.Iso(clock.GetUtcNow());
        var cutoff = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime).AddDays(-1).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var candidates = await store.TransactAsync((tx, token) => tx.ListAsync("p_rewards", new(
            GreaterThanEqual: new Dictionary<string, object?> { ["currentStreak"] = 1 }, LessThan: new Dictionary<string, object?> { ["lastQualifiedDay"] = cutoff },
            OrderBy: [new("lastQualifiedDay")], Limit: Math.Min(tick.Limit ?? 200, 500)), token), ct);
        var succeeded = 0; var skipped = 0; var retried = 0;
        foreach (var candidate in candidates)
        {
            try
            {
                var result = await store.TransactAsync((tx, token) => new ProgressRollover().ProcessAsync(tx, candidate.Data.Text("userId")!, token), ct);
                if (result.ProtectedDays.Count > 0 || result.LostStreak is not null) succeeded++; else skipped++;
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { retried++; }
        }
        return new("STREAK_ROLLOVER", tick.TickId, started, OwnerSchema.Iso(clock.GetUtcNow()), candidates.Count, succeeded, retried, 0, skipped, null, false);
    }

    public Task<JobRunReport> RunLeagueSettlementAsync(ProgressJobTick tick, CancellationToken ct) =>
        RunMeasuredJobAsync("league_settlement", () => RunLeagueSettlementCoreAsync(tick, ct), ct);

    private async Task<JobRunReport> RunLeagueSettlementCoreAsync(ProgressJobTick tick, CancellationToken ct)
    {
        var started = OwnerSchema.Iso(clock.GetUtcNow());
        var day = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime).AddDays(-7);
        var previousMonday = day.AddDays(-(((int)day.DayOfWeek + 6) % 7)).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var weeks = new SortedSet<string>(StringComparer.Ordinal) { tick.WeekId ?? previousMonday };
        if (tick.WeekId is null)
        {
            var pending = await store.TransactAsync((tx, token) => tx.ListAsync("p_league_runs", new(
                Where: new Dictionary<string, object?> { ["status"] = "SETTLING" }, Limit: 500), token), ct);
            foreach (var run in pending) weeks.Add(run.Data.Text("weekId")!);
        }
        var closed = 0; var retried = 0; var intervention = false;
        foreach (var week in weeks)
        {
            var report = await settlement.SettleAsync(week, watermark, ct);
            closed += report.Closed.Count; retried += report.Settling.Count; intervention |= report.NeedsIntervention;
        }
        return new("LEAGUE_SETTLEMENT", tick.TickId, started, OwnerSchema.Iso(clock.GetUtcNow()), closed + retried, closed, retried, 0, 0, null, intervention);
    }

    public Task<JobRunReport> RunDeletionPurgeAsync(ProgressJobTick tick, CancellationToken ct) =>
        RunMeasuredJobAsync("deletion_purge", () => RunDeletionPurgeCoreAsync(tick, ct), ct);

    private async Task<JobRunReport> RunDeletionPurgeCoreAsync(ProgressJobTick tick, CancellationToken ct)
    {
        var started = OwnerSchema.Iso(clock.GetUtcNow());
        var rows = await store.TransactAsync((tx, token) => tx.ListAsync("p_deletions", new(
            Where: new Dictionary<string, object?> { ["status"] = "PURGING" },
            OrderBy: [new("requestedAt")], Limit: Math.Min(tick.Limit ?? 20, 100)), token), ct);
        var succeeded = 0; var retried = 0;
        foreach (var row in rows)
        {
            try
            {
                if (await new ProgressDeletion(store).PurgeAsync(row.Data.Text("userId")!, 50, ct)) succeeded++;
                else retried++;
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { retried++; }
        }
        return new("DELETION_PURGE", tick.TickId, started, OwnerSchema.Iso(clock.GetUtcNow()), rows.Count, succeeded, retried, 0, 0, null, false);
    }

    public Task<JobRunReport> RunOutboxRelayAsync(ProgressJobTick tick, CancellationToken ct) =>
        RunMeasuredJobAsync("outbox_relay", () => RunOutboxRelayCoreAsync(tick, ct), ct);

    private async Task<JobRunReport> RunOutboxRelayCoreAsync(ProgressJobTick tick, CancellationToken ct)
    {
        if (!transport.Configured)
            throw new ServiceException("SERVICE_NOT_CONFIGURED", new() { ["job"] = "relay" });

        var started = OwnerSchema.Iso(clock.GetUtcNow());
        var owner = "tick-" + tick.TickId[..8] + "-" + Guid.NewGuid().ToString("N")[..8];
        var dispatch = await new ProgressOutboxRelay(store, clock).RunAsync(transport.DeliverAsync,
            new(Owner: owner, Limit: Math.Min(tick.Limit ?? 20, 20), Deadline: TimeSpan.FromSeconds(20), Random: relayJitter.NextDouble), ct);
        var report = new JobRunReport("PROGRESS_OUTBOX_RELAY", tick.TickId, started, OwnerSchema.Iso(clock.GetUtcNow()),
            dispatch.Leased, dispatch.Acked, dispatch.Retried, dispatch.Dead,
            dispatch.Leased - dispatch.Acked - dispatch.Retried - dispatch.Dead, null, false);

        WorkerTelemetry.RecordOutbox("progress", dispatch.Leased, dispatch.Acked, dispatch.Retried, dispatch.Dead);
        return report;
    }

    private static async Task<JobRunReport> RunMeasuredJobAsync(string worker, Func<Task<JobRunReport>> action, CancellationToken ct)
    {
        var startedTimestamp = System.Diagnostics.Stopwatch.GetTimestamp();
        try
        {
            var report = await action();
            WorkerTelemetry.RecordTick("progress", worker, "success", startedTimestamp);
            return report;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            WorkerTelemetry.RecordTick("progress", worker, "cancelled", startedTimestamp);
            throw;
        }
        catch
        {
            WorkerTelemetry.RecordTick("progress", worker, "failure", startedTimestamp);
            throw;
        }
    }

    public async Task<ProgressWorkerReport> RunScheduledTickAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var tick = new ProgressJobTick(Guid.NewGuid().ToString(), null, null);
        var jobs = new JsonObject();

        async Task Run(string name, Func<Task<JobRunReport>> action)
        {
            try { jobs[name] = JsonSerializer.SerializeToNode(await action(), WebJson); }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (Exception error)
            {
                jobs[name] = new JsonObject { ["error"] = error is ServiceException serviceError ? serviceError.Code : "JOB_FAILED" };
            }
        }

        if (transport.Configured) await Run("outboxRelay", () => RunOutboxRelayAsync(tick, ct));
        await Run("deletionPurge", () => RunDeletionPurgeAsync(tick, ct));
        if (now.UtcDateTime.Minute == 5) await Run("streakRollover", () => RunStreakRolloverAsync(tick, ct));
        if (now.UtcDateTime.Minute == 15) await Run("leagueSettlement", () => RunLeagueSettlementAsync(tick, ct));
        return new("progress", OwnerSchema.Iso(now), jobs);
    }
}

public sealed class ProgressScheduledTick(ProgressJobRunner runner, RuntimeSettings settings) : IProgressScheduledTick
{
    public Task<ProgressWorkerReport> RunAsync(CancellationToken cancellationToken) => settings.Admitted
        ? runner.RunScheduledTickAsync(cancellationToken)
        : Task.FromException<ProgressWorkerReport>(new ServiceException("SERVICE_NOT_CONFIGURED"));
}
