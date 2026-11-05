using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

public interface ILearningWordsReadService
{
    Task<JsonObject> ListWordsAsync(string userId, string courseId, string sort, string? cursor, int limit, CancellationToken cancellationToken);
}

public sealed class LearningWordsReadService(IRowDriver rows, ILearningContentReader content, TimeProvider clock) : ILearningWordsReadService
{
    public async Task<JsonObject> ListWordsAsync(string userId, string courseId, string sort, string? cursor, int limit, CancellationToken cancellationToken)
    {
        if (cursor is { Length: > 256 } || cursor == "") throw RequestQuery.Bad("cursor");
        var offset = LearningCursor.Decode(cursor);
        if (offset < 0) throw RequestQuery.Bad("cursor");

        var manifest = await content.PublishedAsync(courseId, cancellationToken);
        var lexicon = await BuildLexiconAsync(manifest, cancellationToken);
        var rowsForCourse = await rows.ListAsync("l_review_items", new RowQuery(
            Where: new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId },
            OrderBy: [new("lastReviewedAt", Descending: true)],
            Limit: 2000), cancellationToken);

        var now = clock.GetUtcNow();
        var words = rowsForCourse.Select(row =>
        {
            var vocabularyId = row.Data.Text("vocabularyId") ?? "";
            var lastReviewedAt = row.Data.Text("lastReviewedAt");
            var (term, translation) = lexicon.GetValueOrDefault(vocabularyId,
                (vocabularyId.Split('.').LastOrDefault() ?? vocabularyId, (string?)null));
            var halfLifeHours = row.Data.Number("halfLifeHours");
            return new WordItem(
                courseId,
                vocabularyId,
                row.Data.Text("skillId") ?? "",
                term,
                translation,
                (int)row.Data.Number("stage"),
                Strength(halfLifeHours, lastReviewedAt, now),
                halfLifeHours,
                row.Data.Number("correctCount"),
                row.Data.Number("incorrectCount"),
                row.Data.Text("firstSeenAt") ?? "",
                lastReviewedAt,
                row.Data.Text("dueAt") ?? "");
        }).ToList();

        if (sort == "ALPHABETICAL")
        {
            var english = CultureInfo.GetCultureInfo("en").CompareInfo;
            words.Sort((left, right) =>
            {
                var result = english.Compare(left.Term, right.Term, CompareOptions.None);
                return result != 0 ? result : StringComparer.Ordinal.Compare(left.VocabularyId, right.VocabularyId);
            });
        }

        var page = words.Skip(offset).Take(limit).ToArray();
        return new JsonObject
        {
            ["items"] = new JsonArray(page.Select(item => (JsonNode)new JsonObject
            {
                ["courseId"] = item.CourseId,
                ["vocabularyId"] = item.VocabularyId,
                ["skillId"] = item.SkillId,
                ["term"] = item.Term,
                ["translation"] = item.Translation,
                ["stage"] = item.Stage,
                ["strength"] = item.Strength,
                ["halfLifeHours"] = item.HalfLifeHours,
                ["correctCount"] = item.CorrectCount,
                ["incorrectCount"] = item.IncorrectCount,
                ["firstSeenAt"] = item.FirstSeenAt,
                ["lastReviewedAt"] = item.LastReviewedAt,
                ["dueAt"] = item.DueAt
            }).ToArray()),
            ["nextCursor"] = offset + page.Length < words.Count ? LearningCursor.Encode(offset + page.Length) : null,
            ["asOf"] = OwnerSchema.Iso(now)
        };
    }

    private async Task<Dictionary<string, (string Term, string? Translation)>> BuildLexiconAsync(JsonObject manifest, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, (string Term, string? Translation)>(StringComparer.Ordinal);
        var indexes = (manifest["bundles"] as JsonArray)?.OfType<JsonObject>() ?? [];
        foreach (var index in indexes)
        {
            var lessonId = index.Text("lessonId");
            if (lessonId is null) continue;
            var bundle = await content.BundleAsync(manifest, lessonId, cancellationToken);
            foreach (var exercise in (bundle["exercises"] as JsonArray)?.OfType<JsonObject>() ?? [])
            {
                if (exercise.Text("type") != "matchPairs") continue;
                var vocabularyIds = exercise["vocabularyIds"] as JsonArray ?? [];
                var pairs = (exercise["content"] as JsonObject)?["pairs"] as JsonArray;
                if (pairs is null || pairs.Count != vocabularyIds.Count) continue;
                for (var position = 0; position < vocabularyIds.Count; position++)
                {
                    var vocabularyId = vocabularyIds[position]?.GetValue<string>();
                    var pair = pairs[position] as JsonObject;
                    var left = ((pair?["left"] as JsonObject)?["text"])?.GetValue<string>();
                    var right = ((pair?["right"] as JsonObject)?["text"])?.GetValue<string>();
                    if (vocabularyId is null || left is null || right is null || result.ContainsKey(vocabularyId)) continue;
                    result.Add(vocabularyId, (Truncate(left, 120), Truncate(right, 160)));
                }
            }
        }
        return result;
    }

    private static int Strength(long halfLifeHours, string? lastReviewedAt, DateTimeOffset now)
    {
        if (string.IsNullOrEmpty(lastReviewedAt) || halfLifeHours <= 0 ||
            !DateTimeOffset.TryParse(lastReviewedAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var reviewedAt)) return 0;
        var elapsedHours = Math.Max(0, (now - reviewedAt).TotalHours);
        var strength = (int)Math.Round(4 * Math.Pow(2, -elapsedHours / halfLifeHours), MidpointRounding.AwayFromZero);
        return Math.Clamp(strength, 0, 4);
    }

    private static string Truncate(string value, int maximum) => value.Length <= maximum ? value : value[..maximum];
    private sealed record WordItem(string CourseId, string VocabularyId, string SkillId, string Term, string? Translation,
        int Stage, int Strength, long HalfLifeHours, long CorrectCount, long IncorrectCount, string FirstSeenAt,
        string? LastReviewedAt, string DueAt);
}

[ApiController]
public sealed class LearningWordsController(ILearningWordsReadService words) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";

    /// <summary>List the authenticated learner's vocabulary for a published course.</summary>
    [HttpGet("/v1/words")]
    [ContractOperation("listWords")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<JsonObject> List(CancellationToken cancellationToken)
    {
        var query = RequestQuery.Parse(Request, "courseId", "sort", "cursor", "limit");
        if (!query.TryGetValue("courseId", out var courseId) || !Regex.IsMatch(courseId, IdPattern, RegexOptions.CultureInvariant))
            throw RequestQuery.Bad("courseId");
        var sort = query.GetValueOrDefault("sort", "RECENT");
        if (sort is not ("RECENT" or "ALPHABETICAL")) throw RequestQuery.Bad("sort");
        var cursor = query.GetValueOrDefault("cursor");
        if (cursor is { Length: > 256 } || cursor == "") throw RequestQuery.Bad("cursor");
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        return words.ListWordsAsync(userId, courseId, sort, cursor, Limit(query), cancellationToken);
    }

    private static int Limit(IReadOnlyDictionary<string, string> query)
    {
        if (!query.TryGetValue("limit", out var raw)) return 20;
        if (!double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var value) ||
            !double.IsFinite(value) || value != Math.Truncate(value) || value is < 1 or > 100)
            throw RequestQuery.Bad("limit");
        return (int)value;
    }
}
