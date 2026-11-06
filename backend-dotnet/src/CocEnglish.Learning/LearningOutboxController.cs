using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Contracts;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

public sealed record LearningJobRunReport(string Job, string TickId, string StartedAt, string FinishedAt, int Processed,
    int Succeeded, int Retried, int Dead, int Skipped, string? NextCursor, bool NeedsIntervention);

[ApiController]
public sealed class LearningOutboxController(LearningOutboxJobRunner runner) : ControllerBase
{
    /// <summary>Drain due Learning events to Progress using bounded leases and retry backoff.</summary>
    [HttpPost("/internal/jobs/learning-outbox-dispatch")]
    [ContractOperation("runLearningOutboxDispatch")]
    [ServiceSenders("scheduler", "maintainer")]
    [ProducesResponseType<LearningJobRunReport>(200)]
    public async Task<LearningJobRunReport> Run(CancellationToken ct)
    {
        var tick = LearningJobTick.Parse(HttpContext);
        return await runner.RunAsync(tick.TickId, tick.Limit, TimeSpan.FromSeconds(20), ct);
    }
}

internal sealed record LearningJobTick(string TickId, int? Limit)
{
    private static readonly string[] Fields = ["tickId", "scheduledAt", "limit", "cursor", "weekId"];
    private const string Uuid = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$";

    public static LearningJobTick Parse(HttpContext context)
    {
        var body = (context.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value as JsonObject;
        if (body is null) throw RequestQuery.Bad("body");
        foreach (var field in body.Select(p => p.Key)) if (!Fields.Contains(field, StringComparer.Ordinal)) throw RequestQuery.Bad(field);
        var tickId = Text(body["tickId"], "tickId", 36, 36, Uuid);
        var scheduledAt = Text(body["scheduledAt"], "scheduledAt", 1, 40);
        if (!DateTimeOffset.TryParse(scheduledAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _)) throw RequestQuery.Bad("scheduledAt");
        int? limit = null;
        if (body.ContainsKey("limit")) limit = checked((int)Integer(body["limit"], "limit", 1, 500));
        if (body["cursor"] is not null) _ = Text(body["cursor"], "cursor", 0, 256);
        if (body["weekId"] is not null)
        {
            var week = Text(body["weekId"], "weekId", 10, 10, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
            if (!DateOnly.TryParseExact(week, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)) throw RequestQuery.Bad("weekId");
        }
        return new(tickId, limit);
    }

    private static string Text(JsonNode? node, string field, int min, int max, string? pattern = null)
    {
        if (node?.GetValueKind() != System.Text.Json.JsonValueKind.String) throw RequestQuery.Bad(field);
        var value = node.GetValue<string>();
        if (value.Length < min || value.Length > max || pattern is not null && !Regex.IsMatch(value, pattern, RegexOptions.CultureInvariant)) throw RequestQuery.Bad(field);
        return value;
    }

    private static long Integer(JsonNode? node, string field, long min, long max)
    {
        if (node?.GetValueKind() != System.Text.Json.JsonValueKind.Number) throw RequestQuery.Bad(field);
        var value = node.GetValue<double>();
        if (!double.IsFinite(value) || Math.Truncate(value) != value || value < min || value > max) throw RequestQuery.Bad(field);
        return (long)value;
    }
}
