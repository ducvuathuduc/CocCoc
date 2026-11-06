using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningManifestController(LearningContentRepository content) : ControllerBase
{
    /// <summary>Read a verified published course manifest.</summary>
    [HttpGet("/v1/courses/{courseId}/manifest")]
    [ContractOperation("getManifest")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Get(string courseId, CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "version");
        var version = query.GetValueOrDefault("version");
        if (!string.IsNullOrEmpty(version) && !Regex.IsMatch(version, "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant))
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "version", ["reason"] = "INVALID" });
        var published = await content.PublishedAsync(courseId, ct);
        return string.IsNullOrEmpty(version) ? published : await content.ManifestVersionAsync(courseId, version, ct);
    }
}
