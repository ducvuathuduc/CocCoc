using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningBundleController(IRowDriver rows, LearningContentRepository content) : ControllerBase
{
    /// <summary>Read a verified published lesson bundle.</summary>
    [HttpGet("/v1/lessons/{lessonId}/bundle")]
    [ContractOperation("getBundle")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Get(string lessonId, CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "version");
        var version = query.GetValueOrDefault("version");
        if (!string.IsNullOrEmpty(version) && !Regex.IsMatch(version, "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant))
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "version", ["reason"] = "INVALID" });
        var courses = await rows.ListAsync("l_courses", new(Where: new Dictionary<string, object?> { ["status"] = "PUBLISHED" }, Limit: 100), ct);
        foreach (var course in courses)
        {
            var courseId = course.Data.Text("courseId") ?? "";
            JsonObject manifest;
            if (string.IsNullOrEmpty(version)) manifest = await content.PublishedAsync(courseId, ct);
            else
            {
                try { manifest = await content.ManifestVersionAsync(courseId, version, ct); }
                catch (Exception e) when (e is not OperationCanceledException) { continue; }
            }
            var indexed = (manifest["bundles"] as JsonArray)?.OfType<JsonObject>().Any(x => x.Text("lessonId") == lessonId) == true ||
                          manifest["placementBundle"] is JsonObject placement && placement.Text("lessonId") == lessonId;
            if (indexed) return await content.BundleAsync(manifest, lessonId, ct);
        }
        throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
    }
}
