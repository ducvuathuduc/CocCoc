using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressShopController(OwnerStore store, ProgressShop shop) : ControllerBase
{
    private const string Token = "^[A-Za-z0-9][A-Za-z0-9_.-]*$";

    /// <summary>Read the versioned virtual-item catalog and own available quantities.</summary>
    [HttpGet("/v1/shop")]
    [ContractOperation("listShop")]
    [ProducesResponseType<ShopResponse>(200)]
    public Task<ShopResponse> Catalog(CancellationToken ct) => store.TransactAsync((tx, token) =>
        shop.ListAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, token), ct);

    /// <summary>Purchase virtual items atomically with their wallet and item ledgers.</summary>
    [HttpPost("/v1/shop/purchases")]
    [ContractOperation("buyItem")]
    [ProducesResponseType<ShopPurchaseResponse>(200)]
    public Task<IActionResult> Buy(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["itemId", "quantity", "catalogVersion"], "itemId", "quantity", "catalogVersion");
        var item = ProgressInput.Text(body["itemId"], "itemId", 1, 64, Token);
        var quantity = ProgressInput.Integer(body["quantity"], "quantity", 1, 10);
        var version = ProgressInput.Text(body["catalogVersion"], "catalogVersion", 1, 36, Token);
        var request = new ShopPurchaseRequest(item, quantity, version);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "buyItem", (tx, user, key, token) => shop.BuyAsync(tx, user, request, key, token));
    }

    /// <summary>Consume a held XP/timer boost and append its server-owned window.</summary>
    [HttpPost("/v1/me/boosts")]
    [ContractOperation("activateBoost")]
    [ProducesResponseType<BoostResponse>(200)]
    public Task<IActionResult> Activate(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["itemId"], "itemId");
        var item = ProgressInput.Text(body["itemId"], "itemId", 1, 64, Token);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "activateBoost", (tx, user, key, token) => shop.ActivateAsync(tx, user, item, key, token));
    }

    /// <summary>Restore an eligible lost streak using gems or an owned repair item.</summary>
    [HttpPost("/v1/me/streak-repair")]
    [ContractOperation("repairStreak")]
    [ProducesResponseType<RewardsResponse>(200)]
    public Task<IActionResult> Repair(CancellationToken ct)
    {
        var body = ProgressInput.Object(HttpContext, ["lostStreakDay", "payWith"], "lostStreakDay", "payWith");
        var day = ProgressInput.Text(body["lostStreakDay"], "lostStreakDay", 10, 10, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
        var payment = ProgressInput.Text(body["payWith"], "payWith", 0, int.MaxValue);
        if (payment is not ("GEMS" or "ITEM")) throw RequestQuery.Bad("payWith");
        var request = new StreakRepairRequest(day, payment);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "repairStreak", (tx, user, key, token) => shop.RepairAsync(tx, user, request, key, token));
    }
}
