using CocEnglish.Progress.Application;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using Microsoft.AspNetCore.Hosting;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Configuration;
using System.Text;

namespace CocEnglish.IntegrationTests;

public sealed class BillingSimulationTests
{
    [Theory]
    [InlineData("maintainer", true, 200)]
    [InlineData("maintainer", false, 503)]
    [InlineData("scheduler", true, 403)]
    public async Task HttpNotification_RequiresMaintainerAndSimulationComposition(string sender, bool simulation, int expected)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => {
            builder.ConfigureServices(services => services.AddSingleton(new ProgressCommercePolicy(simulation)));
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"billing-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('3', 64) + "\"}]"
            }));
        });
        using var client = app.CreateClient();
        using var scope = app.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var purchase = await store.TransactAsync((tx, ct) => new ProgressBilling().VerifyAsync(tx, "alice", "gems_500", "GEMS", "ACTIVE", "key", ct));
        fixture.Now = fixture.Now.AddMinutes(1);
        var body = new JsonObject { ["notificationId"] = "refund", ["purchaseId"] = purchase.PurchaseId, ["platform"] = "SIMULATION", ["state"] = "REFUNDED", ["occurredAt"] = OwnerSchema.Iso(fixture.Now) }.ToJsonString();
        const string path = "/internal/billing/notifications";
        for (var i = 0; i < 2; i++)
        {
            var key = new ServiceKey("billing-test", sender, Convert.FromHexString(new string('3', 64)));
            var signature = ServiceHmac.Sign(key, "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request);
            Assert.Equal(expected, (int)response.StatusCode);
            if (expected == 200) Assert.Equal(i == 0 ? "accepted" : "replayed", JsonNode.Parse(await response.Content.ReadAsStringAsync())!["status"]!.GetValue<string>());
        }
        Assert.Equal(expected == 200 ? 0 : 500, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        Assert.Equal(expected == 200 ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_inbox"));
    }

    [Theory]
    [InlineData("2027-02-30T24:00:00.000Z", "2027-03-03T00:00:00.000Z")]
    [InlineData("2027-01-01T00:00:00.123456Z", "2027-01-01T00:00:00.123Z")]
    [InlineData("2027-01-01T00:00:00+23:59", "2026-12-31T00:01:00.000Z")]
    public async Task HttpNotification_NormalizesLikeJavaScriptDateParse(string occurredAt, string expectedUtc)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services => services.AddSingleton(new ProgressCommercePolicy(true)));
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"billing-test\",\"sender\":\"maintainer\",\"secretHex\":\"" + new string('3', 64) + "\"}]"
            }));
        });
        using var client = app.CreateClient();
        using var scope = app.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var purchase = await store.TransactAsync((tx, ct) => new ProgressBilling().VerifyAsync(tx, "alice", "super_monthly", "SUBSCRIPTION", "ACTIVE", "key", ct));
        const string path = "/internal/billing/notifications";
        var body = new JsonObject
        {
            ["notificationId"] = "overflow-date",
            ["purchaseId"] = purchase.PurchaseId,
            ["platform"] = "SIMULATION",
            ["state"] = "CANCELED",
            ["occurredAt"] = occurredAt
        }.ToJsonString();
        var key = new ServiceKey("billing-test", "maintainer", Enumerable.Repeat((byte)0x33, 32).ToArray());
        var signature = ServiceHmac.Sign(key, "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);

        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var responseBody = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal("accepted", responseBody["status"]!.GetValue<string>());
        var row = fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", purchase.PurchaseId))];
        Assert.Equal("CANCELED", row.Text("state"));
        Assert.Equal(expectedUtc, JsonNode.Parse(row.Text("vendorStateJson")!)!["lastOccurredAt"]!.GetValue<string>());
    }

    [Theory]
    [InlineData("2027-13-01T00:00:00Z")]
    [InlineData("2027-02-32T00:00:00Z")]
    [InlineData("2027-01-01T24:00:00.001Z")]
    [InlineData("2027-01-01T23:59:60Z")]
    [InlineData("2027-01-01T00:00:00+24:00")]
    public async Task Notification_RejectsValuesJavascriptDateParseRejects(string occurredAt)
    {
        await using var fixture = new ProgressApiFixture();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();

        var error = await Assert.ThrowsAsync<ServiceException>(() => new ProgressBilling().NotifyAsync(
            store, "invalid-date", "missing-purchase", "CANCELED", occurredAt, "hash", CancellationToken.None));

        Assert.Equal("VALIDATION_ERROR", error.Code);
        Assert.DoesNotContain(fixture.Driver.Rows, row => row.Key.Table == "p_inbox");
    }

    [Fact]
    public async Task Notification_AdvancesSameStateTimestampAndIgnoresEqualOrOlderEvents()
    {
        await using var fixture = new ProgressApiFixture();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var billing = new ProgressBilling();
        var purchase = await store.TransactAsync((tx, ct) => billing.VerifyAsync(tx, "alice", "super_monthly", "SUBSCRIPTION", "ACTIVE", "ordering", ct));
        var purchaseRowId = CanonicalWire.RowId("p_purchases", purchase.PurchaseId);
        var original = fixture.Driver.Rows[("p_purchases", purchaseRowId)];
        var originalVerifiedAt = original.Text("verifiedAt");
        var originalOutboxCount = fixture.Driver.Rows.Count(row => row.Key.Table == "p_outbox");
        var newer = fixture.Now.AddMinutes(2);

        await billing.NotifyAsync(store, "newer-active", purchase.PurchaseId, "ACTIVE", OwnerSchema.Iso(newer), "hash-new", CancellationToken.None);
        var advanced = fixture.Driver.Rows[("p_purchases", purchaseRowId)];
        Assert.Equal("newer-active", advanced.Text("lastNotificationId"));
        Assert.Equal(OwnerSchema.Iso(newer), JsonNode.Parse(advanced.Text("vendorStateJson")!)!["lastOccurredAt"]!.GetValue<string>());
        Assert.Equal(originalVerifiedAt, advanced.Text("verifiedAt"));
        Assert.Equal(originalOutboxCount, fixture.Driver.Rows.Count(row => row.Key.Table == "p_outbox"));

        await billing.NotifyAsync(store, "equal-canceled", purchase.PurchaseId, "CANCELED", OwnerSchema.Iso(newer), "hash-equal", CancellationToken.None);
        await billing.NotifyAsync(store, "older-canceled", purchase.PurchaseId, "CANCELED", OwnerSchema.Iso(newer.AddMinutes(-1)), "hash-older", CancellationToken.None);

        var final = fixture.Driver.Rows[("p_purchases", purchaseRowId)];
        Assert.Equal("ACTIVE", final.Text("state"));
        Assert.Equal("newer-active", final.Text("lastNotificationId"));
        Assert.Equal(OwnerSchema.Iso(newer), JsonNode.Parse(final.Text("vendorStateJson")!)!["lastOccurredAt"]!.GetValue<string>());
        Assert.Equal(originalVerifiedAt, final.Text("verifiedAt"));
        Assert.Equal(originalOutboxCount, fixture.Driver.Rows.Count(row => row.Key.Table == "p_outbox"));
    }

    [Theory]
    [InlineData(false, 503)]
    [InlineData(true, 200)]
    public async Task HttpVerification_DefaultsClosedAndExplicitTestCompositionReplaysReceipt(bool simulation, int expected)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureServices(services => services.AddSingleton(new ProgressCommercePolicy(simulation))));
        using var client = app.CreateClient();
        var key = Guid.NewGuid().ToString();
        string? previous = null;
        for (var i = 0; i < 2; i++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/billing/purchases") { Content = JsonContent.Create(new { productId = "gems_500", kind = "GEMS", platform = "SIMULATION", simulationOutcome = "ACTIVE" }) };
            request.Headers.Add("Authorization", "Bearer alice-jwt"); request.Headers.Add("Idempotency-Key", key);
            using var response = await client.SendAsync(request);
            Assert.Equal(expected, (int)response.StatusCode);
            var text = await response.Content.ReadAsStringAsync();
            if (simulation)
            {
                Assert.Equal(500, JsonNode.Parse(text)!["gems"]!.GetValue<long>());
                if (previous is not null) Assert.Equal(previous, text);
                previous = text;
            }
        }
        Assert.Equal(simulation ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_purchases"));
        Assert.Equal(simulation ? 1 : 0, fixture.Driver.Rows.Count(r => r.Key.Table == "p_reward_ledger"));
    }

    [Theory]
    [InlineData("PENDING", "FREE", "ACTIVE", false)]
    [InlineData("ACTIVE", "MAX", "ACTIVE", true)]
    [InlineData("GRACE", "MAX", "GRACE", true)]
    [InlineData("HOLD", "FREE", "EXPIRED", false)]
    [InlineData("CANCELED", "FREE", "EXPIRED", false)]
    [InlineData("EXPIRED", "FREE", "EXPIRED", false)]
    [InlineData("REVOKED", "FREE", "EXPIRED", false)]
    [InlineData("REFUNDED", "FREE", "EXPIRED", false)]
    public async Task Subscription_VerificationPreservesStateAndEffectiveAccess(string state, string plan, string status, bool active)
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var service = new ProgressBilling();
        var response = await store.TransactAsync((tx, ct) => service.VerifyAsync(tx, "alice", "max_monthly", "SUBSCRIPTION", state, "key", ct));
        Assert.Equal(state, response.State); Assert.Equal(plan, response.Entitlement.Plan); Assert.Equal(status, response.Entitlement.Status);
        Assert.Equal(active, response.Entitlement.UnlimitedEnergy); Assert.Equal(active, response.Entitlement.Conversations);
        Assert.Equal(state == "PENDING" ? null : fixture.Now, response.VerifiedAt);
        Assert.Equal(state == "PENDING" ? 0 : 1, fixture.Driver.Rows.Count(r => r.Key.Table == "p_outbox"));
    }

    [Fact]
    public async Task Gems_NotificationDeduplicationRefundClampsBalanceAndTerminalStateStaysClosed()
    {
        await using var fixture = new ProgressApiFixture(); using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope(); var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        var service = new ProgressBilling();
        var response = await store.TransactAsync((tx, ct) => service.VerifyAsync(tx, "alice", "gems_500", "GEMS", "ACTIVE", "key", ct));
        Assert.Equal(500, response.Gems);
        fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))]["gems"] = 7;
        fixture.Now = fixture.Now.AddMinutes(1);
        var time = OwnerSchema.Iso(fixture.Now);
        Assert.Equal("accepted", await service.NotifyAsync(store, "refund1", response.PurchaseId, "REFUNDED", time, "hash", CancellationToken.None));
        Assert.Equal("replayed", await service.NotifyAsync(store, "refund1", response.PurchaseId, "REFUNDED", time, "hash", CancellationToken.None));
        var conflict = await Assert.ThrowsAsync<ServiceException>(() => service.NotifyAsync(store, "refund1", response.PurchaseId, "ACTIVE", time, "other", CancellationToken.None));
        Assert.Equal("IDEMPOTENCY_CONFLICT", conflict.Code);
        await service.NotifyAsync(store, "late", response.PurchaseId, "ACTIVE", OwnerSchema.Iso(fixture.Now.AddMinutes(1)), "late-hash", CancellationToken.None);
        Assert.Equal(0, fixture.Driver.Rows[("p_rewards", CanonicalWire.RowId("p_rewards", "alice"))].Number("gems"));
        Assert.Equal("REFUNDED", fixture.Driver.Rows[("p_purchases", CanonicalWire.RowId("p_purchases", response.PurchaseId))].Text("state"));
        var refunds = Assert.Single(fixture.Driver.Rows, r => r.Key.Table == "p_reward_ledger" && r.Value.Text("kind") == "REFUND").Value;
        Assert.Equal(-7, refunds.Number("gemsDelta"));
    }
}
