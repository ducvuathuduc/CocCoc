using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class BillingReadCancelTests
{
    [Theory]
    [InlineData("foreign", 404)]
    [InlineData("store", 404)]
    [InlineData("expired", 200)]
    [InlineData("no-purchase", 200)]
    public async Task Cancel_DeniedOrInactiveSubscriptionDoesNotChangePurchaseOrEmitEvent(string scenario, int status)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        Seed(fixture, scenario == "foreign" ? "bob" : "alice");
        var entitlement = fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))];
        if (scenario == "expired") entitlement["expiresAt"] = "2026-11-03T10:00:00.000Z";
        if (scenario == "no-purchase") entitlement["purchaseId"] = null;
        if (scenario == "store") fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", "purchase1"))]["platform"] = "PLAY";
        using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/billing/subscription/cancel") { Content = JsonContent.Create(new { }) };
        request.Headers.Add("Authorization", "Bearer alice-jwt");
        request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        using var response = await client.SendAsync(request);
        Assert.Equal(status, (int)response.StatusCode);
        Assert.Equal("ACTIVE", fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", "purchase1"))].Text("state"));
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_outbox");
        if (scenario == "expired")
        {
            var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal("EXPIRED", body["status"]!.GetValue<string>());
            Assert.False(body["unlimitedEnergy"]!.GetValue<bool>());
        }
    }

    [Fact]
    public async Task PurchaseRead_HidesForeignOwnerAndVendorState()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        Seed(fixture, "alice");
        client.DefaultRequestHeaders.Add("Authorization", "Bearer alice-jwt");
        using var response = await client.GetAsync("/v1/billing/purchases/purchase1");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!.AsObject();
        Assert.Equal(new[] { "entitlement", "gems", "kind", "platform", "productId", "purchaseId", "state", "verifiedAt" }, body.Select(p => p.Key).Order(StringComparer.Ordinal));
        Assert.Equal("ACTIVE", body["state"]!.GetValue<string>());
        Assert.Null(body["gems"]);
        fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", "purchase1"))]["userId"] = "bob";
        using var foreign = await client.GetAsync("/v1/billing/purchases/purchase1");
        using var missing = await client.GetAsync("/v1/billing/purchases/missing");
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(foreign.StatusCode, missing.StatusCode);
    }

    [Fact]
    public async Task PurchaseRead_ReturnsProfileUnavailableAfterDeletionTombstone()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        fixture.Driver.Rows.Remove(("p_profiles", CanonicalWire.RowId("p_profiles", "alice")));
        client.DefaultRequestHeaders.Add("Authorization", "Bearer alice-jwt");

        using var initialize = new HttpRequestMessage(HttpMethod.Post, "/v1/me/initialize") { Content = new StringContent("") };
        initialize.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        using var initialized = await client.SendAsync(initialize);
        Assert.Equal(HttpStatusCode.OK, initialized.StatusCode);
        Seed(fixture, "alice");

        using var deletion = new HttpRequestMessage(HttpMethod.Post, "/v1/me/deletion")
        { Content = JsonContent.Create(new { confirmation = "DELETE" }) };
        deletion.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        using var deleted = await client.SendAsync(deletion);
        Assert.Equal(HttpStatusCode.Accepted, deleted.StatusCode);
        Assert.Contains(fixture.Driver.Rows, row => row.Key.Table == "p_purchases" && row.Value.Text("purchaseId") == "purchase1");

        using var receipt = await client.GetAsync("/v1/billing/purchases/purchase1");
        Assert.Equal(HttpStatusCode.NotFound, receipt.StatusCode);
        var body = JsonNode.Parse(await receipt.Content.ReadAsStringAsync())!;
        Assert.Equal("PROFILE_UNAVAILABLE", body["error"]!["code"]!.GetValue<string>());
    }

    [Fact]
    public async Task Cancel_ChangesEntitlementAndEventAtomicallyAndKeepsAccessUntilExpiry()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        Seed(fixture, "alice");
        for (var i = 0; i < 2; i++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/billing/subscription/cancel") { Content = JsonContent.Create(new { }) };
            request.Headers.Add("Authorization", "Bearer alice-jwt");
            request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal("CANCELED", body["status"]!.GetValue<string>());
            Assert.False(body["autoRenew"]!.GetValue<bool>());
            Assert.True(body["unlimitedEnergy"]!.GetValue<bool>());
            Assert.Equal(1, body["revision"]!.GetValue<int>());
        }
        Assert.Equal("CANCELED", fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", "purchase1"))].Text("state"));
        var row = Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_outbox").Value;
        Assert.Equal("entitlement.changed.v1", row.Text("type"));
        var payload = JsonNode.Parse(row.Text("payloadJson")!)!;
        Assert.Equal(1, payload["entitlementRevision"]!.GetValue<int>());
        Assert.Equal("CANCELED", payload["status"]!.GetValue<string>());
    }

    private static void Seed(ProgressApiFixture fixture, string owner)
    {
        fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "alice"))] = new() {
            ["userId"] = "alice", ["plan"] = "SUPER", ["source"] = "PURCHASE", ["status"] = "ACTIVE", ["expiresAt"] = "2026-12-01T00:00:00.000Z", ["autoRenew"] = true,
            ["familyGroupId"] = null, ["purchaseId"] = "purchase1", ["revision"] = 0 };
        fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", "purchase1"))] = new() {
            ["purchaseId"] = "purchase1", ["userId"] = owner, ["productId"] = "super_monthly", ["kind"] = "SUBSCRIPTION", ["platform"] = "SIMULATION", ["state"] = "ACTIVE",
            ["purchaseToken"] = "simulation-fixture", ["purchaseTokenHash"] = CanonicalWire.Sha256("simulation-fixture"),
            ["verifiedAt"] = "2026-11-01T00:00:00.000Z", ["vendorStateJson"] = "{\"simulation\":true}", ["revision"] = 0 };
    }
}
