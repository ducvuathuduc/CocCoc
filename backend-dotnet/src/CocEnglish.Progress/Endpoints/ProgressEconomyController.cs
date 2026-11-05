using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressEconomyController(OwnerStore store, ProgressEconomy economy) : ControllerBase
{
    /// <summary>Spend server-owned gems on one equipped freeze, within the stored streak capacity.</summary>
    [HttpPost("/v1/me/freezes")]
    [ContractOperation("buyFreeze")]
    [ProducesResponseType<RewardsResponse>(200)]
    public Task<IActionResult> Freeze(CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "buyFreeze", (tx, user, key, token) => economy.BuyFreezeAsync(tx, user, key, token));
    }

    /// <summary>Claim a completed daily/monthly quest, preserving any persisted chest outcome.</summary>
    [HttpPost("/v1/quests/{questId}/claim")]
    [ContractOperation("claimQuest")]
    [ProducesResponseType<RewardsResponse>(200)]
    public Task<IActionResult> Claim([FromRoute] string questId, CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["periodKey", "upgradeChest"], "periodKey");
        var period = ProgressInput.Text(body["periodKey"], "periodKey", 0, 16);
        var upgrade = body.ContainsKey("upgradeChest") && ProgressInput.Boolean(body["upgradeChest"], "upgradeChest");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "claimQuest", (tx, user, _, token) => economy.ClaimQuestAsync(tx, user, questId, period, upgrade, token));
    }
}
