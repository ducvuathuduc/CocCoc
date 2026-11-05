using System.Net;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class WatermarkTests
{
    private static readonly ServiceKey Key = new("progress-test", "progress", Enumerable.Repeat((byte)17, 32).ToArray());
    [Fact]
    public async Task Request_SignsExactGetPathQueryAndEmptyBody()
    {
        var clock = new Clock();
        using var client = new HttpClient(new Handler((request, cancellationToken) =>
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal("https://learning.test/internal/outbox-watermark?before=2026-11-09T00%3A00%3A00.000Z", request.RequestUri!.AbsoluteUri);
            Assert.Null(request.Content);
            var signature = new ServiceSignature(request.Headers.GetValues("X-Service-Key-Id").Single(), request.Headers.GetValues("X-Service-Timestamp").Single(), request.Headers.GetValues("X-Service-Signature").Single());
            Assert.Equal("progress", ServiceHmac.Verify(new Dictionary<string, ServiceKey> { [Key.KeyId] = Key }, signature, "GET", "/internal/outbox-watermark", request.RequestUri.Query,
                new HashSet<string> { "before" }, "", clock.GetUtcNow().ToUnixTimeSeconds(), new HashSet<string> { "progress" }));
            Assert.True(Guid.TryParse(request.Headers.GetValues("X-Request-ID").Single(), out _));
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{\"pendingBefore\":3}") });
        }));
        Assert.Equal(3, await new HttpLearningWatermark(client, new("https://learning.test/"), Key, clock).PendingBeforeAsync(DateTimeOffset.Parse("2026-11-09T00:00:00Z"), CancellationToken.None));
    }

    [Theory]
    [InlineData(503, "{\"pendingBefore\":0}")]
    [InlineData(200, "{\"pendingBefore\":\"0\"}")]
    [InlineData(200, "{\"pendingBefore\":1.5}")]
    [InlineData(200, "{}")]
    [InlineData(200, "null")]
    [InlineData(200, "not-json")]
    public async Task InvalidResponse_NeverBecomesZeroWatermark(int status, string body)
    {
        var calls = 0;
        using var client = new HttpClient(new Handler((_, _) => { calls++; return Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) }); }));
        await Assert.ThrowsAsync<InvalidOperationException>(() => new HttpLearningWatermark(client, new("https://learning.test"), Key, new Clock()).PendingBeforeAsync(DateTimeOffset.UtcNow, CancellationToken.None));
        Assert.Equal(1, calls);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("http://learning.test")]
    [InlineData("https://user:password@learning.test")]
    [InlineData("https://learning.test?secret=x")]
    public async Task InvalidConfiguration_DoesNotCallNetwork(string? endpoint)
    {
        using var client = new HttpClient(new Handler((_, _) => throw new InvalidOperationException("Network must not be called")));
        var failure = await Assert.ThrowsAsync<InvalidOperationException>(() => new HttpLearningWatermark(client, endpoint is null ? null : new(endpoint), Key, new Clock()).PendingBeforeAsync(DateTimeOffset.UtcNow, CancellationToken.None));
        Assert.Equal("WATERMARK_NOT_CONFIGURED", failure.Message);
    }

    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-09T00:00:00Z"); }

    [Fact]
    public async Task TransportFailure_IsUnavailableWithoutLeakingEndpoint()
    {
        using var client = new HttpClient(new Handler((_, _) => throw new HttpRequestException("private endpoint details")));
        var failure = await Assert.ThrowsAsync<InvalidOperationException>(() => new HttpLearningWatermark(client, new("https://learning.test"), Key, new Clock()).PendingBeforeAsync(DateTimeOffset.UtcNow, CancellationToken.None));
        Assert.Equal("WATERMARK_UNAVAILABLE", failure.Message);
        Assert.Null(failure.InnerException);
    }

    [Fact]
    public async Task CallerCancellation_PropagatesInsteadOfBecomingWatermarkFailure()
    {
        using var cancellation = new CancellationTokenSource();
        using var client = new HttpClient(new Handler(async (_, token) =>
        {
            cancellation.Cancel();
            await Task.Delay(Timeout.Infinite, token);
            return new HttpResponseMessage(HttpStatusCode.OK);
        }));
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => new HttpLearningWatermark(client, new("https://learning.test"), Key, new Clock()).PendingBeforeAsync(DateTimeOffset.UtcNow, cancellation.Token));
        Assert.True(cancellation.IsCancellationRequested);
    }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct); }
}
