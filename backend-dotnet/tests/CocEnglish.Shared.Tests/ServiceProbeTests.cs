using System.Net;
using CocEnglish.Shared.Hosting;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class ServiceProbeTests
{
    [Theory]
    [InlineData(200, "{\"service\":\"progress\",\"status\":\"degraded\"}", 0)]
    [InlineData(200, "{\"service\":\"progress\",\"status\":\"ok\"}", 0)]
    [InlineData(503, "{\"service\":\"progress\",\"status\":\"degraded\"}", 1)]
    [InlineData(200, "{\"service\":\"learning\",\"status\":\"ok\"}", 1)]
    [InlineData(200, "{\"service\":\"progress\",\"status\":\"broken\"}", 1)]
    [InlineData(200, "[]", 1)]
    [InlineData(200, "not-json", 1)]
    public async Task Check_ValidatesOwnLivenessWithoutClaimingReadiness(int status, string body, int expected)
    {
        using var client = new HttpClient(new Handler((request, _) =>
        {
            Assert.Equal("http://127.0.0.1:8080/health", request.RequestUri!.AbsoluteUri);
            Assert.Equal(HttpMethod.Get, request.Method);
            return Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(body) });
        }));
        Assert.Equal(expected, await ServiceProbe.CheckAsync(client, "progress"));
    }

    [Fact]
    public async Task Check_TransportFailureFailsProbeButCallerCancellationPropagates()
    {
        using var failed = new HttpClient(new Handler((_, _) => throw new HttpRequestException("offline")));
        Assert.Equal(1, await ServiceProbe.CheckAsync(failed, "progress"));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        using var client = new HttpClient(new Handler((_, ct) => Task.FromCanceled<HttpResponseMessage>(ct)));
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => ServiceProbe.CheckAsync(client, "progress", cancellation.Token));
    }

    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct);
    }
}
