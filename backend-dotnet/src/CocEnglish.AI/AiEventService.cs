using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.AI;

public sealed class AiEventService(OwnerStore store, IRowDriver rows)
{
    public const int PurgeBatch = 80;
    private static readonly string[] UserTables = ["a_conversations", "a_voice_sessions", "a_active_slots", "a_jobs", "a_usage", "a_receipts"];
    private static readonly HashSet<string> Plans = ["FREE", "SUPER", "MAX"];
    private static readonly HashSet<string> EntitlementStatuses = ["ACTIVE", "GRACE", "HOLD", "CANCELED", "EXPIRED", "REVOKED"];

    public Task<string> ApplyEntitlementAsync(string eventId, string bodyHash, string userId, string plan, string status,
        string? expiresAt, long entitlementRevision, CancellationToken ct) =>
        store.ApplyInboxAsync(eventId, "entitlement.changed.v1", bodyHash, async (tx, token) =>
        {
            var rowId = CanonicalWire.RowId("entitlement", userId);
            var current = await tx.GetAsync("a_usage", rowId, token);
            var knownRevision = ProjectionRevision(current?.Text("reservationIdsJson"));
            if (knownRevision is not null && knownRevision.Value >= entitlementRevision) return;
            var projection = new JsonObject
            {
                ["plan"] = plan,
                ["status"] = status,
                ["expiresAt"] = expiresAt,
                ["entitlementRevision"] = entitlementRevision
            };
            tx.Put("a_usage", rowId, new JsonObject
            {
                ["userId"] = userId,
                ["utcDay"] = "ENTITLED",
                ["liveReservedSeconds"] = 0,
                ["liveUsedSeconds"] = 0,
                ["liveGrants"] = 0,
                ["textRequests"] = 0,
                ["recordedSpeechSeconds"] = 0,
                ["recordedReservedSeconds"] = 0,
                ["reservationIdsJson"] = CanonicalWire.Stringify(projection)
            });
        }, ct);

    public async Task<(string Status, string? AcknowledgementEventId)> ApplyDeletionAsync(
        string eventId, string bodyHash, string userId, string requestId, CancellationToken ct)
    {
        var inboxId = CanonicalWire.RowId("inbox", eventId);
        var existing = (await rows.ReadAsync("a_inbox", inboxId, ct))?.Data;
        if (existing is not null)
        {
            if (existing.Text("bodyHash") != bodyHash)
                throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["eventId"] = eventId });
            return ("replayed", null);
        }

        var ackId = DeterministicUuid($"account.purged.v1|ai|{eventId}");
        for (var guard = 0; guard < 1000; guard++)
        {
            ct.ThrowIfCancellationRequested();
            var owned = await OwnedRowsAsync(userId, PurgeBatch, ct);
            if (owned.Count >= PurgeBatch)
            {
                await store.TransactAsync(async (tx, token) =>
                {
                    await DeleteOwnedAsync(tx, owned, userId, token);
                    return 0;
                }, ct);
                continue;
            }

            var status = await store.ApplyInboxAsync(eventId, "account.deleted.v1", bodyHash, async (tx, token) =>
            {
                await DeleteOwnedAsync(tx, owned, userId, token);
                if (await tx.GetAsync("a_outbox", ackId, token) is not null)
                    throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "PURGE_ACK_ALREADY_EXISTS" });
                var envelope = new JsonObject
                {
                    ["eventId"] = ackId,
                    ["type"] = "account.purged.v1",
                    ["schemaVersion"] = 1,
                    ["producer"] = "ai",
                    ["aggregateId"] = userId,
                    ["occurredAt"] = tx.NowIso,
                    ["requestId"] = requestId,
                    ["payload"] = new JsonObject { ["userId"] = userId, ["requestId"] = requestId, ["owner"] = "ai" }
                };
                tx.Put("a_outbox", ackId, new JsonObject
                {
                    ["eventId"] = ackId,
                    ["type"] = "account.purged.v1",
                    ["schemaVersion"] = 1,
                    ["aggregateId"] = userId,
                    ["occurredAt"] = tx.NowIso,
                    ["payloadJson"] = CanonicalWire.Stringify(envelope),
                    ["attempt"] = 0,
                    ["nextAttemptAt"] = tx.NowIso,
                    ["leaseOwner"] = null,
                    ["leaseUntil"] = null,
                    ["status"] = "PENDING",
                    ["ackAt"] = null
                });
            }, ct);
            return (status, status == "accepted" ? ackId : null);
        }

        throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "PURGE_DID_NOT_CONVERGE" });
    }

    private async Task<IReadOnlyList<(string Table, string Id)>> OwnedRowsAsync(string userId, int limit, CancellationToken ct)
    {
        var found = new List<(string Table, string Id)>(limit);
        foreach (var table in UserTables)
        {
            if (found.Count >= limit) break;
            var page = await rows.ListAsync(table, new(Where: new Dictionary<string, object?> { ["userId"] = userId }, Limit: limit - found.Count), ct);
            found.AddRange(page.Select(item => (table, item.Id)));
        }
        if (found.Count < limit)
        {
            var outbox = await rows.ListAsync("a_outbox", new(Where: new Dictionary<string, object?>
            {
                ["aggregateId"] = userId,
                ["type"] = "ai.practice.completed.v1"
            }, Limit: limit - found.Count), ct);
            found.AddRange(outbox.Select(item => ("a_outbox", item.Id)));
        }
        return found;
    }

    private static async Task DeleteOwnedAsync(OwnerSession tx, IReadOnlyList<(string Table, string Id)> owned, string userId, CancellationToken ct)
    {
        foreach (var (table, id) in owned)
        {
            var row = await tx.GetAsync(table, id, ct);
            var belongs = table == "a_outbox"
                ? row?.Text("aggregateId") == userId && row.Text("type") == "ai.practice.completed.v1"
                : row?.Text("userId") == userId;
            if (belongs) tx.Delete(table, id);
        }
    }

    private static long? ProjectionRevision(string? json)
    {
        if (string.IsNullOrEmpty(json)) return null;
        try
        {
            var projection = JsonNode.Parse(json) as JsonObject;
            if (projection is null || !Plans.Contains(projection.Text("plan") ?? "") || !EntitlementStatuses.Contains(projection.Text("status") ?? "") ||
                projection["entitlementRevision"]?.GetValueKind() != System.Text.Json.JsonValueKind.Number ||
                !projection["entitlementRevision"]!.AsValue().TryGetValue<double>(out var revision) || !double.IsFinite(revision) ||
                revision != Math.Truncate(revision) || revision < 0 || revision > int.MaxValue) return null;
            return (long)revision;
        }
        catch (JsonException) { return null; }
    }

    private static string DeterministicUuid(string seed)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(seed));
        bytes[6] = (byte)((bytes[6] & 0x0f) | 0x50);
        bytes[8] = (byte)((bytes[8] & 0x3f) | 0x80);
        var hex = Convert.ToHexString(bytes.AsSpan(0, 16)).ToLowerInvariant();
        return $"{hex[..8]}-{hex[8..12]}-{hex[12..16]}-{hex[16..20]}-{hex[20..32]}";
    }
}
