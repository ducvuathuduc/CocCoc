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
public sealed class LearningEnrollmentController(OwnerStore store, ILearningContentReader content) : ControllerBase
{
    /// <summary>Enroll the authenticated learner in a published course.</summary>
    [HttpPost("/v1/enrollments")]
    [ContractOperation("enrollCourse")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Enroll(CancellationToken ct)
    {
        if ((HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value is not JsonObject body) throw Invalid("body");
        foreach (var field in body.Select(x => x.Key)) if (field is not ("courseId" or "startPoint" or "placementSessionId")) throw Invalid("body." + field, "UNKNOWN_FIELD");
        foreach (var field in new[] { "courseId", "startPoint" }) if (!body.ContainsKey(field)) throw Invalid("body." + field, "REQUIRED");
        var course = Id(body["courseId"], "courseId");
        var start = body["startPoint"]?.GetValueKind() == JsonValueKind.String ? body["startPoint"]!.GetValue<string>() : "";
        if (start is not ("beginner" or "placement")) throw Invalid("startPoint");
        var session = body["placementSessionId"] is null ? null : Id(body["placementSessionId"], "placementSessionId");
        var key = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "Idempotency-Key" });
        key = key.ToLowerInvariant();
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var normalized = new JsonObject { ["courseId"] = course, ["startPoint"] = start, ["placementSessionId"] = session };
        var hash = CanonicalWire.BodyHash(new JsonObject { ["operation"] = "enrollCourse", ["params"] = new JsonObject(), ["body"] = normalized });
        var manifest = await content.PublishedAsync(course, ct);
        var result = await store.CommitWithReceiptAsync(new(user, "enrollCourse", key), hash, async (tx, token) =>
            new OperationResponse(200, await LearningEnrollment.EnrollAsync(tx, user, course, start, session, manifest, token)), ct);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    /// <summary>Activate an existing enrollment.</summary>
    [HttpPost("/v1/enrollments/{courseId}/activate")]
    [ContractOperation("switchCourse")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<IActionResult> Switch(string courseId, CancellationToken ct) => Command(courseId, "switchCourse", ct);

    /// <summary>Reset a course and close its active session.</summary>
    [HttpPost("/v1/enrollments/{courseId}/reset")]
    [ContractOperation("resetCourse")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<IActionResult> Reset(string courseId, CancellationToken ct) => Command(courseId, "resetCourse", ct);

    /// <summary>Remove an enrollment and close its active session.</summary>
    [HttpDelete("/v1/enrollments/{courseId}")]
    [ContractOperation("removeCourse")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<IActionResult> Remove(string courseId, CancellationToken ct) => Command(courseId, "removeCourse", ct);

    private async Task<IActionResult> Command(string courseId, string operation, CancellationToken ct)
    {
        var parsed = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value;
        var body = operation == "removeCourse" && parsed is null ? new JsonObject() : parsed as JsonObject ?? throw Invalid("body");
        var allowed = operation == "removeCourse" ? Array.Empty<string>() : new[] { "expectedRevision" };
        foreach (var field in body.Select(x => x.Key)) if (!allowed.Contains(field, StringComparer.Ordinal)) throw Invalid("body." + field, "UNKNOWN_FIELD");
        long? revision = null;
        if (operation != "removeCourse")
        {
            if (!body.ContainsKey("expectedRevision")) throw Invalid("body.expectedRevision", "REQUIRED");
            if (body["expectedRevision"]?.GetValueKind() != JsonValueKind.Number) throw Invalid("expectedRevision");
            var number = body["expectedRevision"]!.GetValue<double>();
            if (!double.IsFinite(number) || number != Math.Truncate(number) || number is < 0 or > int.MaxValue) throw Invalid("expectedRevision");
            revision = (long)number;
        }
        var key = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "Idempotency-Key" });
        key = key.ToLowerInvariant();
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var normalized = revision is null ? new JsonObject() : new JsonObject { ["expectedRevision"] = revision.Value };
        var hash = CanonicalWire.BodyHash(new JsonObject { ["operation"] = operation, ["params"] = new JsonObject { ["courseId"] = courseId }, ["body"] = normalized });
        var manifest = operation == "resetCourse" ? await content.PublishedAsync(courseId, ct) : null;
        var result = await store.CommitWithReceiptAsync(new(user, operation, key), hash, async (tx, token) =>
            new OperationResponse(200, await LearningEnrollment.CommandAsync(tx, user, courseId, operation, revision, manifest, key, Response.Headers["X-Request-ID"].ToString(), token)), ct);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    private static string Id(JsonNode? value, string field)
    {
        if (value?.GetValueKind() != JsonValueKind.String || !Regex.IsMatch(value.GetValue<string>(), "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant)) throw Invalid(field);
        return value.GetValue<string>();
    }
    private static ServiceException Invalid(string field, string reason = "INVALID") => new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
