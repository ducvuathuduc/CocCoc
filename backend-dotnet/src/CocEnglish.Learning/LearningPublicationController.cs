using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningPublicationController(OwnerStore store, LearningStorageFiles files, IConfiguration configuration) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private const string ShaPattern = "^[a-f0-9]{64}$";
    private const string UuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";
    private static readonly string[] Fields = ["courseId", "versionId", "manifestFileId", "manifestSha256", "expectedPublishedVersion"];

    /// <summary>Verify a signed content version, then atomically publish its immutable version and course pointer.</summary>
    [HttpPost("/v1/admin/content-versions")]
    [ContractOperation("publishContent")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<IActionResult> Publish(CancellationToken cancellationToken)
    {
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var maintainers = (configuration["COC_MAINTAINER_USER_IDS"] ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (!maintainers.Contains(userId, StringComparer.Ordinal)) throw new ServiceException("MAINTAINER_REQUIRED");

        var input = (HttpContext.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject ?? throw RequestQuery.Bad("body");
        foreach (var field in input.Select(property => property.Key))
            if (!Fields.Contains(field, StringComparer.Ordinal)) throw Invalid("body." + field, "UNKNOWN_FIELD");
        foreach (var field in Fields)
            if (!input.ContainsKey(field)) throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "body." + field, ["reason"] = "REQUIRED" });

        var courseId = Identifier(input["courseId"], "body.courseId");
        var versionId = Identifier(input["versionId"], "body.versionId");
        var manifestFileId = Identifier(input["manifestFileId"], "body.manifestFileId");
        var manifestSha256 = Text(input["manifestSha256"], "body.manifestSha256");
        if (!Regex.IsMatch(manifestSha256, ShaPattern, RegexOptions.CultureInvariant)) throw Invalid("body.manifestSha256");
        var expectedPublishedVersion = input["expectedPublishedVersion"] is null ? null : Identifier(input["expectedPublishedVersion"], "body.expectedPublishedVersion");
        var body = new PublishBody(courseId, versionId, manifestFileId, manifestSha256, expectedPublishedVersion);

        var key = Request.Headers["Idempotency-Key"].ToString();
        if (!Regex.IsMatch(key, UuidPattern, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase)) throw Invalid("Idempotency-Key");
        key = key.ToLowerInvariant();
        var normalized = new JsonObject
        {
            ["courseId"] = courseId,
            ["versionId"] = versionId,
            ["manifestFileId"] = manifestFileId,
            ["manifestSha256"] = manifestSha256,
            ["expectedPublishedVersion"] = expectedPublishedVersion
        };
        var bodyHash = CanonicalWire.BodyHash(new JsonObject
        {
            ["operation"] = "publishContent",
            ["params"] = new JsonObject(),
            ["body"] = normalized
        });
        var manifest = await VerifyPublicationAsync(body, cancellationToken);
        var requestId = Response.Headers["X-Request-ID"].ToString();
        var receipt = await store.CommitWithReceiptAsync(new(userId, "publishContent", key), bodyHash, async (tx, token) =>
        {
            var courseRowId = CanonicalWire.RowId("course", courseId);
            var course = await tx.GetAsync("l_courses", courseRowId, token);
            var currentVersion = course?.Text("publishedVersion");
            if (currentVersion != expectedPublishedVersion)
                throw new ServiceException("REVISION_CONFLICT", new() { ["publishedVersion"] = currentVersion });

            var versionRowId = CanonicalWire.RowId("content-version", courseId, versionId);
            if (await tx.GetAsync("l_content_versions", versionRowId, token) is not null)
                throw new ServiceException("REVISION_CONFLICT", new() { ["reason"] = "VERSION_EXISTS", ["versionId"] = versionId });

            var nowIso = tx.NowIso;
            tx.Put("l_content_versions", versionRowId, new JsonObject
            {
                ["courseId"] = courseId,
                ["versionId"] = versionId,
                ["manifestFileId"] = manifestFileId,
                ["manifestSha256"] = manifestSha256,
                ["schemaVersion"] = Number(manifest["schemaVersion"]),
                ["publishedAt"] = nowIso,
                ["retiredAt"] = null,
                ["rewardMappingJson"] = "{}"
            });
            tx.Put("l_courses", courseRowId, new JsonObject
            {
                ["courseId"] = courseId,
                ["sourceLocale"] = Text(manifest["sourceLocale"], "manifest.sourceLocale"),
                ["targetLocale"] = Text(manifest["targetLocale"], "manifest.targetLocale"),
                ["title"] = Text(manifest["title"], "manifest.title"),
                ["publishedVersion"] = versionId,
                ["status"] = "PUBLISHED",
                ["manifestFileId"] = manifestFileId
            });
            return new OperationResponse(200, new JsonObject { ["operationId"] = key, ["status"] = "accepted", ["requestId"] = requestId });
        }, cancellationToken);
        return new ObjectResult(receipt.Body) { StatusCode = receipt.StatusCode };
    }

    private async Task<JsonObject> VerifyPublicationAsync(PublishBody body, CancellationToken ct)
    {
        var text = await files.ReadAsync(body.ManifestFileId, ct);
        if (text is null) throw new ServiceException("NOT_FOUND", new() { ["manifestFileId"] = body.ManifestFileId });

        JsonObject manifest;
        try
        {
            manifest = LearningContentRepository.ParseManifest(text, body.ManifestSha256, LearningIntegrity.ParseKeyring(configuration["COC_CONTENT_PUBLIC_KEYS"]));
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "manifest", ["reason"] = "HASH_OR_SIGNATURE" });
        }
        if (manifest.Text("courseId") != body.CourseId || manifest.Text("courseVersion") != body.VersionId)
            throw new ServiceException("VALIDATION_ERROR", new() { ["field"] = "manifest", ["reason"] = "PIN_MISMATCH" });

        var bundles = new List<JsonObject>();
        var problems = new List<ContentProblem>();
        foreach (var index in Objects(manifest["bundles"]))
        {
            var bundle = await LoadBundleAsync(index, ct);
            if (bundle is not null) bundles.Add(bundle);
            else problems.Add(new(index.Text("lessonId") ?? "?", "BUNDLE_FILE_MISSING"));
        }
        if (manifest["placementBundle"] is JsonObject placementIndex)
        {
            var placement = await LoadBundleAsync(placementIndex, ct);
            if (placement is null) problems.Add(new(placementIndex.Text("lessonId") ?? "placement", "BUNDLE_FILE_MISSING"));
            else problems.AddRange(LearningPublicationValidation.ValidateBundle(placement, "placement"));
        }
        else
        {
            problems.Add(new("placement", "BUNDLE_FILE_MISSING"));
        }
        problems.AddRange(LearningPublicationValidation.ValidateCourse(manifest, bundles));
        if (problems.Count != 0)
        {
            var unknownType = problems.Any(problem => problem.Problem == "UNKNOWN_EXERCISE_TYPE");
            throw new ServiceException(unknownType ? "UNKNOWN_EXERCISE_TYPE" : "VALIDATION_ERROR", new()
            {
                ["problems"] = new JsonArray(problems.Take(20).Select(problem => (JsonNode?)new JsonObject { ["where"] = problem.Where, ["problem"] = problem.Problem }).ToArray()),
                ["problemCount"] = problems.Count
            });
        }
        return manifest;

        async Task<JsonObject?> LoadBundleAsync(JsonObject index, CancellationToken cancellationToken)
        {
            var fileId = index.Text("fileId");
            var bundleText = fileId is null ? null : await files.ReadAsync(fileId, cancellationToken);
            if (bundleText is null) return null;
            try
            {
                return LearningContentRepository.ParseBundle(bundleText, index, LearningIntegrity.ParseKeyring(configuration["COC_CONTENT_PUBLIC_KEYS"]));
            }
            catch (Exception e) when (e is not OperationCanceledException) { return null; }
        }
    }

    private static IEnumerable<JsonObject> Objects(JsonNode? node) => node is JsonArray array ? array.OfType<JsonObject>() : [];
    private static string Identifier(JsonNode? value, string field)
    {
        var text = Text(value, field);
        if (!Regex.IsMatch(text, IdPattern, RegexOptions.CultureInvariant)) throw Invalid(field);
        return text;
    }
    private static string Text(JsonNode? value, string field)
    {
        if (value is JsonValue scalar && scalar.TryGetValue<string>(out var text)) return text;
        throw Invalid(field);
    }
    private static int Number(JsonNode? value) => value is JsonValue scalar && scalar.TryGetValue<int>(out var number) ? number : 0;
    private static ServiceException Invalid(string field, string reason = "INVALID") =>
        new("VALIDATION_ERROR", new() { ["field"] = field, ["reason"] = reason });
}

internal sealed record PublishBody(string CourseId, string VersionId, string ManifestFileId, string ManifestSha256, string? ExpectedPublishedVersion);
