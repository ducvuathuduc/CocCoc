using System.Net;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class AppwriteIdentityVerifierTests
{
    [Fact]
    public async Task VerifyAsync_UsesAccountGetWithJwtAndNeverAnAdminKey()
    {
        var handler = new Handler((request, _) =>
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal("https://appwrite.test/v1/account", request.RequestUri!.AbsoluteUri);
            Assert.Equal("test-project", Assert.Single(request.Headers.GetValues("X-Appwrite-Project")));
            Assert.Equal("a.valid.jwt", Assert.Single(request.Headers.GetValues("X-Appwrite-JWT")));
            Assert.False(request.Headers.Contains("X-Appwrite-Key"));
            return Task.FromResult(Response(HttpStatusCode.OK, "{\"$id\":\"alice\"}"));
        });
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "test-project");
        Assert.Equal("alice", (await verifier.VerifyAsync("a.valid.jwt", CancellationToken.None)).UserId);
        Assert.Equal(1, handler.Calls);
    }

    [Theory]
    [InlineData(401, "user_jwt_invalid", "AUTH_EXPIRED")]
    [InlineData(403, "user_blocked", "ACCOUNT_BLOCKED")]
    [InlineData(403, "user_unauthorized", "AUTH_EXPIRED")]
    public async Task VerifyAsync_ClassifiesRevokedBlockedAndUnauthorized(int status, string type, string code)
    {
        var handler = new Handler((_, _) => Task.FromResult(Response((HttpStatusCode)status, "{\"type\":\"" + type + "\"}")));
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "project");
        Assert.Equal(code, (await Assert.ThrowsAsync<ServiceException>(() => verifier.VerifyAsync("jwt", CancellationToken.None))).Code);
        Assert.Equal(1, handler.Calls);
    }

    [Theory]
    [InlineData(429)]
    [InlineData(500)]
    [InlineData(503)]
    public async Task VerifyAsync_RetriesTransientResponseOnlyOnce(int status)
    {
        var handler = new Handler((_, _) => Task.FromResult(Response((HttpStatusCode)status, "{}")));
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "project");
        Assert.Equal("AUTH_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => verifier.VerifyAsync("jwt", CancellationToken.None))).Code);
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task VerifyAsync_RetriesTransportFailureThenReturnsVerifiedSubject()
    {
        var calls = 0;
        var handler = new Handler((_, _) => ++calls == 1 ? throw new HttpRequestException("sensitive network diagnostic") : Task.FromResult(Response(HttpStatusCode.OK, "{\"$id\":\"alice\"}")));
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "project");
        Assert.Equal("alice", (await verifier.VerifyAsync("jwt", CancellationToken.None)).UserId);
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task VerifyAsync_DeadlineIsBoundedAndCallerCancellationIsNotRetried()
    {
        var handler = new Handler(async (_, token) => { await Task.Delay(Timeout.Infinite, token); return Response(HttpStatusCode.OK, "{}"); });
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "project", TimeSpan.FromMilliseconds(5));
        Assert.Equal("AUTH_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => verifier.VerifyAsync("jwt", CancellationToken.None))).Code);
        Assert.Equal(2, handler.Calls);
        using var canceled = new CancellationTokenSource();
        await canceled.CancelAsync();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => verifier.VerifyAsync("jwt", canceled.Token));
        Assert.Equal(2, handler.Calls);
    }

    [Fact]
    public async Task VerifyAsync_RejectsInvalidSubjectAndUnconfiguredEndpoint()
    {
        var handler = new Handler((_, _) => Task.FromResult(Response(HttpStatusCode.OK, "{\"$id\":\"not/an/id\"}")));
        using var client = new HttpClient(handler);
        var verifier = new AppwriteIdentityVerifier(client, new("https://appwrite.test/v1"), "project");
        Assert.Equal("AUTH_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => verifier.VerifyAsync("jwt", CancellationToken.None))).Code);
        var disabled = new AppwriteIdentityVerifier(client, new("http://untrusted.test/v1"), "project");
        Assert.False(disabled.Configured);
        Assert.Equal("SERVICE_NOT_CONFIGURED", (await Assert.ThrowsAsync<ServiceException>(() => disabled.VerifyAsync("jwt", CancellationToken.None))).Code);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("Basic a.valid.jwt")]
    [InlineData("Bearer invalid token")]
    public void ExtractBearer_RejectsMissingOrMalformedCredentials(string? value) =>
        Assert.Equal("AUTH_REQUIRED", Assert.Throws<ServiceException>(() => AppwriteIdentityVerifier.ExtractBearer(value)).Code);

    [Fact]
    public void ExtractBearer_AcceptsCaseInsensitiveBearerAndRejectsOversizedTokens()
    {
        Assert.Equal("a.valid.jwt", AppwriteIdentityVerifier.ExtractBearer(" bearer a.valid.jwt "));
        Assert.Equal("AUTH_REQUIRED", Assert.Throws<ServiceException>(() => AppwriteIdentityVerifier.ExtractBearer("Bearer " + new string('a', 8193))).Code);
    }

    private static HttpResponseMessage Response(HttpStatusCode status, string body) => new(status) { Content = new StringContent(body) };

    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return send(request, cancellationToken);
        }
    }
}
