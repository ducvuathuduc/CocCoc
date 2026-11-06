using System.Globalization;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;

namespace CocEnglish.Progress.Endpoints;

internal static class ProgressJobInput
{
    public static ProgressJobTick Parse(HttpContext context)
    {
        var body = ProgressInput.Object(context, ["tickId", "scheduledAt", "limit", "cursor", "weekId"]);
        var tickId = ProgressInput.Text(body["tickId"], "tickId", 36, 36, "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$");
        var scheduled = ProgressInput.Text(body["scheduledAt"], "scheduledAt", 1, 40);
        if (!DateTimeOffset.TryParse(scheduled, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _)) throw RequestQuery.Bad("scheduledAt");
        var limit = body.ContainsKey("limit") ? (int?)ProgressInput.Integer(body["limit"], "limit", 1, 500) : null;
        if (body["cursor"] is not null) ProgressInput.Text(body["cursor"], "cursor", 0, 256);
        string? week = null;
        if (body["weekId"] is not null)
        {
            week = ProgressInput.Text(body["weekId"], "weekId", 10, 10, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
            if (!DateOnly.TryParseExact(week, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)) throw RequestQuery.Bad("weekId");
        }
        return new(tickId, limit, week);
    }
}
