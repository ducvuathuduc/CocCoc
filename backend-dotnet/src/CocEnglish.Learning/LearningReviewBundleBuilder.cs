using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

internal sealed record LearningReviewSnapshot(JsonObject Bundle, string Snapshot, string Hash);

/// <summary>Builds the private, immutable review bundle from completed lessons, due words and mistakes.</summary>
internal static class LearningReviewBundleBuilder
{
    public const string ReviewLessonId = "review_dynamic";
    private const int ReviewMinimum = 5;
    private const int ReviewMaximum = 20;
    private const int SnapshotLimit = 65536;

    private sealed record SourceExercise(JsonObject Exercise, JsonObject Source);
    private sealed record DueWord(string VocabularyId, string SkillId, string DueAt, string? LastMistakeAt);

    public static async Task<LearningReviewSnapshot> BuildAsync(
        IRowDriver rows,
        ILearningContentReader content,
        JsonObject manifest,
        JsonObject enrollment,
        string userId,
        string courseId,
        string sessionKey,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var completed = Strings(enrollment.Text("completedLessonsJson"));
        var frontier = enrollment.Number("frontierNodeOrder");
        var completedLessons = (manifest["nodes"] as JsonArray ?? [])
            .OfType<JsonObject>()
            .OrderBy(node => node.Number("order"))
            .Where(node => node.Number("order") < frontier || LessonIds(node).Any(completed.Contains))
            .SelectMany(node => LessonIds(node).Where(lessonId => node.Number("order") < frontier || completed.Contains(lessonId)))
            .ToArray();
        if (completedLessons.Length == 0) throw new ServiceException("NOT_FOUND", new() { ["reason"] = "REVIEW_POOL_EMPTY" });

        var sources = new List<JsonObject>(completedLessons.Length);
        foreach (var lessonId in completedLessons)
            sources.Add(await content.BundleAsync(manifest, lessonId, cancellationToken));

        var due = await DueWordsAsync(rows, userId, courseId, now, cancellationToken);
        var picked = new List<SourceExercise>();
        var pickedIds = new HashSet<string>(StringComparer.Ordinal);

        var mistakes = await rows.ListAsync("l_mistakes", new RowQuery(
            Where: new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId, ["resolvedAt"] = null },
            OrderBy: [new("lastMistakeAt", Descending: true)],
            Limit: 10), cancellationToken);
        foreach (var mistake in mistakes)
        {
            var exerciseId = mistake.Data.Text("exerciseId") ?? "";
            foreach (var source in sources)
            {
                var exercise = Exercises(source).FirstOrDefault(item => item.Text("id") == exerciseId);
                if (exercise is not null && pickedIds.Add(exerciseId))
                {
                    picked.Add(new(exercise, source));
                    break;
                }
            }
        }

        foreach (var word in due)
        {
            foreach (var source in sources)
            {
                var exercise = Exercises(source).FirstOrDefault(item =>
                    !pickedIds.Contains(item.Text("id") ?? "") && VocabularyIds(item).Contains(word.VocabularyId, StringComparer.Ordinal));
                if (exercise is not null)
                {
                    pickedIds.Add(exercise.Text("id") ?? "");
                    picked.Add(new(exercise, source));
                    break;
                }
            }
        }

        foreach (var source in sources.AsEnumerable().Reverse())
        {
            if (picked.Count >= ReviewMinimum) break;
            foreach (var exercise in Exercises(source))
            {
                if (picked.Count >= ReviewMinimum) break;
                var id = exercise.Text("id") ?? "";
                if (pickedIds.Add(id)) picked.Add(new(exercise, source));
            }
        }

        var chosen = picked.Take(ReviewMaximum).ToList();
        if (chosen.Count < ReviewMinimum) throw new ServiceException("NOT_FOUND", new() { ["reason"] = "REVIEW_POOL_EMPTY" });

