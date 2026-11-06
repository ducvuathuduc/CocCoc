using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.AI;

[ApiController]
public sealed class AiVoiceController(IAiVoiceService voice) : ControllerBase
{
    private const int MaxWavBase64Length = 640064;
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
    private const string ShaPattern = "^[a-f0-9]{64}$";

    /// <summary>Create a voice session only when the configured speech provider is available.</summary>
    [HttpPost("/v1/voice-sessions")]
    [ContractOperation("createVoiceSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> CreateSession(CancellationToken ct)
    {
        var input = Body();
        ValidateFields(input, ["sessionId", "scenarioId", "mode", "level"], ["sessionId", "scenarioId", "mode", "level"]);
        var sessionId = Uuid(input["sessionId"], "body.sessionId");
        var scenarioId = Identifier(input["scenarioId"], "body.scenarioId");
        var mode = OneOf(input["mode"], "body.mode", ["LIVE", "TURN"]);
        var level = OneOf(input["level"], "body.level", ["A1", "A2"]);
        var key = IdempotencyKey();
        var body = new JsonObject { ["sessionId"] = sessionId, ["scenarioId"] = scenarioId, ["mode"] = mode, ["level"] = level };
        var receipt = await voice.CreateVoiceAsync(UserId(), sessionId, scenarioId, mode, level, key, Hash("createVoiceSession", body), ct);
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    /// <summary>Record a bounded, monotonic heartbeat for the caller's voice session.</summary>
    [HttpPost("/v1/voice-sessions/{sessionId}/heartbeat")]
    [ContractOperation("heartbeatVoiceSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Heartbeat(string sessionId, CancellationToken ct)
    {
        var input = Body();
        ValidateFields(input, ["epoch", "elapsedSeconds", "turnCount"], ["epoch", "elapsedSeconds", "turnCount"]);
        var id = Uuid(JsonValue.Create(sessionId), "sessionId");
        var epoch = Integer(input["epoch"], "body.epoch", 0, int.MaxValue);
        var elapsedSeconds = Integer(input["elapsedSeconds"], "body.elapsedSeconds", 0, 180);
        _ = Integer(input["turnCount"], "body.turnCount", 0, 50);
        return await voice.HeartbeatAsync(UserId(), id, epoch, elapsedSeconds, ct);
    }

    /// <summary>Close the caller's voice session and release its matching active slot.</summary>
    [HttpPost("/v1/voice-sessions/{sessionId}/close")]
    [ContractOperation("closeVoiceSession")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Close(string sessionId, CancellationToken ct)
    {
        var id = Uuid(JsonValue.Create(sessionId), "sessionId");
        return await voice.CloseAsync(UserId(), id, ct);
    }

    /// <summary>Accept a bounded WAV assessment job without persisting the submitted audio.</summary>
    [HttpPost("/v1/assessment-jobs")]
    [ContractOperation("createAssessment")]
    [ProducesResponseType<JsonObject>(202)]
    public async Task<IActionResult> CreateAssessment(CancellationToken ct)
    {
        var input = Body();
        ValidateFields(input,
            ["jobId", "referenceExerciseId", "lessonVersion", "locale", "wavBase64", "audioSha256", "referenceText"],
            ["jobId", "referenceExerciseId", "lessonVersion", "locale", "wavBase64", "audioSha256"]);
        var jobId = Uuid(input["jobId"], "body.jobId");
        var exerciseId = Identifier(input["referenceExerciseId"], "body.referenceExerciseId");
        var lessonVersion = Identifier(input["lessonVersion"], "body.lessonVersion");
        var locale = OneOf(input["locale"], "body.locale", ["en-US"]);
        var wav = Text(input["wavBase64"], "body.wavBase64", 4, MaxWavBase64Length);
        var sha = Sha(input["audioSha256"], "body.audioSha256");
        string? reference = null;
        if (input["referenceText"] is not null)
            reference = Text(input["referenceText"], "body.referenceText", 1, 300);

        var body = new JsonObject
        {
            ["jobId"] = jobId,
            ["referenceExerciseId"] = exerciseId,
            ["lessonVersion"] = lessonVersion,
            ["locale"] = locale,
            ["wavBase64"] = wav,
            ["audioSha256"] = sha
        };
        if (reference is not null) body["referenceText"] = reference;
        var receipt = await voice.CreateAssessmentAsync(UserId(), new(jobId, exerciseId, lessonVersion, locale, wav, sha, reference), IdempotencyKey(), Hash("createAssessment", body), ct);
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    /// <summary>Return an assessment job owned by the authenticated caller.</summary>
    [HttpGet("/v1/assessment-jobs/{jobId}")]
    [ContractOperation("getAssessment")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> GetAssessment(string jobId, CancellationToken ct)
    {
        _ = RequestQuery.Parse(Request);
        return await voice.GetAssessmentAsync(UserId(), Uuid(JsonValue.Create(jobId), "jobId"), ct);
    }

    /// <summary>Validate a recorded turn request and expose transcript/score only through an admitted speech provider.</summary>
    [HttpPost("/v1/voice-sessions/{sessionId}/turns")]
    [ContractOperation("submitVoiceTurn")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> SubmitTurn(string sessionId, CancellationToken ct)
    {
        var id = Uuid(JsonValue.Create(sessionId), "sessionId");
        var input = Body();
        ValidateFields(input, ["turnId", "epoch", "wavBase64", "audioSha256"], ["turnId", "epoch", "wavBase64", "audioSha256"]);
        var turnId = Uuid(input["turnId"], "body.turnId");
        var epoch = Integer(input["epoch"], "body.epoch", 0, int.MaxValue);
        var wav = Text(input["wavBase64"], "body.wavBase64", 4, MaxWavBase64Length);
        var sha = Sha(input["audioSha256"], "body.audioSha256");
        var body = new JsonObject { ["turnId"] = turnId, ["epoch"] = epoch, ["wavBase64"] = wav, ["audioSha256"] = sha };
        var hash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "submitVoiceTurn",
            ["params"] = new JsonObject { ["sessionId"] = id },
            ["body"] = body
        });
        var receipt = await voice.SubmitVoiceTurnAsync(UserId(), id, turnId, epoch, wav, sha, IdempotencyKey(), hash, ct);
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    private JsonObject Body() => HttpContext.Items[typeof(ParsedRequestBody)] is ParsedRequestBody { Value: JsonObject input }
        ? input
        : throw Invalid("body");

    private string UserId() => ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;

    private string IdempotencyKey()
    {
        var key = Request.Headers["Idempotency-Key"].ToString();
        return Regex.IsMatch(key, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase)
            ? key.ToLowerInvariant()
            : throw Invalid("Idempotency-Key");
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

    private static string Uuid(JsonNode? value, string field)
    {
        var text = Text(value, field, 36, 36);
        return Regex.IsMatch(text, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase)
            ? text.ToLowerInvariant()
            : throw Invalid(field);
    }

    private static string Sha(JsonNode? value, string field)
    {
        var text = Text(value, field, 64, 64);
        return Regex.IsMatch(text, ShaPattern, RegexOptions.CultureInvariant) ? text : throw Invalid(field);
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

    private static int Integer(JsonNode? value, string field, int min, int max)
    {
        if (value is JsonValue scalar && scalar.TryGetValue<JsonElement>(out var element) &&
            element.ValueKind == JsonValueKind.Number && element.TryGetDecimal(out var number) &&
            decimal.Truncate(number) == number && number >= min && number <= max)
            return (int)number;
        throw Invalid(field);
    }

    private static string Hash(string operation, JsonObject body) => CanonicalWire.BodyHash(new JsonObject
    {
        ["operation"] = operation,
        ["params"] = new JsonObject(),
        ["body"] = body
    });

    private static ServiceException Invalid(string field, string reason = "INVALID") =>
        new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
