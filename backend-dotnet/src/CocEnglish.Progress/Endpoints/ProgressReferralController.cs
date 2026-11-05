using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressReferralController(OwnerStore store, ProgressReferrals referrals) : ControllerBase
{
    /// <summary>Issue the verified account's stable code and project referral counts.</summary>
    [HttpGet("/v1/me/referral")]
    [ContractOperation("getReferral")]
    [ProducesResponseType<ReferralResponse>(200)]
    public Task<ReferralResponse> Get(CancellationToken ct) => store.TransactAsync((tx, token) => referrals.GetAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, token), ct);

    /// <summary>Redeem once per invitee without replacing an active premium entitlement.</summary>
    [HttpPost("/v1/referrals/redeem")]
    [ContractOperation("redeemReferral")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public Task<IActionResult> Redeem(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["code"], "code");
        var code = ProgressInput.Text(body["code"], "code", 4, 16, "^[A-Za-z0-9-]+$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "redeemReferral", async (tx, user, key, token) => {
            await referrals.RedeemAsync(tx, user, code, token);
            return new OperationReceiptResponse(key, "completed", Response.Headers["X-Request-ID"].ToString());
        });
    }
}
