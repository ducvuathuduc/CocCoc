using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressRolloverController(ProgressJobRunner jobs) : ControllerBase
{
    /// <summary>Apply bounded missed-day processing to oldest eligible live streaks.</summary>
    [HttpPost("/internal/jobs/streak-rollover")]
    [ContractOperation("runStreakRollover")]
    [ServiceSenders("scheduler", "maintainer")]
    [ProducesResponseType<JobRunReport>(200)]
    public Task<JobRunReport> Run(CancellationToken ct) => jobs.RunStreakRolloverAsync(ProgressJobInput.Parse(HttpContext), ct);
}
