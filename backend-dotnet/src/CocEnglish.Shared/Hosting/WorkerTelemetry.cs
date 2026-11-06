using System.Collections.Concurrent;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace CocEnglish.Shared.Hosting;

/// <summary>Low-cardinality worker and outbox metrics; no user, event, or request identifiers.</summary>
public static class WorkerTelemetry
{
    private static readonly Meter Meter = new("CocEnglish.Workers", "1.0.0");
    private static readonly Counter<long> Ticks = Meter.CreateCounter<long>("cocenglish.worker.ticks", "{tick}");
    private static readonly Histogram<double> TickDuration = Meter.CreateHistogram<double>("cocenglish.worker.tick.duration", "ms");
    private static readonly Counter<long> OutboxEvents = Meter.CreateCounter<long>("cocenglish.outbox.events", "{event}");
    private static readonly ConcurrentDictionary<string, OutboxBacklogSnapshot> Backlogs = new(StringComparer.Ordinal);

    static WorkerTelemetry()
    {
        Meter.CreateObservableGauge<long>("cocenglish.outbox.backlog", ObserveBacklogs, "{event}");
        Meter.CreateObservableGauge<double>("cocenglish.outbox.oldest_event.age", ObserveOldestEventAges, "ms");
    }

    public static void RecordTick(string service, string worker, string outcome, long startedTimestamp)
    {
        var elapsed = Stopwatch.GetElapsedTime(startedTimestamp).TotalMilliseconds;
        var tags = new TagList
        {
            { "service", service }, { "worker", worker }, { "outcome", outcome }
        };
        Ticks.Add(1, tags);
        TickDuration.Record(elapsed, tags);
    }

    public static void RecordOutbox(string service, int leased, int acked, int retried, int dead)
    {
        Record("leased", leased);
        Record("acked", acked);
        Record("retried", retried);
        Record("dead", dead);

        void Record(string outcome, int count)
        {
            var tags = new TagList { { "service", service }, { "outcome", outcome } };
            OutboxEvents.Add(count, tags);
        }
    }

    public static void RecordOutboxBacklog(string service, long pending, long leased, long dead, double? oldestActiveEventAgeMilliseconds) =>
        Backlogs[service] = new(pending, leased, dead, oldestActiveEventAgeMilliseconds);

    public static void ClearOutboxBacklog(string service) => Backlogs.TryRemove(service, out _);

    private static IEnumerable<Measurement<long>> ObserveBacklogs()
    {
        foreach (var (service, snapshot) in Backlogs)
        {
            yield return Measurement(snapshot.Pending, service, "pending");
            yield return Measurement(snapshot.Leased, service, "leased");
            yield return Measurement(snapshot.Dead, service, "dead");
        }

        static Measurement<long> Measurement(long count, string service, string state) =>
            new(count, new TagList { { "service", service }, { "state", state } });
    }

    private static IEnumerable<Measurement<double>> ObserveOldestEventAges()
    {
        foreach (var (service, snapshot) in Backlogs)
        {
            if (snapshot.OldestActiveEventAgeMilliseconds is not { } age) continue;
            yield return new(age, new TagList { { "service", service } });
        }
    }

    private sealed record OutboxBacklogSnapshot(long Pending, long Leased, long Dead, double? OldestActiveEventAgeMilliseconds);
}
