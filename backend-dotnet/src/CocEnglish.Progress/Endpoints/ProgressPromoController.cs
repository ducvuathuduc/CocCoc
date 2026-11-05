using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressPromoController(OwnerStore store) : ControllerBase
{
    /// <summary>Redeem an active, unexhausted promo atomically with the owner's reward.</summary>
    [HttpPost("/v1/promo-codes/redeem")]
    [ContractOperation("redeemPromoCode")]
    [ProducesResponseType<PromoResponse>(200)]
    public Task<IActionResult> Redeem(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["code"], "code");
        var code = ProgressInput.Text(body["code"], "code", 4, 32, "^[A-Za-z0-9 -]+$");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "redeemPromoCode", (tx, user, _, token) => new ProgressPromos().RedeemAsync(tx, user, code, token));
    }
}
