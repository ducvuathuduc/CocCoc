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
public sealed class AiConversationController(AiConversationService conversations, OwnerStore store, IAiRelayTransport relay, TimeProvider clock) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";

    [HttpPost("/v1/tutor")]
    [ContractOperation("tutorFeedback")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Tutor(CancellationToken ct)
    {
        var input = Body();
        ValidateFields(input, ["requestId", "exerciseId", "lessonVersion", "scenarioId", "learnerText", "level", "locale", "feedbackLocale"], ["requestId", "learnerText", "level", "locale", "feedbackLocale"]);
        var requestId = Uuid(input["requestId"], "body.requestId");
        var exerciseId = NullableId(input["exerciseId"], "body.exerciseId");
        var lessonVersion = NullableId(input["lessonVersion"], "body.lessonVersion");
        var scenarioId = NullableId(input["scenarioId"], "body.scenarioId");
        var learnerText = Text(input["learnerText"], "body.learnerText", 0, 512);
        var level = OneOf(input["level"], "body.level", ["A1", "A2"]);
        _ = OneOf(input["locale"], "body.locale", ["en-US"]);
        _ = OneOf(input["feedbackLocale"], "body.feedbackLocale", ["vi-VN"]);
        var normalized = new JsonObject
        {
            ["requestId"] = requestId,
            ["exerciseId"] = exerciseId,
            ["lessonVersion"] = lessonVersion,
            ["scenarioId"] = scenarioId,
            ["learnerText"] = learnerText,
            ["level"] = level
        };
        var hash = Hash("tutorFeedback", normalized);
        var userId = UserId();
        var result = await conversations.TutorAsync(userId, new(requestId, exerciseId, lessonVersion, scenarioId, learnerText, level), hash, ct);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    [HttpGet("/v1/conversations")]
    [ContractOperation("listConversations")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> List(CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "kind", "scenarioId", "cursor", "limit");
        var kind = query.GetValueOrDefault("kind");
        if (!string.IsNullOrEmpty(kind)) kind = OneOf(JsonValue.Create(kind), "kind", ["ROLEPLAY", "VIDEO_CALL"]);
        var scenarioId = query.GetValueOrDefault("scenarioId");
        if (!string.IsNullOrEmpty(scenarioId)) scenarioId = Identifier(JsonValue.Create(scenarioId), "scenarioId");
        var cursor = query.GetValueOrDefault("cursor");
        if (string.IsNullOrEmpty(cursor)) cursor = null;
        if (cursor is not null) cursor = Text(JsonValue.Create(cursor), "cursor", 1, 256);
        var limit = 20;
        if (query.TryGetValue("limit", out var rawLimit))
        {
            if (!double.TryParse(rawLimit, NumberStyles.Float, CultureInfo.InvariantCulture, out var number) || !double.IsFinite(number) || Math.Truncate(number) != number)
                throw Invalid("limit");
            limit = number is >= int.MinValue and <= int.MaxValue ? (int)number : -1;
            if (limit is < 1 or > 100) throw Invalid("limit");
        }
        return await conversations.ListAsync(UserId(), kind, scenarioId, cursor, limit, ct);
    }

    [HttpPost("/v1/conversations")]
    [ContractOperation("startConversation")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Start(CancellationToken ct)
    {
        var input = Body();
        ValidateFields(input, ["kind", "courseId", "scenarioId", "voiceSessionId"], ["kind", "courseId", "scenarioId", "voiceSessionId"]);
        var kind = OneOf(input["kind"], "body.kind", ["ROLEPLAY", "VIDEO_CALL"]);
        var courseId = Identifier(input["courseId"], "body.courseId");
        var scenarioId = Identifier(input["scenarioId"], "body.scenarioId");
        var voiceSessionId = NullableId(input["voiceSessionId"], "body.voiceSessionId");
        var key = IdempotencyKey();
        var normalized = new JsonObject { ["kind"] = kind, ["courseId"] = courseId, ["scenarioId"] = scenarioId, ["voiceSessionId"] = voiceSessionId };
        var hash = Hash("startConversation", normalized);
        var receipt = await conversations.StartAsync(UserId(), new(kind, courseId, scenarioId, voiceSessionId), key, hash, ct);
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    [HttpPost("/v1/conversations/{conversationId}/complete")]
    [ContractOperation("completeConversation")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Complete(string conversationId, CancellationToken ct)
    {
        var body = Body();
        ValidateFields(body, ["endReason"], ["endReason"]);
        var endReason = OneOf(body["endReason"], "body.endReason", ["COMPLETED", "USER_EXIT"]);
        var id = Identifier(JsonValue.Create(conversationId), "conversationId");
        var key = IdempotencyKey();
        var hash = Hash("completeConversation", new JsonObject { ["endReason"] = endReason }, new JsonObject { ["conversationId"] = id });
        var result = await conversations.CompleteAsync(UserId(), id, endReason, key, hash, ct);
        if (result.Receipt.Status == "created")
            await AiImmediateRelay.DispatchAsync(store, relay, clock, result.EventIds, ct);
        return new ObjectResult(result.Receipt.Body) { StatusCode = result.Receipt.StatusCode };
    }

    private JsonObject Body() => HttpContext.Items[typeof(ParsedRequestBody)] is ParsedRequestBody { Value: JsonObject input } ? input : throw Invalid("body");
    private string UserId() => ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
    private string IdempotencyKey()
    {
        var key = Request.Headers["Idempotency-Key"].ToString();
        return Regex.IsMatch(key, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase) ? key.ToLowerInvariant() : throw Invalid("Idempotency-Key");
    }
    private static void ValidateFields(JsonObject input, string[] allowed, string[] required)
    {
        foreach (var property in input)
            if (!allowed.Contains(property.Key, StringComparer.Ordinal)) throw Invalid("body." + property.Key, "UNKNOWN_FIELD");
        foreach (var field in required)
            if (!input.ContainsKey(field)) throw Invalid("body." + field, "REQUIRED");
    }
    private static string Identifier(JsonNode? value, string field)
    {
        var text = Text(value, field, 1, 36);
        return Regex.IsMatch(text, IdPattern, RegexOptions.CultureInvariant) ? text : throw Invalid(field);
    }
    private static string? NullableId(JsonNode? value, string field) => value is null ? null : Identifier(value, field);
    private static string Uuid(JsonNode? value, string field)
    {
        var text = Text(value, field, 36, 36);
        return Regex.IsMatch(text, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase) ? text.ToLowerInvariant() : throw Invalid(field);
    }
    private static string Text(JsonNode? value, string field, int min, int max)
    {
        if (value is JsonValue scalar && scalar.TryGetValue<string>(out var text) && text.Length >= min && text.Length <= max) return text;
        throw Invalid(field);
    }
    private static string OneOf(JsonNode? value, string field, string[] options)
    {
        var text = Text(value, field, 1, 64);
        return options.Contains(text, StringComparer.Ordinal) ? text : throw Invalid(field);
    }
    private static string Hash(string operation, JsonObject body, JsonObject? parameters = null) => CanonicalWire.BodyHash(new JsonObject
    {
        ["operation"] = operation,
        ["params"] = parameters ?? new JsonObject(),
        ["body"] = body
    });
    private static ServiceException Invalid(string field, string reason = "INVALID") => new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
