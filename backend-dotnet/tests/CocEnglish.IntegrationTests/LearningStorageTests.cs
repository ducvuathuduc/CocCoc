using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using System.Net;
using System.Text;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningStorageTests
{
    [Theory]
    [InlineData(200, "{\"title\":\"Tiếng Việt\"}")]
    [InlineData(404, null)]
    public async Task Read_UsesLearningBucketAndDistinguishesMissingFile(int status, string? expected)
    {
        using var client = new HttpClient(new Handler((request, _) => {
            Assert.Equal("/v1/storage/buckets/learning-assets/files/file1/download", request.RequestUri!.AbsolutePath);
            Assert.Equal("project", request.Headers.GetValues("X-Appwrite-Project").Single()); Assert.Equal("test-key", request.Headers.GetValues("X-Appwrite-Key").Single());
            return Task.FromResult(new HttpResponseMessage((HttpStatusCode)status) { Content = new StringContent(expected ?? "missing", Encoding.UTF8, "application/json") });
        }));
        Assert.Equal(expected, await new LearningStorageFiles(client, new(new("https://appwrite.test/v1"), "project", "test-key")).ReadAsync("file1", CancellationToken.None));
    }

    [Fact]
    public async Task Read_ReportsUnavailableWithoutLeakingCredential()
    {
        using var client = new HttpClient(new Handler((_, _) => throw new HttpRequestException("test-key")));
        var error = await Assert.ThrowsAsync<ServiceException>(() => new LearningStorageFiles(client, new(new("https://appwrite.test/v1"), "project", "test-key")).ReadAsync("file1", CancellationToken.None));
        Assert.Equal("STORAGE_UNAVAILABLE", error.Code); Assert.DoesNotContain("test-key", error.ToString());
    }
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    { protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => send(request, ct); }
}
