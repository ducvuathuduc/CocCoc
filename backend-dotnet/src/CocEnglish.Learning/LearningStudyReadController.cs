using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

public interface ILearningStudyReadService
{
    Task<JsonObject> ListMistakesAsync(string userId, string courseId, bool includeResolved, string? cursor, int limit, CancellationToken cancellationToken);
    Task<JsonObject> ListActivitiesAsync(string userId, string courseId, string? kind, string? cursor, int limit, CancellationToken cancellationToken);
    Task<JsonObject> GetReviewAsync(string userId, string? courseId, string? cursor, int limit, CancellationToken cancellationToken);
}

public sealed class LearningStudyReadService(IRowDriver rows, TimeProvider clock) : ILearningStudyReadService
{
    public async Task<JsonObject> ListMistakesAsync(string userId, string courseId, bool includeResolved, string? cursor, int limit, CancellationToken cancellationToken)
    {
        var (offset, where) = Page(cursor, new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId });
        if (!includeResolved) where["resolvedAt"] = null;
        var query = new RowQuery(Where: where, OrderBy: [new("lastMistakeAt", Descending: true)], Limit: limit, Offset: offset);
        var items = await rows.ListAsync("l_mistakes", query, cancellationToken);
        var total = await rows.CountAsync("l_mistakes", query with { OrderBy = null, Limit = 1, Offset = 0 }, cancellationToken);
        var result = new JsonArray(items.Select(row => (JsonNode)new JsonObject
        {
            ["courseId"] = row.Data.Text("courseId"),
            ["exerciseId"] = row.Data.Text("exerciseId"),
            ["lessonVersion"] = row.Data.Text("lessonVersion"),
            ["skillId"] = row.Data.Text("skillId"),
            ["mistakeCount"] = row.Data.Number("mistakeCount"),
            ["lastMistakeAt"] = row.Data.Text("lastMistakeAt"),
            ["resolvedAt"] = row.Data.Text("resolvedAt")
        }).ToArray());
        return PageResponse(result, offset, total, items.Count);
    }

    public async Task<JsonObject> ListActivitiesAsync(string userId, string courseId, string? kind, string? cursor, int limit, CancellationToken cancellationToken)
    {
        var where = new Dictionary<string, object?> { ["userId"] = userId, ["courseId"] = courseId };
        if (kind is not null) where["kind"] = kind;
        var (offset, filters) = Page(cursor, where);
        var query = new RowQuery(Where: filters, OrderBy: [new("activityId")], Limit: limit, Offset: offset);
        var items = await rows.ListAsync("l_activity_progress", query, cancellationToken);
        var total = await rows.CountAsync("l_activity_progress", query with { OrderBy = null, Limit = 1, Offset = 0 }, cancellationToken);
        var result = new JsonArray(items.Select(row => (JsonNode)new JsonObject
        {
            ["courseId"] = row.Data.Text("courseId"),
            ["kind"] = row.Data.Text("kind"),
            ["activityId"] = row.Data.Text("activityId"),
            ["completions"] = row.Data.Number("completions"),
            ["bestScore"] = row.Data.Number("bestScore"),
            ["stars"] = row.Data.Number("stars"),
            ["firstCompletedAt"] = row.Data.Text("firstCompletedAt"),
            ["lastCompletedAt"] = row.Data.Text("lastCompletedAt")
        }).ToArray());
        return PageResponse(result, offset, total, items.Count);
    }

    public async Task<JsonObject> GetReviewAsync(string userId, string? courseId, string? cursor, int limit, CancellationToken cancellationToken)
    {
        if (cursor is { Length: > 256 } || cursor == "") throw RequestQuery.Bad("cursor");
        var offset = LearningCursor.Decode(cursor);
        if (offset < 0) throw RequestQuery.Bad("cursor");
        var where = new Dictionary<string, object?> { ["userId"] = userId };
        if (courseId is not null) where["courseId"] = courseId;
        var now = OwnerSchema.Iso(clock.GetUtcNow());
        var candidates = await rows.ListAsync("l_review_items", new RowQuery(
            Where: where,
            LessThanEqual: new Dictionary<string, object?> { ["dueAt"] = now },
            OrderBy: [new("dueAt")],
            Limit: 100), cancellationToken);

        var ordered = OrderDue(candidates.Select(row =>
        {
            var rawWindow = row.Data.Text("firstAttemptWindowJson") ?? "[]";
            var window = JsonNode.Parse(rawWindow) as JsonArray ?? [];
            var booleans = window.Select(value => value?.GetValue<bool>() ?? false).ToArray();
            var mastery = booleans.Length < 5 ? (double?)null : Math.Round((double)booleans.Count(value => value) / booleans.Length, 3, MidpointRounding.AwayFromZero);
            return new DueReviewItem(
                row.Data.Text("vocabularyId") ?? "",
                row.Data.Text("skillId") ?? "",
                row.Data.Text("dueAt") ?? "",
                (int)row.Data.Number("stage"),
                mastery,
                row.Data.Number("incorrectCount") > 0 ? row.Data.Text("lastReviewedAt") : null);
        }).ToList());

        var page = ordered.Skip(offset).Take(limit).ToArray();
        return new JsonObject
        {
            ["items"] = new JsonArray(page.Select(item => (JsonNode)new JsonObject
            {
                ["vocabularyId"] = item.VocabularyId,
                ["skillId"] = item.SkillId,
                ["dueAt"] = item.DueAt,
                ["stage"] = item.Stage,
                ["mastery"] = item.Mastery
            }).ToArray()),
            ["nextCursor"] = offset + page.Length < ordered.Count ? LearningCursor.Encode(offset + page.Length) : null,
            ["asOf"] = now
        };
    }

    private sealed record DueReviewItem(string VocabularyId, string SkillId, string DueAt, int Stage, double? Mastery, string? LastMistakeAt);

    private static List<DueReviewItem> OrderDue(List<DueReviewItem> candidates)
    {
        candidates.Sort((left, right) =>
        {
            var result = StringComparer.Ordinal.Compare(left.DueAt, right.DueAt);
            if (result != 0) return result;
            result = StringComparer.Ordinal.Compare(right.LastMistakeAt ?? "", left.LastMistakeAt ?? "");
            return result != 0 ? result : StringComparer.Ordinal.Compare(left.VocabularyId, right.VocabularyId);
        });
        var resultItems = new List<DueReviewItem>(candidates.Count);
        while (candidates.Count > 0)
        {
            var blocked = resultItems.Count >= 2 && resultItems[^1].SkillId == resultItems[^2].SkillId ? resultItems[^1].SkillId : null;
            var index = blocked is null ? 0 : candidates.FindIndex(item => item.SkillId != blocked);
            if (index < 0) index = 0;
            resultItems.Add(candidates[index]);
            candidates.RemoveAt(index);
        }
        return resultItems;
    }

    private JsonObject PageResponse(JsonArray items, int offset, long total, int count) => new()
    {
        ["items"] = items,
        ["nextCursor"] = offset + count < total ? LearningCursor.Encode(offset + count) : null,
        ["asOf"] = OwnerSchema.Iso(clock.GetUtcNow())
    };

    private static (int Offset, Dictionary<string, object?> Where) Page(string? cursor, Dictionary<string, object?> where)
    {
        if (cursor is { Length: > 256 } || cursor == "") throw RequestQuery.Bad("cursor");
        var offset = LearningCursor.Decode(cursor);
        if (offset < 0) throw RequestQuery.Bad("cursor");
        return (offset, where);
    }
}

