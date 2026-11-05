using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressInteractionController(OwnerStore store, ProgressSocial social) : ControllerBase
{
    /// <summary>Send an allowlisted message or gift boost with daily deduplication.</summary>
    [HttpPost("/v1/interactions")]
    [ContractOperation("sendInteraction")]
    [ProducesResponseType<InteractionResponse>(200)]
    public Task<IActionResult> Send(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["targetUserId", "kind", "contextId", "messageKey"], "targetUserId", "kind", "contextId", "messageKey");
        var target = ProgressInput.Text(body["targetUserId"], "targetUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var kind = ProgressInput.Text(body["kind"], "kind", 1, 16);
        if (!new[] { "NUDGE", "HIGH_FIVE", "KUDOS", "GIFT_BOOST", "CONGRATS" }.Contains(kind, StringComparer.Ordinal)) throw RequestQuery.Bad("kind");
        var context = ProgressInput.Text(body["contextId"], "contextId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var message = ProgressInput.Text(body["messageKey"], "messageKey", 1, 64, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "sendInteraction", (tx, user, key, token) => social.InteractAsync(tx, user, target, kind, context, message, key, token));
    }

    /// <summary>Opt into this UTC week's deterministic solo or paired quest.</summary>
    [HttpPost("/v1/friend-quests/opt-in")]
    [ContractOperation("optInFriendQuest")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> OptIn(CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "optInFriendQuest", async (tx, user, key, token) =>
        {
            await social.OptInQuestAsync(tx, user, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    }
}
