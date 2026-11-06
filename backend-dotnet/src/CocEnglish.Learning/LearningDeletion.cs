using System.Diagnostics;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

public sealed class LearningDeletion(IRowDriver rows, OwnerStore store)
{
    public sealed record Result(string Status, string? AcknowledgementEventId);
    private static readonly string[] UserTables = ["l_answers", "l_sessions", "l_active_slots", "l_review_items", "l_mistakes", "l_activity_progress", "l_reports", "l_receipts", "l_enrollments"];

    public async Task<Result> ApplyAsync(string eventId, string hash, string user, string requestId, CancellationToken ct)
    {
        var existing = (await rows.ReadAsync("l_inbox", eventId, ct))?.Data;
        if (existing is not null)
        {
            if (existing.Text("bodyHash") != hash || existing.Text("type") != "account.deleted.v1") throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["eventId"] = eventId });
            return new("replayed", null);
        }
        var elapsed = Stopwatch.StartNew();
        foreach (var table in UserTables)
        {
            while (true)
            {
                ct.ThrowIfCancellationRequested();
                if (elapsed.Elapsed > TimeSpan.FromSeconds(20)) throw new ServiceException("DEADLINE_EXCEEDED", new() { ["reason"] = "PURGE_IN_PROGRESS" });
                var page = await rows.ListAsync(table, new(Where: new Dictionary<string, object?> { ["userId"] = user }, Limit: 80), ct);
                if (page.Count == 0) break;
                await store.TransactAsync(async (tx, token) => {
                    foreach (var item in page)
                    {
                        var row = await tx.GetAsync(table, item.Id, token);
                        if (row?.Text("userId") == user) tx.Delete(table, item.Id);
                    }
                    return 0;
                }, ct);
            }
        }
        string? acknowledgementEventId = null;
        var status = await store.ApplyInboxAsync(eventId, "account.deleted.v1", hash, async (tx, token) => {
            var energyId = CanonicalWire.RowId("energy", user);
            if (await tx.GetAsync("l_energy", energyId, token) is not null) tx.Delete("l_energy", energyId);
            var ackId = Guid.NewGuid().ToString();
            acknowledgementEventId = ackId;
            var ack = new JsonObject { ["eventId"] = ackId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1, ["producer"] = "learning",
                ["aggregateId"] = user, ["occurredAt"] = tx.NowIso, ["requestId"] = requestId,
                ["payload"] = new JsonObject { ["userId"] = user, ["requestId"] = requestId, ["owner"] = "learning" } };
            await tx.GetAsync("l_outbox", ackId, token);
            tx.Put("l_outbox", ackId, new JsonObject { ["eventId"] = ackId, ["type"] = "account.purged.v1", ["schemaVersion"] = 1,
                ["aggregateId"] = user, ["occurredAt"] = tx.NowIso, ["payloadJson"] = CanonicalWire.Stringify(ack), ["attempt"] = 0,
                ["nextAttemptAt"] = tx.NowIso, ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null });
        }, ct);
        return new(status, status == "accepted" ? acknowledgementEventId : null);
    }
}
