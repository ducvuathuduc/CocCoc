using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressFamilyController(OwnerStore store, ProgressFamily family) : ControllerBase
{
    /// <summary>Create a family from an eligible purchased premium entitlement.</summary>
    [HttpPost("/v1/family")]
    [ContractOperation("createFamily")]
    [ProducesResponseType<FamilyResponse>(200)]
    public Task<IActionResult> Create(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["plan"], "plan"); var plan = ProgressInput.Text(body["plan"], "plan", 1, 5);
        if (plan is not ("SUPER" or "MAX")) throw RequestQuery.Bad("plan");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "createFamily", (tx, user, key, token) => family.CreateAsync(tx, user, plan, key, token));
    }
    /// <summary>Join an active family with its normalized invitation code.</summary>
    [HttpPost("/v1/family/{groupId}/members")]
    [ContractOperation("joinFamily")]
    [ProducesResponseType<FamilyResponse>(200)]
    public Task<IActionResult> Join([FromRoute] string groupId, CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["inviteCode"], "inviteCode");
        var code = ProgressInput.Text(body["inviteCode"], "inviteCode", 4, 16, "^[A-Za-z0-9-]+$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "joinFamily", (tx, user, _, token) => family.JoinAsync(tx, user, groupId, code, token));
    }
    /// <summary>Allow the manager to remove a member or a member to leave.</summary>
    [HttpDelete("/v1/family/{groupId}/members/{userId}")]
    [ContractOperation("removeFamilyMember")]
    [ProducesResponseType<FamilyResponse>(200)]
    public Task<IActionResult> Remove([FromRoute] string groupId, [FromRoute] string userId, CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "removeFamilyMember", (tx, user, _, token) => family.RemoveAsync(tx, user, groupId, userId, token));
    }
}
