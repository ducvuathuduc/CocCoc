using CocEnglish.Shared.Errors;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Shared.Hosting;

[ApiController]
public sealed class HealthController(RuntimeSettings settings) : ControllerBase
{
    [HttpGet("/health")]
    [ContractOperation("getHealth")]
    public IActionResult Health() => Ok(new { service = settings.Service, buildId = settings.BuildId, status = "degraded" });

    [HttpGet("/ready")]
    [ContractOperation("getReadiness")]
    public IActionResult Ready() => throw new ServiceException("SERVICE_NOT_CONFIGURED", new()
    {
        ["reason"] = "DOTNET_MIGRATION_IN_PROGRESS"
    });
}
