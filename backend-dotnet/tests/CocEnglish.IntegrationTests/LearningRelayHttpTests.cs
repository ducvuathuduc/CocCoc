using System.Net;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningRelayHttpTests
{
    private static readonly ServiceKey Key = new("learning-test", "learning", Enumerable.Repeat((byte)17, 32).ToArray());

    [Theory]
    [InlineData(200, "{}", LearningRelayOutcome.Ack)]
    [InlineData(200, "", LearningRelayOutcome.Ack)]
    [InlineData(200, "not-json", LearningRelayOutcome.Retry)]
    [InlineData(400, "{}", LearningRelayOutcome.Dead)]
    [InlineData(403, "{}", LearningRelayOutcome.Dead)]
    [InlineData(409, "{\"error\":{\"code\":\"IDEMPOTENCY_CONFLICT\"}}", LearningRelayOutcome.Dead)]
    [InlineData(409, "{\"error\":{\"code\":\"REVISION_CONFLICT\"}}", LearningRelayOutcome.Retry)]
    [InlineData(401, "{}", LearningRelayOutcome.Retry)]
    [InlineData(429, "{}", LearningRelayOutcome.Retry)]
    [InlineData(503, "{}", LearningRelayOutcome.Retry)]
    [InlineData(403, "not-json", LearningRelayOutcome.Retry)]
    public async Task SignedDelivery_PreservesNodeResponseOutcomeTable(int status, string body, LearningRelayOutcome expected)
    {
        var clock = new Clock(); var envelope = new JsonObject { ["eventId"] = "event", ["payload"] = new JsonObject { ["message"] = "Tiếng Việt 😀" } }; var calls = 0;
        using var client = new HttpClient(new Handler(async (request, token) => {
            calls++; Assert.Equal("https://progress.test/internal/events", request.RequestUri!.AbsoluteUri); Assert.Equal(HttpMethod.Post, request.Method);
            var raw = await request.Content!.ReadAsStringAsync(token); Assert.Equal(CanonicalWire.Stringify(envelope), raw);
            Assert.Equal("application/json", request.Content.Headers.ContentType!.MediaType);
            var signature = new ServiceSignature(request.Headers.GetValues("X-Service-Key-Id").Single(), request.Headers.GetValues("X-Service-Timestamp").Single(), request.Headers.GetValues("X-Service-Signature").Single());
            Assert.Equal("learning", ServiceHmac.Verify(new Dictionary<string, ServiceKey> { [Key.KeyId] = Key }, signature, "POST", "/internal/events", "", new HashSet<string>(), raw, clock.GetUtcNow().ToUnixTimeSeconds(), new HashSet<string> { "learning" }));
            Assert.True(Guid.TryParse(request.Headers.GetValues("X-Request-ID").Single(), out _));
            return new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) };
        }));
        var transport = new HttpLearningRelay(client, new("https://progress.test"), Key, clock);
        Assert.True(transport.Configured); Assert.Equal(expected, await transport.DeliverAsync(envelope, CancellationToken.None)); Assert.Equal(1, calls);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("http://progress.test")]
    [InlineData("https://user:password@progress.test")]
    [InlineData("https://progress.test?token=private")]
    public async Task MissingOrInvalidTarget_RetriesWithoutCallingNetwork(string? endpoint)
    {
        var calls = 0; using var client = new HttpClient(new Handler((_, _) => { calls++; throw new HttpRequestException(); }));
        Assert.Equal(LearningRelayOutcome.Retry, await new HttpLearningRelay(client, endpoint is null ? null : new(endpoint), Key, new Clock()).DeliverAsync(new(), CancellationToken.None));
        Assert.Equal(0, calls);
    }

    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T10:00:00Z"); }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct); }
}