        var bundle = BuildBundle(chosen, manifest, courseId, sessionKey);
        var snapshot = CanonicalWire.Json(bundle);
        while (snapshot.Length > SnapshotLimit && chosen.Count > ReviewMinimum)
        {
            chosen.RemoveAt(chosen.Count - 1);
            bundle = BuildBundle(chosen, manifest, courseId, sessionKey);
            snapshot = CanonicalWire.Json(bundle);
        }
        if (snapshot.Length > SnapshotLimit)
            throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "REVIEW_SNAPSHOT_TOO_LARGE" });
        return new(bundle, snapshot, CanonicalWire.Sha256(snapshot));
    }

    private static async Task<IReadOnlyList<DueWord>> DueWordsAsync(IRowDriver rows, string userId, string courseId, DateTimeOffset now, CancellationToken ct)
    {
        var candidates = await rows.ListAsync("l_review_items", new RowQuery(
            Where: new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId },
            LessThanEqual: new Dictionary<string, object?> { ["dueAt"] = OwnerSchema.Iso(now) },
            OrderBy: [new("dueAt")],
            Limit: 100), ct);
        var result = candidates.Select(row => new DueWord(
            row.Data.Text("vocabularyId") ?? "",
            row.Data.Text("skillId") ?? "",
            row.Data.Text("dueAt") ?? "",
            row.Data.Number("incorrectCount") > 0 ? row.Data.Text("lastReviewedAt") : null)).ToList();
        result.Sort((left, right) =>
        {
            var compare = StringComparer.Ordinal.Compare(left.DueAt, right.DueAt);
            if (compare != 0) return compare;
            compare = StringComparer.Ordinal.Compare(right.LastMistakeAt ?? "", left.LastMistakeAt ?? "");
            return compare != 0 ? compare : StringComparer.Ordinal.Compare(left.VocabularyId, right.VocabularyId);
        });

        var ordered = new List<DueWord>(result.Count);
        while (result.Count > 0)
        {
            var blocked = ordered.Count >= 2 && ordered[^1].SkillId == ordered[^2].SkillId ? ordered[^1].SkillId : null;
            var index = blocked is null ? 0 : result.FindIndex(item => item.SkillId != blocked);
            if (index < 0) index = 0;
            ordered.Add(result[index]);
            result.RemoveAt(index);
        }
        return ordered.Take(ReviewMaximum).ToArray();
    }

    private static JsonObject BuildBundle(IReadOnlyList<SourceExercise> chosen, JsonObject manifest, string courseId, string sessionKey)
    {
        var exercises = chosen.Select(item => item.Exercise).ToArray();
        var requiredAssetIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var exercise in exercises)
        {
            AddAssetId(requiredAssetIds, (exercise["prompt"] as JsonObject)?.Text("audioAssetId"));
            foreach (var choice in (exercise["content"]?["choices"] as JsonArray ?? []).OfType<JsonObject>())
                AddAssetId(requiredAssetIds, choice.Text("imageAssetId"));
        }

        var selectedAssets = new Dictionary<string, JsonObject>(StringComparer.Ordinal);
        foreach (var item in chosen)
        {
            foreach (var asset in (item.Source["assets"] as JsonArray ?? []).OfType<JsonObject>())
            {
                var fileId = asset.Text("fileId") ?? "";
                if (requiredAssetIds.Contains(fileId)) selectedAssets[fileId] = asset.DeepClone().AsObject();
            }
        }
        var slowVariants = new List<JsonObject>();
        foreach (var item in chosen)
        {
            foreach (var asset in (item.Source["assets"] as JsonArray ?? []).OfType<JsonObject>())
            {
                var fileId = asset.Text("fileId") ?? "";
                if (fileId.EndsWith(".s", StringComparison.Ordinal) &&
                    requiredAssetIds.Contains(fileId[..^2] + ".n") && !selectedAssets.ContainsKey(fileId) &&
                    !slowVariants.Any(value => value.Text("fileId") == fileId))
                    slowVariants.Add(asset.DeepClone().AsObject());
            }
        }
        var assets = selectedAssets.Values.Concat(slowVariants).Take(100).Select(item => (JsonNode)item).ToArray();
        var skills = new List<string>();
        foreach (var skill in exercises.SelectMany(SkillIds))
            if (!skills.Contains(skill, StringComparer.Ordinal) && skills.Count < 20) skills.Add(skill);

        var first = chosen[0].Source;
        var lessonVersion = "review." + CanonicalWire.Sha256(sessionKey)[..20];
        var unsigned = new JsonObject
        {
            ["schemaVersion"] = 1,
            ["courseId"] = courseId,
            ["courseVersion"] = manifest.Text("courseVersion"),
            ["sectionId"] = first.Text("sectionId"),
            ["unitId"] = first.Text("unitId"),
            ["nodeId"] = first.Text("nodeId"),
            ["order"] = 0,
            ["lessonId"] = ReviewLessonId,
            ["lessonVersion"] = lessonVersion,
            ["rewardIdentity"] = ReviewLessonId,
            ["title"] = "Ôn tập",
            ["skillIds"] = new JsonArray(skills.Select(skill => (JsonNode?)JsonValue.Create(skill)).ToArray()),
            ["exercises"] = new JsonArray(exercises.Select(item => (JsonNode)item.DeepClone()).ToArray()),
            ["assets"] = new JsonArray(assets),
            ["gradingRulesVersion"] = first.Text("gradingRulesVersion"),
            ["manifestHash"] = manifest.Text("manifestHash")
        };
        var signature = Convert.ToBase64String(SHA512.HashData(Encoding.UTF8.GetBytes(CanonicalWire.Json(unsigned))))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
        unsigned["signatureKeyId"] = "server-snapshot-sha512";
        unsigned["signature"] = signature;
        return unsigned;
    }

    private static IEnumerable<JsonObject> Exercises(JsonObject source) => (source["exercises"] as JsonArray ?? []).OfType<JsonObject>();
    private static IEnumerable<string> LessonIds(JsonObject node) => (node["lessonIds"] as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "");
    private static IEnumerable<string> VocabularyIds(JsonObject exercise) => (exercise["vocabularyIds"] as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "");
    private static IEnumerable<string> SkillIds(JsonObject exercise) => (exercise["skillIds"] as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "");
    private static void AddAssetId(HashSet<string> ids, string? value) { if (!string.IsNullOrEmpty(value)) ids.Add(value); }
    private static HashSet<string> Strings(string? json) => string.IsNullOrEmpty(json)
        ? new(StringComparer.Ordinal)
        : (JsonNode.Parse(json) as JsonArray ?? []).Select(value => value?.GetValue<string>() ?? "").ToHashSet(StringComparer.Ordinal);
}
