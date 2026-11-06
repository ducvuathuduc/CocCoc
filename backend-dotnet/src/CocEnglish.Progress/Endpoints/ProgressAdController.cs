using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Errors;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressAdController(OwnerStore store, ProgressCommercePolicy policy) : ControllerBase
{
    /// <summary>Record a simulated ad using server-day limits and duplicate-safe rewards.</summary>
    [HttpPost("/v1/ad-events")]
    [ContractOperation("recordAdEvent")]
    [ProducesResponseType<AdResponse>(200)]
    public Task<IActionResult> Record(CancellationToken ct)
    {
        if (!policy.AllowSimulation) throw new ServiceException("SERVICE_NOT_CONFIGURED");
        var body = ProgressInput.Object(HttpContext, ["adEventId", "placement", "kind"], "adEventId", "placement", "kind");
        var ad = ProgressInput.Text(body["adEventId"], "adEventId", 36, 36, "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$");
        var placement = ProgressInput.Text(body["placement"], "placement", 1, 32);
        if (placement is not ("LESSON_END_INTERSTITIAL" or "REWARDED_GEMS" or "REWARDED_ENERGY_REFILL")) throw RequestQuery.Bad("placement");
        var kind = ProgressInput.Text(body["kind"], "kind", 1, 24); if (kind is not ("IMPRESSION" or "REWARDED_COMPLETION")) throw RequestQuery.Bad("kind");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "recordAdEvent", (tx, user, _, token) => new ProgressAds().RecordAsync(tx, user, ad, placement, kind, token));
    }
}
