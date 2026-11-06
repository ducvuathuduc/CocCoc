using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class GiftTests
{
    [Theory]
    [InlineData("missing", "PROFILE_UNAVAILABLE")]
    [InlineData("deleted", "PROFILE_UNAVAILABLE")]
    [InlineData("self", "PROFILE_UNAVAILABLE")]
    [InlineData("blocked", "USER_BLOCKED")]
    public async Task Send_DenialsDoNotCreatePurchaseOrGift(string condition, string error)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureServices(services => services.AddSingleton(new ProgressCommercePolicy(true))));
        using var client = app.CreateClient();
        if (condition != "missing") fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["deletedAt"] = condition == "deleted" ? "2026-11-03T00:00:00.000Z" : null };
        if (condition == "blocked") fixture.Driver.Rows[("p_blocks", CanonicalWire.RowId("p_blocks", "bob", "alice"))] = new() { ["userId"] = "bob", ["targetUserId"] = "alice" };
        using var request = Request("/v1/gifts", "alice", new { recipientUserId = condition == "self" ? "alice" : "bob", plan = "SUPER", durationDays = 7, note = (string?)null, simulationOutcome = "ACTIVE" });
        using var response = await client.SendAsync(request);
        Assert.Equal(error, JsonNode.Parse(await response.Content.ReadAsStringAsync())!["error"]!["code"]!.GetValue<string>());
        Assert.Equal(0, fixture.Driver.Commits);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table is "p_gifts" or "p_purchases");
    }

    [Theory]
    [InlineData("ACTIVE", "DELIVERED")]
    [InlineData("GRACE", "DELIVERED")]
    [InlineData("HOLD", "REFUNDED")]
    [InlineData("CANCELED", "REFUNDED")]
    [InlineData("EXPIRED", "REFUNDED")]
    [InlineData("REVOKED", "REFUNDED")]
    [InlineData("REFUNDED", "REFUNDED")]
    [InlineData("PENDING", "PURCHASE_PENDING")]
    public async Task SendAndRedeem_RespectsPaymentOutcomeAndNeverExtendsTwice(string state, string status)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureServices(services => services.AddSingleton(new ProgressCommercePolicy(true))));
        using var client = app.CreateClient();
        fixture.Driver.Rows[("p_profiles", CanonicalWire.RowId("p_profiles", "bob"))] = new() { ["userId"] = "bob", ["learningZone"] = "UTC" };
        if (state == "GRACE") fixture.Driver.Rows[("p_entitlements", CanonicalWire.RowId("p_entitlements", "bob"))] = new() { ["userId"] = "bob", ["plan"] = "MAX", ["source"] = "PURCHASE", ["status"] = "ACTIVE", ["expiresAt"] = "2026-12-01T00:00:00.000Z", ["autoRenew"] = true, ["revision"] = 0 };
        using var request = Request("/v1/gifts", "alice", new { recipientUserId = "bob", plan = "SUPER", durationDays = 7, note = "Quà 😀", simulationOutcome = state });
        using var response = await client.SendAsync(request);
        var body = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        if (state == "PENDING")
        {
            Assert.Equal("PURCHASE_PENDING", body["error"]!["code"]!.GetValue<string>());
            Assert.Equal(0, fixture.Driver.Commits); return;
        }
        Assert.Equal(HttpStatusCode.OK, response.StatusCode); Assert.Equal(status, body["status"]!.GetValue<string>());
        Assert.Equal("Quà 😀", body["note"]!.GetValue<string>());
        var gift = body["giftId"]!.GetValue<string>();
        using var foreign = Request($"/v1/gifts/{gift}/redeem", "alice", new { });
        using var denied = await client.SendAsync(foreign); Assert.Equal(HttpStatusCode.NotFound, denied.StatusCode);
        for (var i = 0; i < 2; i++)
        {
            using var redeem = Request($"/v1/gifts/{gift}/redeem", "bob", new { }); using var result = await client.SendAsync(redeem);
            Assert.Equal(status == "DELIVERED" ? HttpStatusCode.OK : HttpStatusCode.NotFound, result.StatusCode);
            if (status == "DELIVERED")
            {
                var entitlement = JsonNode.Parse(await result.Content.ReadAsStringAsync())!;
                Assert.Equal(state == "GRACE" ? "PURCHASE" : "GIFT", entitlement["source"]!.GetValue<string>());
                Assert.Equal(state == "GRACE" ? "MAX" : "SUPER", entitlement["plan"]!.GetValue<string>());
                Assert.Equal(state == "GRACE" ? "2026-12-08T00:00:00.000Z" : "2026-11-10T10:00:00.000Z", entitlement["expiresAt"]!.GetValue<string>());
            }
        }
        Assert.Equal(status == "DELIVERED" ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
        Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_purchases");
    }

    [Fact]
    public async Task DefaultHost_KeepsBothSimulationRoutesClosed()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        foreach (var path in new[] { "/v1/gifts", "/v1/gifts/missing/redeem" })
        {
            using var request = Request(path, "alice", new { }); using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        }
        Assert.Equal(0, fixture.Driver.Commits);
    }

    private static HttpRequestMessage Request(string path, string user, object body)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = JsonContent.Create(body) };
        request.Headers.Add("Authorization", "Bearer " + user + "-jwt"); request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString()); return request;
    }
}
