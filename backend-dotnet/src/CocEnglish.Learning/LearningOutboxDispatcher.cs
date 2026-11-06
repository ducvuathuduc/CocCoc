using System.Globalization;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;

namespace CocEnglish.Learning;

public enum LearningRelayOutcome { Ack, Retry, Dead }
public sealed record LearningDispatchReport(int Leased, int Acked, int Retried, int Dead);
public sealed record LearningDispatchOptions(string? Owner = null, int Limit = 20, IReadOnlyList<string>? EventIds = null,
    TimeSpan? Deadline = null, Func<double>? Random = null);

public interface ILearningRelayTransport
{
    bool Configured { get; }
    Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct);
}

/// <summary>Leases and delivers durable Learning events to Progress at least once.</summary>
public sealed class LearningOutboxDispatcher(OwnerStore store, TimeProvider clock)
{
    private const int BatchLimit = 20;
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromSeconds(30);

    public async Task<LearningDispatchReport> RunAsync(Func<JsonObject, CancellationToken, Task<LearningRelayOutcome>> deliver,
        LearningDispatchOptions options, CancellationToken ct)
    {
        var owner = options.Owner ?? "relay-" + Guid.NewGuid().ToString("N"); owner = owner[..Math.Min(64, owner.Length)];
        var limit = Math.Clamp(options.Limit, 1, BatchLimit);
        var candidates = await store.TransactAsync(async (tx, token) => {
            if (options.EventIds is not null)
            {
                var selected = new List<string>();
                foreach (var id in options.EventIds)
                    if (await tx.GetAsync("l_outbox", id, token) is not null) selected.Add(id);
                return selected;
            }
            var pending = await tx.ListAsync("l_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "PENDING" },
                LessThan: new Dictionary<string, object?> { ["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(1)) },
                OrderBy: [new("nextAttemptAt")], Limit: limit), token);
            var expired = await tx.ListAsync("l_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "LEASED" },
                LessThan: new Dictionary<string, object?> { ["leaseUntil"] = tx.NowIso }, OrderBy: [new("leaseUntil")], Limit: limit), token);
            return pending.Concat(expired).Take(limit).Select(row => row.Id).ToList();
        }, ct);
        if (candidates.Count == 0) return new(0, 0, 0, 0);

        var leased = await store.TransactAsync(async (tx, token) => {
            var rows = new List<(string Id, JsonObject Data)>();
            foreach (var id in candidates)
            {
                var row = await tx.GetAsync("l_outbox", id, token);
                if (row is null) continue;
                var due = row.Text("status") == "PENDING" && Date(row.Text("nextAttemptAt")) is { } next && next <= tx.Now ||
                          row.Text("status") == "LEASED" && Date(row.Text("leaseUntil")) is { } until && until < tx.Now;
                if (!due) continue;
                row["status"] = "LEASED"; row["leaseOwner"] = owner; row["leaseUntil"] = OwnerSchema.Iso(tx.Now.Add(LeaseDuration));
                tx.Put("l_outbox", id, row); rows.Add((id, row));
            }
            return rows;
        }, ct);

        var started = clock.GetUtcNow(); var acked = 0; var retried = 0; var dead = 0;
        var random = options.Random ?? Random.Shared.NextDouble;
        foreach (var (id, row) in leased)
        {
            ct.ThrowIfCancellationRequested();
            if (options.Deadline is { } deadline && clock.GetUtcNow() - started > deadline) break;
            LearningRelayOutcome outcome;
            try
            {
                var envelope = JsonNode.Parse(row.Text("payloadJson")!) as JsonObject ?? throw new FormatException("OUTBOX_ENVELOPE_INVALID");
                outcome = await deliver(envelope, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { outcome = LearningRelayOutcome.Retry; }

            await SettleAsync(id, owner, outcome, random, ct);
            if (outcome == LearningRelayOutcome.Ack) acked++;
            else if (outcome == LearningRelayOutcome.Dead) dead++;
            else retried++;
        }
        return new(leased.Count, acked, retried, dead);
    }

    private Task SettleAsync(string id, string owner, LearningRelayOutcome outcome, Func<double> random, CancellationToken ct) =>
        store.TransactAsync(async (tx, token) => {
            var current = await tx.GetAsync("l_outbox", id, token);
            if (current is null || current.Text("status") != "LEASED" || current.Text("leaseOwner") != owner) return 0;
            var attempt = current.Number("attempt") + (outcome == LearningRelayOutcome.Ack ? 0 : 1);
            current["leaseOwner"] = null; current["leaseUntil"] = null;
            if (outcome == LearningRelayOutcome.Ack)
            {
                current["status"] = "ACK"; current["ackAt"] = tx.NowIso;
            }
            else
            {
                current["attempt"] = attempt;
                if (outcome == LearningRelayOutcome.Dead || attempt >= 10) current["status"] = "DEAD";
                else
                {
                    var delay = Math.Min(Math.Pow(2, attempt) * 1000, 900_000);
                    var jittered = Math.Floor(delay / 2 + random() * delay / 2 + 0.5);
                    current["status"] = "PENDING"; current["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(jittered));
                }
            }
            tx.Put("l_outbox", id, current); return 0;
        }, ct);

    private static DateTimeOffset? Date(string? value) => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date) ? date : null;
}

/// <summary>Best-effort delivery of just-committed events; the durable dispatcher remains the retry path.</summary>
public static class LearningImmediateRelay
{
    public static Task<LearningDispatchReport> DispatchAsync(OwnerStore store, ILearningRelayTransport relay,
        TimeProvider clock, IReadOnlyList<string> eventIds, string owner, CancellationToken ct,
        TimeSpan? deadline = null, Func<double>? random = null)
    {
        if (!relay.Configured || eventIds.Count == 0)
            return Task.FromResult(new LearningDispatchReport(0, 0, 0, 0));
        return new LearningOutboxDispatcher(store, clock).RunAsync(relay.DeliverAsync,
            new(Owner: owner, EventIds: eventIds, Deadline: deadline ?? TimeSpan.FromMilliseconds(1500), Random: random), ct);
    }
}
