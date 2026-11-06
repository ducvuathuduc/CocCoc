using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressFriendStreakController(OwnerStore store, ProgressFriendStreaks streaks) : ControllerBase
{
    /// <summary>Read the caller's bounded open friend-streak relationships.</summary>
    [HttpGet("/v1/friend-streaks")]
    [ContractOperation("listFriendStreaks")]
    [ProducesResponseType<FriendStreakPageResponse>(200)]
    public Task<FriendStreakPageResponse> List(CancellationToken ct) => store.TransactAsync((tx, token) =>
        streaks.ListAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, token), ct);

    /// <summary>Invite a reciprocal friend whose preferences permit invitations.</summary>
    [HttpPost("/v1/friend-streaks")]
    [ContractOperation("inviteFriendStreak")]
    [ProducesResponseType<FriendStreakResponse>(200)]
    public Task<IActionResult> Invite(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["targetUserId"], "targetUserId");
        var target = ProgressInput.Text(body["targetUserId"], "targetUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "inviteFriendStreak", (tx, user, _, token) => streaks.InviteAsync(tx, user, target, token));
    }

    /// <summary>Accept or decline an invitation belonging to the verified recipient.</summary>
    [HttpPost("/v1/friend-streaks/{pairId}/respond")]
    [ContractOperation("respondFriendStreak")]
    [ProducesResponseType<FriendStreakResponse>(200)]
    public Task<IActionResult> Respond([FromRoute] string pairId, CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["accept"], "accept");
        var accept = ProgressInput.Boolean(body["accept"], "accept");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "respondFriendStreak", (tx, user, _, token) => streaks.RespondAsync(tx, user, pairId, accept, token));
    }
}
