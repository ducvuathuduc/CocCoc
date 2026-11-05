using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressLeagueResultController(OwnerStore store, ProgressLeagueResults results) : ControllerBase
{
    /// <summary>Read own latest settled league result and unseen flag.</summary>
    [HttpGet("/v1/league/result")]
    [ContractOperation("getLeagueResult")]
    [ProducesResponseType<LeagueResultResponse>(200)]
    public Task<LeagueResultResponse> Get(CancellationToken ct) => store.TransactAsync((tx, token) => results.GetAsync(tx,
        ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, token), ct);

    /// <summary>Mark only the caller's latest settled week as seen.</summary>
    [HttpPost("/v1/league/result/seen")]
    [ContractOperation("markLeagueResultSeen")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Seen(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["weekId"], "weekId");
        var week = ProgressInput.Text(body["weekId"], "weekId", 10, 10, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "markLeagueResultSeen", async (tx, user, key, token) =>
        {
            await results.SeenAsync(tx, user, week, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    }
}
