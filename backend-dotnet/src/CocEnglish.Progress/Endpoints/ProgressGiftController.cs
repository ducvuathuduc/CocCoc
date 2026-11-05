using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Errors;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressGiftController(OwnerStore store, ProgressCommercePolicy policy) : ControllerBase
{
    /// <summary>Create a simulated premium gift in explicitly enabled local composition.</summary>
    [HttpPost("/v1/gifts")]
    [ContractOperation("sendGift")]
    [ProducesResponseType<GiftResponse>(200)]
    public Task<IActionResult> Send(CancellationToken ct)
    {
        RequireSimulation();
        var body = ProgressInput.Object(HttpContext, ["recipientUserId", "plan", "durationDays", "note", "simulationOutcome"], "recipientUserId", "plan", "durationDays", "note", "simulationOutcome");
        var recipient = ProgressInput.Text(body["recipientUserId"], "recipientUserId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var plan = ProgressInput.Text(body["plan"], "plan", 1, 5); if (plan is not ("SUPER" or "MAX")) throw RequestQuery.Bad("plan");
        var days = ProgressInput.Integer(body["durationDays"], "durationDays", 1, 365);
        var note = body["note"] is null ? null : ProgressInput.Text(body["note"], "note", 0, 160);
        var state = ProgressInput.Text(body["simulationOutcome"], "simulationOutcome", 1, 16);
        if (state is not ("PENDING" or "ACTIVE" or "GRACE" or "HOLD" or "CANCELED" or "EXPIRED" or "REVOKED" or "REFUNDED")) throw RequestQuery.Bad("simulationOutcome");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "sendGift", (tx, user, key, token) => new ProgressGifts().SendAsync(tx, user, recipient, plan, days, note, state, key, token));
    }
    /// <summary>Redeem a delivered gift once, retaining an active MAX plan when extending.</summary>
    [HttpPost("/v1/gifts/{giftId}/redeem")]
    [ContractOperation("redeemGift")]
    [ProducesResponseType<EntitlementResponse>(200)]
    public Task<IActionResult> Redeem([FromRoute] string giftId, CancellationToken ct)
    {
        RequireSimulation(); ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "redeemGift", (tx, user, _, token) => new ProgressGifts().RedeemAsync(tx, user, giftId, token));
    }
    private void RequireSimulation() { if (!policy.AllowSimulation) throw new ServiceException("SERVICE_NOT_CONFIGURED"); }
}
