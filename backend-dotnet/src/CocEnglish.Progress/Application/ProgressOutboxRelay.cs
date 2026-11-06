using CocEnglish.Shared.Persistence;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Security;
using System.Globalization;

namespace CocEnglish.Progress.Application;

public enum RelayOutcome { Ack, Retry, Dead }
public sealed record RelayReport(int Leased, int Acked, int Retried, int Dead);
public sealed record RelayOptions(string? Owner = null, int Limit = 20, IReadOnlyList<string>? RowIds = null, TimeSpan? Deadline = null, Func<double>? Random = null);
public interface IRelayJitterSource { double NextDouble(); }
public sealed class SystemRelayJitterSource : IRelayJitterSource { public double NextDouble() => Random.Shared.NextDouble(); }
public sealed class ProgressOutboxRelay(OwnerStore store, TimeProvider clock)
{
    public async Task<RelayReport> RunAsync(Func<string, JsonObject, CancellationToken, Task<RelayOutcome>> deliver, RelayOptions options, CancellationToken ct)
    {
        var owner = options.Owner ?? "relay-" + Guid.NewGuid().ToString("N"); owner = owner[..Math.Min(64, owner.Length)];
        var random = options.Random ?? Random.Shared.NextDouble; var limit = Math.Min(options.Limit, 20);
        var candidates = await store.TransactAsync(async (tx, token) => {
            if (options.RowIds is not null)
            {
                var selected = new List<string>();
                foreach (var id in options.RowIds) if (await tx.GetAsync("p_outbox", id, token) is not null) selected.Add(id);
                return selected;
            }
            var pending = await tx.ListAsync("p_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "PENDING" },
                LessThan: new Dictionary<string, object?> { ["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(1)) }, OrderBy: [new("nextAttemptAt")], Limit: limit), token);
            var expired = await tx.ListAsync("p_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "LEASED" },
                LessThan: new Dictionary<string, object?> { ["leaseUntil"] = tx.NowIso }, OrderBy: [new("leaseUntil")], Limit: limit), token);
            return pending.Concat(expired).Take(limit).Select(r => r.Id).ToList();
        }, ct);
        if (candidates.Count == 0) return new(0, 0, 0, 0);
        var leased = await store.TransactAsync(async (tx, token) => {
            var rows = new List<(string Id, JsonObject Row)>();
            foreach (var id in candidates)
            {
                var row = await tx.GetAsync("p_outbox", id, token);
                if (row is null) continue;
                var due = row.Text("status") == "PENDING" && Date(row.Text("nextAttemptAt")) is { } next && next <= tx.Now ||
                    row.Text("status") == "LEASED" && Date(row.Text("leaseUntil")) is { } until && until < tx.Now;
                if (!due) continue;
                row["status"] = "LEASED"; row["leaseOwner"] = owner; row["leaseUntil"] = OwnerSchema.Iso(tx.Now.AddSeconds(30));
                tx.Put("p_outbox", id, row); rows.Add((id, row));
            }
            return rows;
        }, ct);
        var started = clock.GetUtcNow(); var acked = 0; var retried = 0; var dead = 0;
        foreach (var (id, row) in leased)
        {
            ct.ThrowIfCancellationRequested();
            if (options.Deadline is { } deadline && clock.GetUtcNow() - started > deadline) break;
            RelayOutcome outcome;
            try
            {
                var envelope = Envelope(row);
                var targets = row.Text("type") switch {
                    "account.deleted.v1" or "entitlement.changed.v1" => new[] { "learning", "ai" },
                    "energy.granted.v1" => ["learning"], _ => Array.Empty<string>()
                };
                outcome = targets.Length == 0 ? RelayOutcome.Dead : RelayOutcome.Ack;
                foreach (var target in targets)
                {
                    RelayOutcome targetOutcome;
                    try { targetOutcome = await deliver(target, envelope, ct); }
                    catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
                    catch { targetOutcome = RelayOutcome.Retry; }
                    if (targetOutcome == RelayOutcome.Dead) { outcome = RelayOutcome.Dead; break; }
                    if (targetOutcome == RelayOutcome.Retry) outcome = RelayOutcome.Retry;
                }
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { outcome = RelayOutcome.Dead; }
            await store.TransactAsync(async (tx, token) => {
                var current = await tx.GetAsync("p_outbox", id, token);
                if (current is null || current.Text("status") != "LEASED" || current.Text("leaseOwner") != owner) return 0;
                var attempt = current.Number("attempt") + (outcome == RelayOutcome.Ack ? 0 : 1);
                current["leaseOwner"] = null; current["leaseUntil"] = null;
                if (outcome == RelayOutcome.Ack) { current["status"] = "ACK"; current["ackAt"] = tx.NowIso; }
                else
                {
                    current["attempt"] = attempt;
                    if (outcome == RelayOutcome.Dead || attempt >= 10) current["status"] = "DEAD";
                    else
                    {
                        var delay = Math.Min(Math.Pow(2, attempt) * 1000, 900000);
                        current["status"] = "PENDING"; current["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(Math.Floor(delay / 2 + random() * delay / 2 + .5)));
                    }
                }
                tx.Put("p_outbox", id, current); return 0;
            }, ct);
            if (outcome == RelayOutcome.Ack) acked++; else if (outcome == RelayOutcome.Dead) dead++; else retried++;
        }
        return new(leased.Count, acked, retried, dead);
    }

    private static DateTimeOffset? Date(string? value) => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date) ? date : null;
    internal static JsonObject Envelope(JsonObject row) => new() {
        ["eventId"] = row.Text("eventId"), ["type"] = row.Text("type"), ["schemaVersion"] = 1, ["producer"] = "progress", ["aggregateId"] = row.Text("aggregateId"),
        ["occurredAt"] = Date(row.Text("occurredAt")) is { } occurred ? OwnerSchema.Iso(occurred) : row.Text("occurredAt"),
        ["requestId"] = row.Text("eventId"), ["payload"] = JsonNode.Parse(row.Text("payloadJson")!)
    };
}
