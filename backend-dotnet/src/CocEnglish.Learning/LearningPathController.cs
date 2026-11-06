using System.Globalization;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningPathController(IRowDriver rows, LearningContentRepository content, TimeProvider clock) : ControllerBase
{
    /// <summary>Read the learner's current course path.</summary>
    [HttpGet("/v1/courses/{courseId}/path")]
    [ContractOperation("getPath")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Get(string courseId, CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "cursor", "limit");
        var cursor = query.GetValueOrDefault("cursor");
        if (cursor is not null && (cursor.Length == 0 || cursor.Length > 256)) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "cursor", ["reason"] = "INVALID" });
        var offset = LearningCursor.Decode(cursor);
        if (offset < 0) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "cursor" });
        var limit = 24;
        if (query.TryGetValue("limit", out var raw))
        {
            if (!double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var n) || !double.IsFinite(n) || n != Math.Truncate(n) || n is < 1 or > 100)
                throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "limit", ["reason"] = "INVALID" });
            limit = (int)n;
        }
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var row = (await rows.ReadAsync("l_enrollments", CanonicalWire.RowId("enrollment", user, courseId), ct))?.Data;
        if (row is null || !string.IsNullOrEmpty(row.Text("removedAt"))) throw new ServiceException("NOT_FOUND", new() { ["courseId"] = courseId, ["reason"] = "NOT_ENROLLED" });
        var manifest = await content.PublishedAsync(courseId, ct);
        var completed = (JsonNode.Parse(row.Text("completedLessonsJson") ?? "[]") as JsonArray ?? []).Select(x => x?.GetValue<string>() ?? "").ToArray();
        var mastered = (JsonNode.Parse(row.Text("masteredNodesJson") ?? "[]") as JsonArray ?? []).Select(x => x?.GetValue<string>() ?? "").ToArray();
        var nodes = (manifest["nodes"] as JsonArray ?? []).OfType<JsonObject>().OrderBy(n => n.Number("order")).ToArray();
        var page = nodes.Skip(offset).Take(limit).ToArray();
        return new JsonObject {
            ["enrollment"] = LearningEnrollment.Dto(row),
            ["nodes"] = new JsonArray(page.Select(node => (JsonNode?)new JsonObject {
                ["nodeId"] = node["nodeId"]?.DeepClone(), ["unitId"] = node["unitId"]?.DeepClone(), ["sectionId"] = node["sectionId"]?.DeepClone(),
                ["order"] = node["order"]?.DeepClone(), ["title"] = node["title"]?.DeepClone(), ["kind"] = node["kind"]?.DeepClone(),
                ["state"] = LearningPath.NodeState(node, row.Number("frontierNodeOrder"), completed, mastered), ["lessonIds"] = node["lessonIds"]?.DeepClone()
            }).ToArray()),
            ["asOf"] = OwnerSchema.Iso(clock.GetUtcNow()), ["nextCursor"] = offset + page.Length < nodes.Length ? LearningCursor.Encode(offset + page.Length) : null
        };
    }
}