[ApiController]
public sealed class LearningStudyReadController(ILearningStudyReadService reads) : ControllerBase
{
    private const string IdPattern = "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$";
    private static readonly string[] ActivityKinds = ["STORY", "ADVENTURE", "RADIO", "SIDE_QUEST", "CLASH", "UNIT_REVIEW"];

    /// <summary>List the authenticated learner's mistakes for one course.</summary>
    [HttpGet("/v1/mistakes")]
    [ContractOperation("listMistakes")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<JsonObject> Mistakes(CancellationToken cancellationToken)
    {
        var query = RequestQuery.Parse(Request, "courseId", "includeResolved", "cursor", "limit");
        var courseId = Id(query.GetValueOrDefault("courseId"), "courseId");
        var includeResolved = query.TryGetValue("includeResolved", out var rawResolved)
            ? rawResolved switch { "true" => true, "false" => false, _ => throw RequestQuery.Bad("includeResolved") }
            : false;
        var limit = Limit(query);
        var cursor = query.GetValueOrDefault("cursor");
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        return reads.ListMistakesAsync(userId, courseId, includeResolved, cursor, limit, cancellationToken);
    }

    /// <summary>List the authenticated learner's saved progress for course activities.</summary>
    [HttpGet("/v1/activities")]
    [ContractOperation("listActivityProgress")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<JsonObject> Activities(CancellationToken cancellationToken)
    {
        var query = RequestQuery.Parse(Request, "courseId", "kind", "cursor", "limit");
        var courseId = Id(query.GetValueOrDefault("courseId"), "courseId");
        var kind = query.GetValueOrDefault("kind");
        if (kind is not null && !ActivityKinds.Contains(kind, StringComparer.Ordinal)) throw RequestQuery.Bad("kind");
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        return reads.ListActivitiesAsync(userId, courseId, kind, query.GetValueOrDefault("cursor"), Limit(query), cancellationToken);
    }

    /// <summary>List due vocabulary for the authenticated learner's review queue.</summary>
    [HttpGet("/v1/review")]
    [ContractOperation("getReview")]
    [ProducesResponseType<JsonObject>(200)]
    public Task<JsonObject> Review(CancellationToken cancellationToken)
    {
        var query = RequestQuery.Parse(Request, "courseId", "cursor", "limit");
        var courseId = query.TryGetValue("courseId", out var rawCourse) ? Id(rawCourse, "courseId") : null;
        var userId = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        return reads.GetReviewAsync(userId, courseId, query.GetValueOrDefault("cursor"), Limit(query), cancellationToken);
    }

    private static int Limit(IReadOnlyDictionary<string, string> query)
    {
        if (!query.TryGetValue("limit", out var raw)) return 20;
        if (!double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var value) ||
            !double.IsFinite(value) || value != Math.Truncate(value) || value is < 1 or > 100)
            throw RequestQuery.Bad("limit");
        return (int)value;
    }

    private static string Id(string? value, string field)
    {
        if (value is null || !Regex.IsMatch(value, IdPattern, RegexOptions.CultureInvariant)) throw RequestQuery.Bad(field);
        return value;
    }
}
