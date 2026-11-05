using System.Net;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class RelayHttpTests
{
    private static readonly ServiceKey Key = new("progress-test", "progress", Enumerable.Repeat((byte)17, 32).ToArray());
    [Theory]
    [InlineData(200, "{}", RelayOutcome.Ack)]
    [InlineData(200, "", RelayOutcome.Ack)]
    [InlineData(200, "not-json", RelayOutcome.Retry)]
    [InlineData(400, "{}", RelayOutcome.Dead)]
    [InlineData(403, "{}", RelayOutcome.Dead)]
    [InlineData(409, "{\"error\":{\"code\":\"IDEMPOTENCY_CONFLICT\"}}", RelayOutcome.Dead)]
    [InlineData(409, "{\"error\":{\"code\":\"REVISION_CONFLICT\"}}", RelayOutcome.Retry)]
    [InlineData(401, "{}", RelayOutcome.Retry)]
    [InlineData(429, "{}", RelayOutcome.Retry)]
    [InlineData(503, "{}", RelayOutcome.Retry)]
    [InlineData(403, "not-json", RelayOutcome.Retry)]
    public async Task SignedDelivery_PreservesNodeResponseOutcomeTable(int status, string body, RelayOutcome expected)
    {
        var clock = new Clock(); var envelope = new JsonObject { ["eventId"] = "event", ["payload"] = new JsonObject { ["message"] = "Tiếng Việt 😀" } }; var calls = 0;
        using var client = new HttpClient(new Handler(async (request, token) => {
            calls++; Assert.Equal("https://learning.test/internal/events", request.RequestUri!.AbsoluteUri); Assert.Equal(HttpMethod.Post, request.Method);
            var raw = await request.Content!.ReadAsStringAsync(token); Assert.Equal(CanonicalWire.Stringify(envelope), raw);
            Assert.Equal("application/json", request.Content.Headers.ContentType!.MediaType);
            var signature = new ServiceSignature(request.Headers.GetValues("X-Service-Key-Id").Single(), request.Headers.GetValues("X-Service-Timestamp").Single(), request.Headers.GetValues("X-Service-Signature").Single());
            Assert.Equal("progress", ServiceHmac.Verify(new Dictionary<string, ServiceKey> { [Key.KeyId] = Key }, signature, "POST", "/internal/events", "", new HashSet<string>(), raw, clock.GetUtcNow().ToUnixTimeSeconds(), new HashSet<string> { "progress" }));
            Assert.True(Guid.TryParse(request.Headers.GetValues("X-Request-ID").Single(), out _));
            return new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) };
        }));
        var transport = new HttpProgressRelay(client, new Dictionary<string, Uri> { ["learning"] = new("https://learning.test") }, Key, clock);
        Assert.True(transport.Configured); Assert.Equal(expected, await transport.DeliverAsync("learning", envelope, CancellationToken.None)); Assert.Equal(1, calls);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("http://learning.test")]
    [InlineData("https://user:password@learning.test")]
    [InlineData("https://learning.test?token=private")]
    public async Task MissingOrInvalidTarget_RetriesWithoutCallingNetwork(string? endpoint)
    {
        var calls = 0; using var client = new HttpClient(new Handler((_, _) => { calls++; throw new HttpRequestException(); }));
        var targets = new Dictionary<string, Uri>(); if (endpoint is not null) targets["learning"] = new(endpoint);
        Assert.Equal(RelayOutcome.Retry, await new HttpProgressRelay(client, targets, Key, new Clock()).DeliverAsync("learning", new(), CancellationToken.None)); Assert.Equal(0, calls);
    }
    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T10:00:00Z"); }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct); }
}
