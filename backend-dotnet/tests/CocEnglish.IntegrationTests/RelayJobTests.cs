using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class RelayJobTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task SignedJob_RetriesUntilEveryTargetAcknowledgesOrFailsClosedWithoutKey(bool configured)
    {
        await using var fixture = new ProgressApiFixture(); var handler = new Receiver();
        using var app = fixture.WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?> {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"scheduler-test\",\"sender\":\"scheduler\",\"secretHex\":\"" + new string('6', 64) + "\"}" +
                    (configured ? ",{\"keyId\":\"progress-test\",\"sender\":\"progress\",\"secretHex\":\"" + new string('7', 64) + "\"}" : "") + "]",
                ["COC_LEARNING_URL"] = "https://learning.test", ["COC_AI_URL"] = "https://ai.test"
            }));
            builder.ConfigureServices(services => services.AddHttpClient("progress-relay").ConfigurePrimaryHttpMessageHandler(() => handler));
        });
        using var client = app.CreateClient();
        var eventId = Guid.NewGuid().ToString(); var id = CanonicalWire.RowId("p_outbox", eventId);
        fixture.Driver.Rows[("p_outbox", id)] = new() { ["eventId"] = eventId, ["type"] = "account.deleted.v1", ["schemaVersion"] = 1, ["aggregateId"] = "alice", ["occurredAt"] = OwnerSchema.Iso(fixture.Now),
            ["payloadJson"] = "{\"userId\":\"alice\"}", ["attempt"] = 0, ["nextAttemptAt"] = OwnerSchema.Iso(fixture.Now), ["leaseOwner"] = null, ["leaseUntil"] = null, ["status"] = "PENDING", ["ackAt"] = null, ["revision"] = 0 };
        for (var i = 0; i < 3; i++)
        {
            if (i == 1) { fixture.Now = fixture.Now.AddSeconds(3); handler.Healthy = true; }
            const string path = "/internal/jobs/progress-outbox-relay";
            var body = new JsonObject { ["tickId"] = "11111111-1111-4111-8111-111111111111", ["scheduledAt"] = OwnerSchema.Iso(fixture.Now) }.ToJsonString();
            var signature = ServiceHmac.Sign(new("scheduler-test", "scheduler", Convert.FromHexString(new string('6', 64))), "POST", path, "", new HashSet<string>(), body, fixture.Now.ToUnixTimeSeconds());
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            using var response = await client.SendAsync(request);
            Assert.Equal(configured ? HttpStatusCode.OK : HttpStatusCode.ServiceUnavailable, response.StatusCode);
            if (configured)
            {
                var report = JsonNode.Parse(await response.Content.ReadAsStringAsync())!;
                Assert.Equal(i < 2 ? 1 : 0, report["processed"]!.GetValue<int>()); Assert.Equal(i == 0 ? 1 : 0, report["retried"]!.GetValue<int>()); Assert.Equal(i == 1 ? 1 : 0, report["succeeded"]!.GetValue<int>());
            }
        }
        Assert.Equal(configured ? 4 : 0, handler.Targets.Count);
        if (configured) Assert.Equal(new[] { "learning.test", "ai.test", "learning.test", "ai.test" }, handler.Targets);
        Assert.Equal(configured ? "ACK" : "PENDING", fixture.Driver.Rows[("p_outbox", id)].Text("status"));
        Assert.Equal(configured ? 1 : 0, fixture.Driver.Rows[("p_outbox", id)].Number("attempt"));
    }

    private sealed class Receiver : HttpMessageHandler
    {
        public List<string> Targets { get; } = []; public bool Healthy { get; set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Targets.Add(request.RequestUri!.Host); Assert.Equal("/internal/events", request.RequestUri.AbsolutePath);
            Assert.Equal("progress-test", request.Headers.GetValues("X-Service-Key-Id").Single());
            return Task.FromResult(new HttpResponseMessage(request.RequestUri.Host == "ai.test" && !Healthy ? HttpStatusCode.ServiceUnavailable : HttpStatusCode.OK) { Content = new StringContent("{}") });
        }
    }
}
