using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;

namespace CocEnglish.Learning;

/// <summary>Published course summary.</summary>
public sealed record CourseSummary(string CourseId, string Title, string SourceLocale, string TargetLocale, string PublishedVersion, bool Available);
/// <summary>Published courses and an opaque continuation cursor.</summary>
public sealed record CoursePage(IReadOnlyList<CourseSummary> Items, string? NextCursor, DateTimeOffset AsOf);

[ApiController]
public sealed class LearningCoursesController(IRowDriver driver, TimeProvider clock) : ControllerBase
{
    /// <summary>Read an ordered page of published courses.</summary>
    [HttpGet("/v1/courses")]
    [ContractOperation("listCourses")]
    [ProducesResponseType<CoursePage>(200)]
    public async Task<CoursePage> List(CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "cursor", "limit");
        var limit = 20;
        if (query.TryGetValue("limit", out var value))
        {
            if (!double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var number) || !double.IsFinite(number) || number != Math.Truncate(number) || number is < 1 or > 100) throw RequestQuery.Bad("limit");
            limit = (int)number;
        }
        var cursor = query.GetValueOrDefault("cursor");
        if (cursor is not null && (cursor.Length == 0 || cursor.Length > 256)) throw RequestQuery.Bad("cursor");
        var offset = LearningCursor.Decode(cursor); if (offset < 0) throw RequestQuery.Bad("cursor");
        var where = new Dictionary<string, object?> { ["status"] = "PUBLISHED" };
        var rows = await driver.ListAsync("l_courses", new(Where: where, OrderBy: [new("courseId")], Limit: limit, Offset: offset), ct);
        var total = await driver.CountAsync("l_courses", where, ct);
        return new(rows.Select(r => new CourseSummary(r.Data.Text("courseId")!, r.Data.Text("title")!, r.Data.Text("sourceLocale")!, r.Data.Text("targetLocale")!, r.Data.Text("publishedVersion")!, true)).ToArray(),
            offset + rows.Count < total ? LearningCursor.Encode(offset + rows.Count) : null, clock.GetUtcNow());
    }
}
