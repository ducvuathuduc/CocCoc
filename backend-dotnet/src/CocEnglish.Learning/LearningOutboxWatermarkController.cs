using System.Globalization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

/// <summary>Outbox status for events that occurred before a requested UTC instant.</summary>
public sealed record LearningWatermarkResponse(DateTimeOffset Before, DateTimeOffset? OldestUndeliveredAt, int PendingBefore);

public interface ILearningOutboxWatermarkService
{
    Task<LearningWatermarkResponse> GetAsync(DateTimeOffset before, CancellationToken cancellationToken);
}

public sealed class LearningOutboxWatermarkService(OwnerStore store) : ILearningOutboxWatermarkService
{
    private static readonly string[] Undelivered = ["PENDING", "LEASED", "DEAD"];

    public Task<LearningWatermarkResponse> GetAsync(DateTimeOffset before, CancellationToken cancellationToken)
    {
        var utcBefore = before.ToUniversalTime();
        var beforeIso = OwnerSchema.Iso(utcBefore);
        var query = new RowQuery(
            LessThan: new Dictionary<string, object?> { ["occurredAt"] = beforeIso },
            AnyOf: new Dictionary<string, string[]> { ["status"] = Undelivered },
            OrderBy: [new("occurredAt")],
            Limit: 1);

        return store.TransactAsync(async (tx, token) =>
        {
            var oldest = await tx.ListAsync("l_outbox", query, token);
            var count = await tx.CountAsync("l_outbox", query with { OrderBy = null }, token);
            if (count > int.MaxValue) throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "WATERMARK_COUNT_OUT_OF_RANGE" });
            DateTimeOffset? oldestAt = null;
            if (oldest.Count > 0 && DateTimeOffset.TryParse(oldest[0].Data.Text("occurredAt"), CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var parsed))
                oldestAt = parsed;
            return new LearningWatermarkResponse(utcBefore, oldestAt, (int)count);
        }, cancellationToken);
    }
}

[ApiController]
public sealed class LearningOutboxWatermarkController(ILearningOutboxWatermarkService service) : ControllerBase
{
    /// <summary>Return the oldest unacknowledged Learning event before a signed cutoff.</summary>
    [HttpGet("/internal/outbox-watermark")]
    [ContractOperation("getOutboxWatermark")]
    [ServiceSenders("progress", "maintainer")]
    [ProducesResponseType<LearningWatermarkResponse>(200)]
    public Task<LearningWatermarkResponse> Get(CancellationToken cancellationToken)
    {
        var query = RequestQuery.Parse(Request, "before");
        if (!query.TryGetValue("before", out var raw) || !DateTimeOffset.TryParse(raw, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var before))
            throw RequestQuery.Bad("before");
        return service.GetAsync(before, cancellationToken);
    }
}
