using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

public interface ILearningContentReader
{
    Task<JsonObject> PublishedAsync(string courseId, CancellationToken cancellationToken);
    Task<JsonObject> BundleAsync(JsonObject manifest, string lessonId, CancellationToken cancellationToken);
    Task<JsonObject> BundleByLessonVersionAsync(string courseId, string lessonId, string lessonVersion, CancellationToken cancellationToken);
}

/// <summary>Loads immutable content only after checking its published hash and signature.</summary>
public sealed class LearningContentRepository(IRowDriver rows, LearningStorageFiles files, IReadOnlyDictionary<string, byte[]> keys) : ILearningContentReader
{
    public static JsonObject ParseManifest(string text, string expectedHash, IReadOnlyDictionary<string, byte[]> keys)
    {
        if (CanonicalWire.Sha256(text) != expectedHash) throw Corrupt("MANIFEST_HASH_MISMATCH");
        var manifest = Parse(text, "MANIFEST_SIGNATURE_INVALID");
        if (!LearningIntegrity.VerifyManifest(keys, manifest)) throw Corrupt("MANIFEST_SIGNATURE_INVALID");
        return manifest;
    }

    public static JsonObject ParseBundle(string text, JsonObject index, IReadOnlyDictionary<string, byte[]> keys)
    {
        var lesson = index.Text("lessonId");
        if (CanonicalWire.Sha256(text) != index.Text("sha256")) throw Corrupt("BUNDLE_HASH_MISMATCH", lesson);
        var bundle = Parse(text, "BUNDLE_SIGNATURE_INVALID", lesson);
        if (!LearningIntegrity.VerifyBundle(keys, bundle) || bundle.Text("lessonVersion") != index.Text("lessonVersion"))
            throw Corrupt("BUNDLE_SIGNATURE_INVALID", lesson);
        return bundle;
    }

    public async Task<JsonObject> ManifestVersionAsync(string courseId, string versionId, CancellationToken ct)
    {
        var details = new JsonObject { ["courseId"] = courseId, ["version"] = versionId };
        var version = (await rows.ReadAsync("l_content_versions", CanonicalWire.RowId("content-version", courseId, versionId), ct))?.Data;
        if (version is null) throw new ServiceException("NOT_FOUND", details);
        if (!string.IsNullOrEmpty(version.Text("retiredAt"))) throw new ServiceException("CONTENT_VERSION_RETIRED", details);
        var text = await files.ReadAsync(version.Text("manifestFileId") ?? "", ct);
        if (text is null) throw Corrupt("MANIFEST_FILE_MISSING");
        var manifest = ParseManifest(text, version.Text("manifestSha256") ?? "", keys);
        if (manifest.Text("courseId") != courseId || manifest.Text("courseVersion") != versionId) throw Corrupt("MANIFEST_PIN_MISMATCH");
        return manifest;
    }

    public async Task<JsonObject> PublishedAsync(string courseId, CancellationToken ct)
    {
        var course = (await rows.ReadAsync("l_courses", CanonicalWire.RowId("course", courseId), ct))?.Data;
        if (course is null || course.Text("status") != "PUBLISHED") throw new ServiceException("NOT_FOUND", new() { ["courseId"] = courseId });
        return await ManifestVersionAsync(courseId, course.Text("publishedVersion") ?? "", ct);
    }

    public async Task<JsonObject> BundleAsync(JsonObject manifest, string lessonId, CancellationToken ct)
    {
        var indexes = (manifest["bundles"] as JsonArray)?.OfType<JsonObject>() ?? [];
        var index = indexes.FirstOrDefault(x => x.Text("lessonId") == lessonId);
        if (index is null && manifest["placementBundle"] is JsonObject placement && placement.Text("lessonId") == lessonId) index = placement;
        if (index is null) throw new ServiceException("NOT_FOUND", new() { ["lessonId"] = lessonId });
        var text = await files.ReadAsync(index.Text("fileId") ?? "", ct);
        if (text is null) throw Corrupt("BUNDLE_FILE_MISSING", lessonId);
        return ParseBundle(text, index, keys);
    }

    public async Task<JsonObject> BundleByLessonVersionAsync(string courseId, string lessonId, string lessonVersion, CancellationToken ct)
    {
        var published = await PublishedAsync(courseId, ct);
        if (Pins(published, lessonId, lessonVersion)) return await BundleAsync(published, lessonId, ct);
        var versions = await rows.ListAsync("l_content_versions", new(Where: new Dictionary<string, object?> { ["courseId"] = courseId },
            OrderBy: [new("publishedAt", Descending: true)], Limit: 20), ct);
        foreach (var version in versions)
        {
            var versionId = version.Data.Text("versionId");
            if (versionId is null || versionId == published.Text("courseVersion")) continue;
            var older = await ManifestVersionAsync(courseId, versionId, ct);
            if (Pins(older, lessonId, lessonVersion)) return await BundleAsync(older, lessonId, ct);
        }
        throw new ServiceException("CONTENT_VERSION_RETIRED", new() { ["lessonVersion"] = lessonVersion });
    }

    private static bool Pins(JsonObject manifest, string lessonId, string lessonVersion) =>
        (manifest["bundles"] as JsonArray ?? []).OfType<JsonObject>().Concat(manifest["placementBundle"] is JsonObject placement ? [placement] : [])
            .Any(index => index.Text("lessonId") == lessonId && index.Text("lessonVersion") == lessonVersion);

    private static JsonObject Parse(string text, string reason, string? lesson = null)
    {
        try { return CanonicalWire.ParseBody(text) as JsonObject ?? throw Corrupt(reason, lesson); }
        catch (JsonException) { throw Corrupt(reason, lesson); }
    }
    private static ServiceException Corrupt(string reason, string? lesson = null)
    {
        var details = new JsonObject { ["reason"] = reason };
        if (lesson is not null) details["lessonId"] = lesson;
        return new ServiceException("STORAGE_UNAVAILABLE", details);
    }
}
