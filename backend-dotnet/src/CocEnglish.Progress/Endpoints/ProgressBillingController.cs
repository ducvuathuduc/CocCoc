using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressBillingController(OwnerStore store, ProgressCommercePolicy policy) : ControllerBase
{
    private readonly ProgressBilling billing = new();

    /// <summary>Verify a simulated purchase only in explicitly composed simulation hosts.</summary>
    [HttpPost("/v1/billing/purchases")]
    [ContractOperation("verifyPurchase")]
    [ProducesResponseType<PurchaseResponse>(200)]
    public Task<IActionResult> Verify(CancellationToken ct)
    {
        RequireSimulation();
        var body = ProgressInput.Object(HttpContext, ["productId", "kind", "platform", "simulationOutcome"], "productId", "kind", "platform", "simulationOutcome");
        if (ProgressInput.Text(body["platform"], "platform", 1, 16) != "SIMULATION") throw RequestQuery.Bad("platform");
        var product = ProgressInput.Text(body["productId"], "productId", 1, 64, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var kind = ProgressInput.Text(body["kind"], "kind", 1, 16);
        if (kind is not ("SUBSCRIPTION" or "GEMS")) throw RequestQuery.Bad("kind");
        var state = State(body["simulationOutcome"], "simulationOutcome");
        return ProgressMutation.ExecuteAsync(HttpContext, store, "verifyPurchase", (tx, user, key, token) => billing.VerifyAsync(tx, user, product, kind, state, key, token));
    }

    /// <summary>Apply a maintainer-signed simulated vendor update with atomic inbox deduplication.</summary>
    [HttpPost("/internal/billing/notifications")]
    [ContractOperation("billingNotification")]
    [ServiceSenders("maintainer")]
    [ProducesResponseType<OperationReceiptResponse>(200)]
    public async Task<OperationReceiptResponse> Notify(CancellationToken ct)
    {
        RequireSimulation();
        var body = ProgressInput.Object(HttpContext, ["notificationId", "purchaseId", "platform", "state", "occurredAt"], "notificationId", "purchaseId", "platform", "state", "occurredAt");
        if (ProgressInput.Text(body["platform"], "platform", 1, 16) != "SIMULATION") throw RequestQuery.Bad("platform");
        var notification = ProgressInput.Text(body["notificationId"], "notificationId", 1, 128);
        var purchase = ProgressInput.Text(body["purchaseId"], "purchaseId", 1, 36, "^[A-Za-z0-9][A-Za-z0-9_.-]*$");
        var state = State(body["state"], "state");
        var occurredAt = ProgressInput.Text(body["occurredAt"], "occurredAt", 20, 40, @"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$");
        var status = await billing.NotifyAsync(store, notification, purchase, state, occurredAt, CanonicalWire.BodyHash(body), ct);
        return new(notification[..Math.Min(64, notification.Length)], status, Response.Headers["X-Request-ID"].ToString());
    }

    private void RequireSimulation() { if (!policy.AllowSimulation) throw new ServiceException("SERVICE_NOT_CONFIGURED"); }
    private static string State(System.Text.Json.Nodes.JsonNode? value, string field)
    {
        var state = ProgressInput.Text(value, field, 1, 16);
        if (state is not ("PENDING" or "ACTIVE" or "GRACE" or "HOLD" or "CANCELED" or "EXPIRED" or "REVOKED" or "REFUNDED")) throw RequestQuery.Bad(field);
        return state;
    }

    /// <summary>Read a purchase belonging to the verified account.</summary>
    [HttpGet("/v1/billing/purchases/{purchaseId}")]
    [ContractOperation("getPurchase")]
    [ProducesResponseType<PurchaseResponse>(200)]
    public Task<PurchaseResponse> Get([FromRoute] string purchaseId, CancellationToken ct) => store.TransactAsync((tx, token) =>
        billing.GetPurchaseAsync(tx, ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId, purchaseId, token), ct);

    /// <summary>Cancel simulated renewal while retaining remaining subscription access.</summary>
    [HttpPost("/v1/billing/subscription/cancel")]
    [ContractOperation("cancelSubscription")]
    [ProducesResponseType<EntitlementResponse>(200)]
    public Task<IActionResult> Cancel(CancellationToken ct)
    {
        ProgressInput.Empty(HttpContext);
        return ProgressMutation.ExecuteAsync(HttpContext, store, "cancelSubscription", (tx, user, _, token) => billing.CancelAsync(tx, user, token));
    }
}
