using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.AI;

public enum AiRelayOutcome { Ack, Retry, Dead }
public sealed record AiDispatchReport(int Leased, int Acked, int Retried, int Dead);
public sealed record AiDispatchOptions(string? Owner = null, int Limit = 20, IReadOnlyList<string>? EventIds = null,
    TimeSpan? Deadline = null, Func<double>? Random = null);

public interface IAiRelayTransport
{
    bool Configured { get; }
    Task<AiRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct);
}

/// <summary>Durably leases AI events and delivers them to Progress at least once.</summary>
public sealed class AiOutboxDispatcher(OwnerStore store, TimeProvider clock)
{
    private const int BatchLimit = 20;
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromSeconds(30);

    public async Task<AiDispatchReport> RunAsync(Func<JsonObject, CancellationToken, Task<AiRelayOutcome>> deliver,
        AiDispatchOptions options, CancellationToken ct)
    {
        var owner = options.Owner ?? "ai-relay-" + Guid.NewGuid().ToString("N");
        owner = owner[..Math.Min(owner.Length, 64)];
        var limit = Math.Clamp(options.Limit, 1, BatchLimit);
        var candidates = await store.TransactAsync(async (tx, token) =>
        {
            if (options.EventIds is not null)
            {
                var selected = new List<string>();
                foreach (var id in options.EventIds)
                    if (await tx.GetAsync("a_outbox", id, token) is not null) selected.Add(id);
                return selected;
            }

            var pending = await tx.ListAsync("a_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "PENDING" },
                LessThan: new Dictionary<string, object?> { ["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(1)) },
                OrderBy: [new("nextAttemptAt")], Limit: limit), token);
            var expired = await tx.ListAsync("a_outbox", new(Where: new Dictionary<string, object?> { ["status"] = "LEASED" },
                LessThan: new Dictionary<string, object?> { ["leaseUntil"] = tx.NowIso },
                OrderBy: [new("leaseUntil")], Limit: limit), token);
            return pending.Concat(expired).Take(limit).Select(row => row.Id).ToList();
        }, ct);
        if (candidates.Count == 0) return new(0, 0, 0, 0);

        var leased = await store.TransactAsync(async (tx, token) =>
        {
            var rows = new List<(string Id, JsonObject Data)>();
            foreach (var id in candidates)
            {
                var row = await tx.GetAsync("a_outbox", id, token);
                if (row is null) continue;
                var due = row.Text("status") == "PENDING" && Date(row.Text("nextAttemptAt")) is { } next && next <= tx.Now ||
                          row.Text("status") == "LEASED" && Date(row.Text("leaseUntil")) is { } until && until < tx.Now;
                if (!due) continue;
                row["status"] = "LEASED";
                row["leaseOwner"] = owner;
                row["leaseUntil"] = OwnerSchema.Iso(tx.Now.Add(LeaseDuration));
                tx.Put("a_outbox", id, row);
                rows.Add((id, row));
            }
            return rows;
        }, ct);

        var started = clock.GetUtcNow();
        var acked = 0;
        var retried = 0;
        var dead = 0;
        var random = options.Random ?? Random.Shared.NextDouble;
        foreach (var (id, row) in leased)
        {
            ct.ThrowIfCancellationRequested();
            if (options.Deadline is { } deadline && clock.GetUtcNow() - started > deadline) break;
            AiRelayOutcome outcome;
            try
            {
                var envelope = JsonNode.Parse(row.Text("payloadJson")!) as JsonObject ?? throw new FormatException("OUTBOX_ENVELOPE_INVALID");
                outcome = await deliver(envelope, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch { outcome = AiRelayOutcome.Retry; }

            await SettleAsync(id, owner, outcome, random, ct);
            if (outcome == AiRelayOutcome.Ack) acked++;
            else if (outcome == AiRelayOutcome.Dead) dead++;
            else retried++;
        }
        return new(leased.Count, acked, retried, dead);
    }

    private Task SettleAsync(string id, string owner, AiRelayOutcome outcome, Func<double> random, CancellationToken ct) =>
        store.TransactAsync(async (tx, token) =>
        {
            var current = await tx.GetAsync("a_outbox", id, token);
            if (current is null || current.Text("status") != "LEASED" || current.Text("leaseOwner") != owner) return 0;
            var attempt = current.Number("attempt") + (outcome == AiRelayOutcome.Ack ? 0 : 1);
            current["leaseOwner"] = null;
            current["leaseUntil"] = null;
            if (outcome == AiRelayOutcome.Ack)
            {
                current["status"] = "ACK";
                current["ackAt"] = tx.NowIso;
            }
            else
            {
                current["attempt"] = attempt;
                if (outcome == AiRelayOutcome.Dead || attempt >= 10) current["status"] = "DEAD";
                else
                {
                    var delay = Math.Min(Math.Pow(2, attempt) * 1000, 900_000);
                    var jittered = Math.Floor(delay / 2 + random() * delay / 2 + 0.5);
                    current["status"] = "PENDING";
                    current["nextAttemptAt"] = OwnerSchema.Iso(tx.Now.AddMilliseconds(jittered));
                }
            }
            tx.Put("a_outbox", id, current);
            return 0;
        }, ct);

    private static DateTimeOffset? Date(string? value) => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture,
        DateTimeStyles.AssumeUniversal, out var date) ? date : null;
}

/// <summary>Signs AI event deliveries with the existing service HMAC wire contract.</summary>
public sealed class HttpAiRelay(HttpClient client, Uri? progressUrl, ServiceKey? key, TimeProvider clock) : IAiRelayTransport
{
    public bool Configured => progressUrl is { IsAbsoluteUri: true, Scheme: "https" } && progressUrl.UserInfo.Length == 0 &&
        progressUrl.Query.Length == 0 && progressUrl.Fragment.Length == 0 && key is { Sender: "ai", Secret.Length: >= 32 };

    public async Task<AiRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct)
    {
        if (!Configured) return AiRelayOutcome.Retry;
        const string path = "/internal/events";
        var body = CanonicalWire.Stringify(envelope);
        var signature = ServiceHmac.Sign(key!, "POST", path, "", new HashSet<string>(), body, clock.GetUtcNow().ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, progressUrl!.AbsoluteUri.TrimEnd('/') + path)
        { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        request.Headers.Add("X-Request-ID", Guid.NewGuid().ToString());
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            var text = await response.Content.ReadAsStringAsync(timeout.Token);
            JsonObject? bodyJson = null;
            if (text.Length > 0) bodyJson = JsonNode.Parse(text) as JsonObject;
            return OutcomeForStatus((int)response.StatusCode, bodyJson);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { return AiRelayOutcome.Retry; }
        catch (HttpRequestException) { return AiRelayOutcome.Retry; }
        catch (JsonException) { return AiRelayOutcome.Retry; }
    }

    public static AiRelayOutcome OutcomeForStatus(int status, JsonObject? body)
    {
        var error = body?["error"] as JsonObject;
        var code = error?.Text("code");
        var field = (error?["details"] as JsonObject)?.Text("field");
        if (status == (int)HttpStatusCode.OK) return AiRelayOutcome.Ack;
        if (status == (int)HttpStatusCode.Conflict && code == "IDEMPOTENCY_CONFLICT") return AiRelayOutcome.Dead;
        if (status == (int)HttpStatusCode.BadRequest && field == "type") return AiRelayOutcome.Retry;
        if (status is 400 or 403) return AiRelayOutcome.Dead;
        return AiRelayOutcome.Retry;
    }
}

/// <summary>Best-effort, bounded dispatch after commit; durable leases remain the retry path.</summary>
public static class AiImmediateRelay
{
    public static async Task DispatchAsync(OwnerStore store, IAiRelayTransport relay, TimeProvider clock,
        IReadOnlyList<string> eventIds, CancellationToken ct, TimeSpan? deadline = null, Func<double>? random = null)
    {
        if (!relay.Configured || eventIds.Count == 0) return;
        var bounded = deadline ?? TimeSpan.FromMilliseconds(1500);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(bounded);
        try
        {
            await new AiOutboxDispatcher(store, clock).RunAsync(relay.DeliverAsync,
                new(Owner: "immediate-" + eventIds[0][..Math.Min(8, eventIds[0].Length)], EventIds: eventIds,
                    Deadline: bounded, Random: random), timeout.Token);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { /* The durable worker retries events that remain pending. */ }
    }
}
