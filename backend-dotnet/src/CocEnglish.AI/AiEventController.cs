using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.AI;

[ApiController]
public sealed class AiEventController(OwnerStore store, IRowDriver rows, IAiRelayTransport relay, TimeProvider clock) : ControllerBase
{
    private const string Identifier = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string Uuid = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";

    [HttpPost("/internal/events")]
    [ContractOperation("consumeEvent")]
    [ServiceSenders("progress")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Consume(CancellationToken ct)
    {
        var body = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject;
        var fields = new[] { "eventId", "type", "schemaVersion", "producer", "aggregateId", "occurredAt", "requestId", "payload" };
        var eventId = Text(body, "eventId");
        var type = Text(body, "type");
        var producer = Text(body, "producer");
        var aggregateId = Text(body, "aggregateId");
        var occurredAt = Text(body, "occurredAt");
        var requestId = Text(body, "requestId");
        if (body is null || body.Count != fields.Length || body.Any(property => !fields.Contains(property.Key, StringComparer.Ordinal)) ||
            !Match(eventId, Uuid) || type is null || Number(body["schemaVersion"]) != 1 || producer is null ||
            !Match(aggregateId, Identifier) ||
            !DateTimeOffset.TryParse(occurredAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _) ||
            requestId is null || requestId.Length > 64 || body["payload"] is not JsonObject)
            throw RequestQuery.Bad("event");
        if (producer != "progress" || (string)HttpContext.Items["ServiceSender"]! != "progress") throw new ServiceException("FORBIDDEN");
        if (type is not ("entitlement.changed.v1" or "account.deleted.v1")) throw RequestQuery.Bad("type");

        var payload = body["payload"]!.AsObject();
        var userId = Text(payload, "userId");
        if (!Match(userId, Identifier)) throw Invalid("USER_ID");
        if (userId != aggregateId) throw Invalid("AGGREGATE_MISMATCH");
        var hash = CanonicalWire.BodyHash(body);
        var service = new AiEventService(store, rows);
        string status;
        if (type == "entitlement.changed.v1")
        {
            Exact(payload, ["userId", "plan", "status", "expiresAt", "entitlementRevision"]);
            var plan = Text(payload, "plan");
            var entitlementStatus = Text(payload, "status");
            if (plan is not ("FREE" or "SUPER" or "MAX")) throw Invalid("PLAN");
            if (entitlementStatus is not ("ACTIVE" or "GRACE" or "HOLD" or "CANCELED" or "EXPIRED" or "REVOKED")) throw Invalid("STATUS");
            string? expiry = null;
            if (payload["expiresAt"] is not null)
            {
                var expiryText = Text(payload, "expiresAt");
                if (!DateTimeOffset.TryParse(expiryText, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsed)) throw Invalid("EXPIRES_AT");
                expiry = OwnerSchema.Iso(parsed);
            }
            var revision = Number(payload["entitlementRevision"]);
            if (revision is null || revision < 0 || revision > int.MaxValue) throw Invalid("REVISION");
            status = await service.ApplyEntitlementAsync(eventId!, hash, userId!, plan, entitlementStatus, expiry, revision.Value, ct);
        }
        else
        {
            Exact(payload, ["userId", "requestId"]);
            var deletionRequestId = Text(payload, "requestId");
            if (!Match(deletionRequestId, Uuid)) throw Invalid("REQUEST_ID");
            var result = await service.ApplyDeletionAsync(eventId!, hash, userId!, deletionRequestId!, ct);
            status = result.Status;
            if (status == "accepted" && result.AcknowledgementEventId is { } acknowledgementEventId)
                await AiImmediateRelay.DispatchAsync(store, relay, clock, [acknowledgementEventId], ct);
        }
        return new JsonObject { ["operationId"] = eventId, ["status"] = status, ["requestId"] = Response.Headers["X-Request-ID"].ToString() };
    }

    private static string? Text(JsonObject? value, string key) => value?[key]?.GetValueKind() == JsonValueKind.String ? value[key]!.GetValue<string>() : null;
    private static bool Match(string? value, string pattern) => value is not null && Regex.IsMatch(value, pattern, RegexOptions.CultureInvariant);
    private static long? Number(JsonNode? node)
    {
        if (node?.GetValueKind() != JsonValueKind.Number) return null;
        var number = node.GetValue<double>();
        return double.IsFinite(number) && number == Math.Truncate(number) && number >= 0 && number <= int.MaxValue ? (long)number : null;
    }
    private static void Exact(JsonObject payload, string[] fields)
    {
        if (payload.Count != fields.Length || payload.Any(property => !fields.Contains(property.Key, StringComparer.Ordinal))) throw Invalid("PAYLOAD_FIELDS");
    }
    private static ServiceException Invalid(string reason) => new("VALIDATION_ERROR", new() { ["reason"] = reason });
}
