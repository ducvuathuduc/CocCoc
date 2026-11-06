using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressRelayController(ProgressJobRunner jobs) : ControllerBase
{
    /// <summary>Lease and deliver a bounded outbox batch to every required service owner.</summary>
    [HttpPost("/internal/jobs/progress-outbox-relay")]
    [ContractOperation("runProgressOutboxRelay")]
    [ServiceSenders("scheduler", "maintainer")]
    [ProducesResponseType<JobRunReport>(200)]
    public Task<JobRunReport> Run(CancellationToken ct) => jobs.RunOutboxRelayAsync(ProgressJobInput.Parse(HttpContext), ct);
}
