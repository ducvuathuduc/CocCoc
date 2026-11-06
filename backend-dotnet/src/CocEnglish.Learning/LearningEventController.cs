using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningEventController(OwnerStore store, IRowDriver rows, ILearningRelayTransport relay, TimeProvider clock) : ControllerBase
{
    private const string Identifier = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string Uuid = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";

    /// <summary>Apply authenticated Progress events once using the Learning inbox.</summary>
    [HttpPost("/internal/events")]
    [ContractOperation("consumeEvent")]
    [ServiceSenders("progress")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Consume(CancellationToken ct)
    {
        var body = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject;
        var fields = new[] { "eventId", "type", "schemaVersion", "producer", "aggregateId", "occurredAt", "requestId", "payload" };
        if (body is null || body.Count != fields.Length || body.Any(p => !fields.Contains(p.Key, StringComparer.Ordinal)) ||
            !Match(Text(body, "eventId"), Uuid) || Text(body, "type") is null || Number(body["schemaVersion"]) != 1 ||
            Text(body, "producer") is null || !Match(Text(body, "aggregateId"), Identifier) ||
            !DateTimeOffset.TryParse(Text(body, "occurredAt"), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _) ||
            Text(body, "requestId") is not { Length: <= 64 } || body["payload"] is not JsonObject)
            throw RequestQuery.Bad("event");
        var type = Text(body, "type")!;
        if (type is not ("energy.granted.v1" or "entitlement.changed.v1" or "account.deleted.v1")) throw RequestQuery.Bad("type");
        if (Text(body, "producer") != "progress" || (string)HttpContext.Items["ServiceSender"]! != "progress") throw new ServiceException("FORBIDDEN");
        var payload = body["payload"]!.AsObject();
        if (type == "account.deleted.v1")
        {
            if (payload.Count != 2 || !payload.ContainsKey("userId") || !payload.ContainsKey("requestId")) throw Invalid("PAYLOAD_FIELDS");
            var deletionUser = Text(payload, "userId"); var requestId = Text(payload, "requestId");
            if (!Match(deletionUser, Identifier)) throw Invalid("userId");
            if (deletionUser != Text(body, "aggregateId")) throw Invalid("aggregateId");
            if (!Match(requestId, Uuid)) throw Invalid("requestId");
            var deletion = await new LearningDeletion(rows, store).ApplyAsync(Text(body, "eventId")!, CanonicalWire.BodyHash(body), deletionUser!, requestId!, ct);
            if (deletion.Status == "accepted" && deletion.AcknowledgementEventId is { } ackId)
            {
                try
                {
                    await LearningImmediateRelay.DispatchAsync(store, relay, clock, [ackId], "event-" + ackId[..8], ct);
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
                catch { /* The durable outbox dispatcher remains the retry path. */ }
            }
            return new JsonObject { ["operationId"] = Text(body, "eventId"), ["status"] = deletion.Status, ["requestId"] = Response.Headers["X-Request-ID"].ToString() };
        }
        var expected = type == "energy.granted.v1" ? new[] { "operationId", "userId", "amount", "refillToCapacity", "reason" } : new[] { "userId", "plan", "status", "expiresAt", "entitlementRevision" };
        if (payload.Count != expected.Length || payload.Any(p => !expected.Contains(p.Key, StringComparer.Ordinal))) throw Invalid("PAYLOAD_FIELDS");
        var user = Text(payload, "userId");
        if (!Match(user, Identifier)) throw Invalid("userId");
        if (user != Text(body, "aggregateId")) throw Invalid("aggregateId");
        Func<OwnerSession, CancellationToken, Task> effect;
        if (type == "energy.granted.v1")
        {
            if (!Match(Text(payload, "operationId"), Identifier)) throw Invalid("operationId");
            var amount = payload["amount"] is null ? null : Number(payload["amount"]);
            if (payload["amount"] is not null && (amount is null || amount is < 1 or > 100)) throw Invalid("amount");
            if (payload["refillToCapacity"]?.GetValueKind() is not (JsonValueKind.True or JsonValueKind.False) || payload["refillToCapacity"]!.GetValue<bool>() != (amount is null)) throw Invalid("refillToCapacity");
            if (Text(payload, "reason") is not ("SHOP" or "CHEST" or "FRIEND" or "QUEST" or "AD" or "PROMO")) throw Invalid("reason");
            effect = (tx, token) => LearningEnergy.GrantAsync(tx, user!, amount, amount is null, token);
        }
        else
        {
            var plan = Text(payload, "plan"); var status = Text(payload, "status"); var expires = Text(payload, "expiresAt"); var revision = Number(payload["entitlementRevision"]);
            if (plan is not ("FREE" or "SUPER" or "MAX")) throw Invalid("plan");
            if (status is not ("ACTIVE" or "GRACE" or "HOLD" or "CANCELED" or "EXPIRED" or "REVOKED")) throw Invalid("status");
            if (payload["expiresAt"] is not null && (expires is null || !DateTimeOffset.TryParse(expires, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _))) throw Invalid("expiresAt");
            if (revision is null or < 0 or > int.MaxValue) throw Invalid("entitlementRevision");
            effect = (tx, token) => LearningEnergy.EntitlementAsync(tx, user!, plan, status, expires, revision.Value, token);
        }
        var eventId = Text(body, "eventId")!;
        var result = await store.ApplyInboxAsync(eventId, type, CanonicalWire.BodyHash(body), effect, ct);
        return new JsonObject { ["operationId"] = eventId, ["status"] = result, ["requestId"] = Response.Headers["X-Request-ID"].ToString() };
    }

    private static string? Text(JsonObject obj, string key) => obj[key]?.GetValueKind() == JsonValueKind.String ? obj[key]!.GetValue<string>() : null;
    private static bool Match(string? value, string pattern) => value is not null && Regex.IsMatch(value, pattern, RegexOptions.CultureInvariant);
    private static long? Number(JsonNode? node)
    {
        if (node?.GetValueKind() != JsonValueKind.Number) return null;
        var n = node.GetValue<double>(); return double.IsFinite(n) && n == Math.Truncate(n) && n >= 0 && n <= int.MaxValue ? (long)n : null;
    }
    private static ServiceException Invalid(string reason) => new("VALIDATION_ERROR", new() { ["reason"] = reason });
}
