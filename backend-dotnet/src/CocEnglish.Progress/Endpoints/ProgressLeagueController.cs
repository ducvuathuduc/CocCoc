using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressLeagueController(OwnerStore store, ProgressLeagues leagues) : ControllerBase
{
    /// <summary>Read the verified account's current weekly cohort.</summary>
    [HttpGet("/v1/league")]
    [ContractOperation("getLeague")]
    [ProducesResponseType<LeagueResponse>(200)]
    public Task<LeagueResponse> Get(CancellationToken ct)
    {
        ProgressPaging.Parse(Request);
        return store.TransactAsync((tx, token) => leagues.GetAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, token), ct);
    }

    /// <summary>Join the first open cohort of the server-recorded tier.</summary>
    [HttpPost("/v1/league/join")]
    [ContractOperation("joinLeague")]
    [ProducesResponseType<LeagueResponse>(200)]
    public Task<IActionResult> Join(CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "joinLeague", (tx, user, _, token) => leagues.JoinAsync(tx, user, token));
    }
}
