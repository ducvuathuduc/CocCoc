using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressSettlementController(ProgressJobRunner jobs) : ControllerBase
{
    /// <summary>Settle ended cohorts only after Learning confirms its delivery watermark.</summary>
    [HttpPost("/internal/jobs/league-settlement")]
    [ContractOperation("runLeagueSettlement")]
    [ServiceSenders("scheduler", "maintainer")]
    [ProducesResponseType<JobRunReport>(200)]
    public Task<JobRunReport> Run(CancellationToken ct) => jobs.RunLeagueSettlementAsync(ProgressJobInput.Parse(HttpContext), ct);
}
