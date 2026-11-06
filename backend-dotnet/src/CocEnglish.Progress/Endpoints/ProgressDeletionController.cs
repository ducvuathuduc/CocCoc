using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressDeletionController(ProgressJobRunner jobs) : ControllerBase
{
    /// <summary>Retry acknowledged account purges in bounded batches.</summary>
    [HttpPost("/internal/jobs/deletion-purge")]
    [ContractOperation("runDeletionPurge")]
    [ServiceSenders("scheduler", "maintainer")]
    [ProducesResponseType<JobRunReport>(200)]
    public Task<JobRunReport> Run(CancellationToken ct) => jobs.RunDeletionPurgeAsync(ProgressJobInput.Parse(HttpContext), ct);
}
