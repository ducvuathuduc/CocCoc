using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningSessionController(OwnerStore store, IRowDriver rows, ILearningContentReader content, ILearningRelayTransport relay, TimeProvider clock, IConfiguration config) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
    private static readonly string[] Modes = ["LESSON", "REVIEW", "MASTERY", "PLACEMENT", "STORIES", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH", "UNIT_REVIEW", "TEST_OUT", "CHECKPOINT"];

    /// <summary>Start a version-pinned lesson session and return its owner-only resume snapshot.</summary>
    [HttpPost("/v1/sessions")]
    [ContractOperation("startSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Start(CancellationToken ct)
    {
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw Invalid("body");
        var allowed = new[] { "courseId", "lessonId", "mode", "expectedEnrollmentRevision", "activityId", "opponentId" };
        foreach (var field in input.Select(property => property.Key)) if (!allowed.Contains(field, StringComparer.Ordinal)) throw Invalid("body." + field, "UNKNOWN_FIELD");
        var courseId = Id(input["courseId"], "courseId"); var lessonId = Id(input["lessonId"], "lessonId");
        var mode = Text(input["mode"], "mode"); if (!Modes.Contains(mode, StringComparer.Ordinal)) throw Invalid("mode");
        var expectedRevision = Integer(input["expectedEnrollmentRevision"], "expectedEnrollmentRevision", 0, int.MaxValue);
        var activityId = input.ContainsKey("activityId") ? Id(input["activityId"], "activityId") : null;
        var opponentId = input.ContainsKey("opponentId") ? Id(input["opponentId"], "opponentId") : null;
        var key = IdempotencyKey();
        var normalized = new JsonObject { ["courseId"] = courseId, ["lessonId"] = lessonId, ["mode"] = mode, ["expectedEnrollmentRevision"] = expectedRevision };
        if (activityId is not null) normalized["activityId"] = activityId;
        if (opponentId is not null) normalized["opponentId"] = opponentId;
        var hash = CanonicalWire.BodyHash(new JsonObject { ["operation"] = "startSession", ["params"] = new JsonObject(), ["body"] = normalized });
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var receipt = await new LearningSessions(store, rows, content, clock, config).StartAsync(user, courseId, lessonId, mode,
            expectedRevision, key, hash, activityId, opponentId, ct);
        if (receipt.Body is JsonObject reference && reference["sessionRef"] is JsonValue sessionRef && sessionRef.TryGetValue<string>(out var sessionId))
            return new ObjectResult(await new LearningSessions(store, rows, content, clock, config).GetViewAsync(user, sessionId, ct)) { StatusCode = receipt.StatusCode };
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    /// <summary>Return an owner-only resume snapshot for an existing session.</summary>
    [HttpGet("/v1/sessions/{sessionId}")]
    [ContractOperation("getSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Get(string sessionId, CancellationToken ct)
    {
        _ = RequestQuery.Parse(Request);
        if (!Regex.IsMatch(sessionId, IdPattern, RegexOptions.CultureInvariant)) throw Invalid("sessionId");
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        return await new LearningSessions(store, rows, content, clock, config).GetViewAsync(user, sessionId, ct);
    }

    /// <summary>Grade the next queued exercise against its signed, server-owned bundle.</summary>
    [HttpPost("/v1/sessions/{sessionId}/answers")]
    [ContractOperation("submitAnswer")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Answer(string sessionId, CancellationToken ct)
    {
        if (!Regex.IsMatch(sessionId, IdPattern, RegexOptions.CultureInvariant)) throw Invalid("sessionId");
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw Invalid("body");
        var fields = new[] { "exerciseId", "attemptOrdinal", "answer", "assisted", "substituted", "expectedRevision" };
        foreach (var field in input.Select(property => property.Key)) if (!fields.Contains(field, StringComparer.Ordinal)) throw Invalid("body." + field, "UNKNOWN_FIELD");
        foreach (var field in fields) if (!input.ContainsKey(field)) throw Invalid("body." + field, "REQUIRED");
        var exerciseId = Id(input["exerciseId"], "exerciseId");
        var attemptOrdinal = Integer(input["attemptOrdinal"], "attemptOrdinal", 0, 2);
        var answer = ParseAnswer(input["answer"]);
        var assisted = Boolean(input["assisted"], "assisted"); var substituted = Boolean(input["substituted"], "substituted");
        var expectedRevision = Integer(input["expectedRevision"], "expectedRevision", 0, int.MaxValue);
        var key = IdempotencyKey();
        var normalized = new JsonObject { ["exerciseId"] = exerciseId, ["attemptOrdinal"] = attemptOrdinal, ["answer"] = answer.DeepClone(),
            ["assisted"] = assisted, ["substituted"] = substituted, ["expectedRevision"] = expectedRevision };
        var hash = CanonicalWire.BodyHash(new JsonObject { ["operation"] = "submitAnswer", ["params"] = new JsonObject { ["sessionId"] = sessionId }, ["body"] = normalized });
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var result = await new LearningSessions(store, rows, content, clock, config).SubmitAnswerAsync(user, sessionId, exerciseId, (int)attemptOrdinal,
            answer, assisted, substituted, expectedRevision, key, hash, ct);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    /// <summary>Commit a completed session, its learning effects and its Progress event atomically.</summary>
    [HttpPost("/v1/sessions/{sessionId}/complete")]
    [ContractOperation("completeSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Complete(string sessionId, CancellationToken ct)
    {
        if (!Regex.IsMatch(sessionId, IdPattern, RegexOptions.CultureInvariant)) throw Invalid("sessionId");
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw Invalid("body");
        foreach (var field in input.Select(property => property.Key))
            if (field != "expectedRevision") throw Invalid("body." + field, "UNKNOWN_FIELD");
        if (!input.ContainsKey("expectedRevision")) throw Invalid("body.expectedRevision", "REQUIRED");
        var expectedRevision = Integer(input["expectedRevision"], "expectedRevision", 0, int.MaxValue);
        var key = IdempotencyKey();
        var normalized = new JsonObject { ["expectedRevision"] = expectedRevision };
        var hash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "completeSession",
            ["params"] = new JsonObject { ["sessionId"] = sessionId },
            ["body"] = normalized
        });
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var result = await new LearningSessions(store, rows, content, clock, config).CompleteAsync(
            user, sessionId, expectedRevision, key, hash, Response.Headers["X-Request-ID"].ToString(), relay, ct);
        return new ObjectResult(result.Receipt.Body) { StatusCode = result.Receipt.StatusCode };
    }

    /// <summary>Abandon the active session and release its course slot exactly once.</summary>
    [HttpPost("/v1/sessions/{sessionId}/abandon")]
    [ContractOperation("abandonSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Abandon(string sessionId, CancellationToken ct)
    {
        if (!Regex.IsMatch(sessionId, IdPattern, RegexOptions.CultureInvariant)) throw Invalid("sessionId");
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw Invalid("body");
        foreach (var field in input.Select(property => property.Key))
            if (field != "expectedRevision") throw Invalid("body." + field, "UNKNOWN_FIELD");
        if (!input.ContainsKey("expectedRevision")) throw Invalid("body.expectedRevision", "REQUIRED");
        var expectedRevision = Integer(input["expectedRevision"], "expectedRevision", 0, int.MaxValue);
        var key = IdempotencyKey();
        var normalized = new JsonObject { ["expectedRevision"] = expectedRevision };
        var hash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "abandonSession",
            ["params"] = new JsonObject { ["sessionId"] = sessionId },
            ["body"] = normalized
        });
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var result = await new LearningSessions(store, rows, content, clock, config).AbandonAsync(
            user, sessionId, expectedRevision, key, hash, Response.Headers["X-Request-ID"].ToString(), ct);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    private string IdempotencyKey()
    {
        var key = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase)) throw Invalid("Idempotency-Key");
        return key.ToLowerInvariant();
    }

    internal static string Id(JsonNode? value, string field)
    {
        var text = Text(value, field);
        if (!Regex.IsMatch(text, IdPattern, RegexOptions.CultureInvariant)) throw Invalid(field);
        return text;
    }

    private static string Text(JsonNode? value, string field)
    {
        if (value?.GetValueKind() != System.Text.Json.JsonValueKind.String) throw Invalid(field);
        return value.GetValue<string>();
    }

    internal static long Integer(JsonNode? value, string field, long min, long max)
    {
        if (value?.GetValueKind() != System.Text.Json.JsonValueKind.Number) throw Invalid(field);
        var number = value.GetValue<double>();
        if (!double.IsFinite(number) || number != Math.Truncate(number) || number < min || number > max) throw Invalid(field);
        return (long)number;
    }

    internal static bool Boolean(JsonNode? value, string field)
    {
        if (value?.GetValueKind() is not (System.Text.Json.JsonValueKind.True or System.Text.Json.JsonValueKind.False)) throw Invalid(field);
        return value.GetValue<bool>();
    }

    internal static JsonObject ParseAnswer(JsonNode? node, string prefix = "answer")
    {
        if (node is not JsonObject answer) throw Invalid(prefix);
        var kind = Text(answer["kind"], prefix + ".kind");
        return kind switch
        {
            "text" => ParseText(answer, prefix),
            "choice" => ParseChoice(answer, prefix),
            "tokens" => ParseTokens(answer, prefix),
            "pairs" => ParsePairs(answer, prefix),
            "speech" => ParseSpeech(answer, prefix),
            _ => throw Invalid(prefix + ".kind")
        };
    }

    private static JsonObject ParseText(JsonObject answer, string prefix)
    {
        Exact(answer, ["kind", "text"], prefix);
        return new() { ["kind"] = "text", ["text"] = BoundedText(answer, "text", 512, prefix) };
    }

    private static JsonObject ParseChoice(JsonObject answer, string prefix)
    {
        Exact(answer, ["kind", "choiceId"], prefix);
        return new() { ["kind"] = "choice", ["choiceId"] = Id(answer["choiceId"], prefix + ".choiceId") };
    }

    private static JsonObject ParseSpeech(JsonObject answer, string prefix)
    {
        Exact(answer, ["kind", "assessmentJobId"], prefix);
        return new() { ["kind"] = "speech", ["assessmentJobId"] = Id(answer["assessmentJobId"], prefix + ".assessmentJobId") };
    }

    private static JsonObject ParseTokens(JsonObject answer, string prefix)
    {
        Exact(answer, ["kind", "tokenIds"], prefix);
        if (answer["tokenIds"] is not JsonArray list || list.Count > 40) throw Invalid(prefix + ".tokenIds");
        var ids = new JsonArray(); for (var i = 0; i < list.Count; i++) ids.Add(Id(list[i], $"{prefix}.tokenIds[{i}]"));
        return new() { ["kind"] = "tokens", ["tokenIds"] = ids };
    }

    private static JsonObject ParsePairs(JsonObject answer, string prefix)
    {
        Exact(answer, ["kind", "matches"], prefix);
        if (answer["matches"] is not JsonArray list || list.Count > 10) throw Invalid(prefix + ".matches");
        var matches = new JsonArray();
        for (var i = 0; i < list.Count; i++)
        {
            var field = $"{prefix}.matches[{i}]";
            if (list[i] is not JsonObject match) throw Invalid(field);
            Exact(match, ["leftId", "rightId"], field);
            matches.Add(new JsonObject { ["leftId"] = Id(match["leftId"], field + ".leftId"), ["rightId"] = Id(match["rightId"], field + ".rightId") });
        }
        return new() { ["kind"] = "pairs", ["matches"] = matches };
    }

    private static string BoundedText(JsonObject value, string property, int max, string prefix)
    {
        var text = Text(value[property], prefix + "." + property);
        if (text.Length > max) throw Invalid(prefix + "." + property);
        return text;
    }

    internal static void Exact(JsonObject value, string[] fields, string prefix)
    {
        foreach (var field in value.Select(property => property.Key)) if (!fields.Contains(field, StringComparer.Ordinal)) throw Invalid(prefix + "." + field, "UNKNOWN_FIELD");
        foreach (var field in fields) if (!value.ContainsKey(field)) throw Invalid(prefix + "." + field, "REQUIRED");
    }

    private static ServiceException Invalid(string field, string reason = "INVALID") => new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
