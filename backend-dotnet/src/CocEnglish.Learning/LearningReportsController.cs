using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningReportsController(OwnerStore store) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
    private static readonly string[] Fields = ["exerciseId", "lessonVersion", "category", "note"];
    private static readonly string[] Categories = ["CONTENT", "ANSWER", "AUDIO", "OTHER"];

    /// <summary>Queue a learner's content or answer report without blocking the lesson.</summary>
    [HttpPost("/v1/reports")]
    [ContractOperation("createReport")]
    [ProducesResponseType<JsonObject>(202)]
    public async Task<IActionResult> Create(CancellationToken cancellationToken)
    {
        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw RequestQuery.Bad("body");
        foreach (var field in input.Select(property => property.Key))
            if (!Fields.Contains(field, StringComparer.Ordinal)) throw Invalid("body." + field, "UNKNOWN_FIELD");
        foreach (var field in Fields.Take(3)) if (!input.ContainsKey(field)) throw Invalid("body." + field, "REQUIRED");
        var exerciseId = Identifier(input["exerciseId"], "body.exerciseId");
        var lessonVersion = Identifier(input["lessonVersion"], "body.lessonVersion");
        if (input["category"]?.GetValueKind() != System.Text.Json.JsonValueKind.String ||
            !Categories.Contains(input["category"]!.GetValue<string>(), StringComparer.Ordinal)) throw Invalid("body.category");
        var category = input["category"]!.GetValue<string>();
        var note = "";
        if (input.ContainsKey("note"))
        {
            if (input["note"]?.GetValueKind() != System.Text.Json.JsonValueKind.String) throw Invalid("body.note");
            note = input["note"]!.GetValue<string>();
            if (note.Length > 512) throw Invalid("body.note");
        }

        var idempotencyKey = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(idempotencyKey, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase))
            throw Invalid("Idempotency-Key");
        idempotencyKey = idempotencyKey.ToLowerInvariant();
        var body = new JsonObject
        {
            ["exerciseId"] = exerciseId,
            ["lessonVersion"] = lessonVersion,
            ["category"] = category
        };
        if (input.ContainsKey("note")) body["note"] = note;
        var bodyHash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "createReport",
            ["params"] = new JsonObject(),
            ["body"] = body.DeepClone()
        });
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var requestId = Response.Headers["X-Request-ID"].ToString();
        var result = await store.CommitWithReceiptAsync(new(userId, "createReport", idempotencyKey), bodyHash, async (tx, token) =>
        {
            var reportId = CanonicalWire.RowId("report", userId, idempotencyKey);
            tx.Put("l_reports", reportId, new JsonObject
            {
                ["userId"] = userId,
                ["exerciseId"] = exerciseId,
                ["lessonVersion"] = lessonVersion,
                ["category"] = category,
                ["note"] = note[..Math.Min(note.Length, 512)],
                ["status"] = "OPEN"
            });
            return new OperationResponse(202, new JsonObject { ["operationId"] = idempotencyKey, ["status"] = "accepted", ["requestId"] = requestId });
        }, cancellationToken);
        return new ObjectResult(result.Body) { StatusCode = result.StatusCode };
    }

    private static string Identifier(JsonNode? value, string field)
    {
        if (value?.GetValueKind() != System.Text.Json.JsonValueKind.String ||
            !Regex.IsMatch(value.GetValue<string>(), IdPattern, RegexOptions.CultureInvariant)) throw Invalid(field);
        return value.GetValue<string>();
    }

    private static ServiceException Invalid(string field, string reason = "INVALID") =>
        new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}
