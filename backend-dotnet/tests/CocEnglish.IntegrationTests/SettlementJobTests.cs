using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using CocEnglish.Shared.Persistence;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class SettlementJobTests
{
    private const string Path = "/internal/jobs/league-settlement";
    private const string Body = "{\"tickId\":\"11111111-1111-4111-8111-111111111111\",\"scheduledAt\":\"2026-11-03T10:00:00Z\"}";

    [Fact]
    public async Task HttpWatermarkFailure_RetriesThenClosesWithoutDuplicateEffects()
    {
        await using var fixture = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-10T00:00:00.001Z") };
        var runId = CanonicalWire.RowId("p_league_runs", "2026-11-02", "cohort");
        fixture.Driver.Rows[("p_league_runs", runId)] = new() { ["weekId"] = "2026-11-02", ["cohortId"] = "cohort", ["tier"] = 0, ["stage"] = "LEAGUE", ["status"] = "OPEN", ["snapshotJson"] = "{\"members\":[]}" };
        var handler = new WatermarkHandler();
        using var app = fixture.WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> {
                ["COC_LEARNING_URL"] = "https://learning.test",
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"job-test\",\"sender\":\"scheduler\",\"secretHex\":\"" + new string('1', 64) + "\"},{\"keyId\":\"progress-test\",\"sender\":\"progress\",\"secretHex\":\"" + new string('2', 64) + "\"}]"
            }));
            builder.ConfigureServices(services => services.AddHttpClient("learning-watermark").ConfigurePrimaryHttpMessageHandler(() => handler));
        });
        using var client = app.CreateClient();
        for (var attempt = 0; attempt < 3; attempt++)
        {
            using var request = Signed("scheduler", fixture.Now, Body.Replace("2026-11-03T10:00:00Z", "2026-11-10T00:00:00Z"));
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var report = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
            Assert.Equal(attempt < 2 ? 1 : 0, report["processed"]!.GetValue<int>());
            Assert.Equal(attempt == 1 ? 1 : 0, report["succeeded"]!.GetValue<int>());
            Assert.Equal(attempt == 0 ? 1 : 0, report["retried"]!.GetValue<int>());
            Assert.Equal(attempt == 0, report["needsIntervention"]!.GetValue<bool>());
            Assert.Equal(attempt == 0 ? "SETTLING" : "CLOSED", fixture.Driver.Rows[("p_league_runs", runId)].Text("status"));
        }
        Assert.Equal(3, handler.Calls);
        Assert.DoesNotContain(fixture.Driver.Rows, r => r.Key.Table == "p_reward_ledger");
    }

    private sealed class WatermarkHandler : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Assert.Equal("https://learning.test/internal/outbox-watermark?before=2026-11-09T00%3A00%3A00.000Z", request.RequestUri!.AbsoluteUri);
            Assert.Equal("progress-test", request.Headers.GetValues("X-Service-Key-Id").Single());
            Calls++;
            return Task.FromResult(new HttpResponseMessage(Calls == 1 ? HttpStatusCode.ServiceUnavailable : HttpStatusCode.OK) { Content = new StringContent("{\"pendingBefore\":0}") });
        }
    }

    [Theory]
    [InlineData("scheduler", 200)]
    [InlineData("maintainer", 200)]
    [InlineData("learning", 403)]
    public async Task SignedTick_EnforcesAuthorityAndReportsEmptyWeek(string sender, int status)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        { ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"job-test\",\"sender\":\"" + sender + "\",\"secretHex\":\"" + new string('1', 64) + "\"}]" })));
        using var client = app.CreateClient();
        using var request = Signed(sender, fixture.Now, Body);
        using var response = await client.SendAsync(request);
        Assert.Equal(status, (int)response.StatusCode);
        var json = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        if (status != 200) { Assert.Equal("FORBIDDEN", json["error"]!["code"]!.GetValue<string>()); return; }
        Assert.Equal("LEAGUE_SETTLEMENT", json["job"]!.GetValue<string>());
        Assert.Equal("11111111-1111-4111-8111-111111111111", json["tickId"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", json["startedAt"]!.GetValue<string>());
        Assert.Equal(0, json["processed"]!.GetValue<int>());
        Assert.Equal(0, json["succeeded"]!.GetValue<int>());
        Assert.False(json["needsIntervention"]!.GetValue<bool>());
    }

    [Theory]
    [InlineData("{}", "tickId")]
    [InlineData("{\"extra\":true}", "extra")]
    [InlineData("{\"tickId\":\"11111111-1111-4111-8111-111111111111\",\"scheduledAt\":\"not-a-date\"}", "scheduledAt")]
    [InlineData("{\"tickId\":\"11111111-1111-4111-8111-111111111111\",\"scheduledAt\":\"2026-11-03T10:00:00Z\",\"weekId\":\"2026-02-30\"}", "weekId")]
    public async Task InvalidTick_ReturnsValidationField(string body, string field)
    {
        await using var fixture = new ProgressApiFixture();
        using var app = fixture.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        { ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"job-test\",\"sender\":\"scheduler\",\"secretHex\":\"" + new string('1', 64) + "\"}]" })));
        using var client = app.CreateClient();
        using var request = Signed("scheduler", fixture.Now, body);
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
        Assert.Equal(field, json["error"]!["details"]!["field"]!.GetValue<string>());
        Assert.Equal(0, fixture.Driver.Commits);
    }

    private static HttpRequestMessage Signed(string sender, DateTimeOffset now, string body)
    {
        var key = new ServiceKey("job-test", sender, Convert.FromHexString(new string('1', 64)));
        var signed = ServiceHmac.Sign(key, "POST", Path, "", new HashSet<string>(), body, now.ToUnixTimeSeconds());
        var request = new HttpRequestMessage(HttpMethod.Post, Path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signed.KeyId);
        request.Headers.Add("X-Service-Timestamp", signed.Timestamp);
        request.Headers.Add("X-Service-Signature", signed.Signature);
        return request;
    }
}
