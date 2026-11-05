using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using CocEnglish.Learning;
using CocEnglish.Shared.Persistence;
using Xunit;

namespace CocEnglish.IntegrationTests;

/// <summary>Opt-in cloud probes for the published learning-assets bucket.</summary>
public sealed class AppwriteStorageLiveTests
{
    private const string Bucket = "learning-assets";

    [AppwriteLiveFact]
    [Trait("Category", "AppwriteLive")]
    public async Task LearningAssetFile_RoundTripsThroughAppwriteAndIsDeleted()
    {
        var connection = AppwriteStorageLiveConfiguration.FromEnvironment();
        var fileId = "dn_" + Guid.NewGuid().ToString("N");
        var fileName = "probe-" + Guid.NewGuid().ToString("N") + ".txt";
        var payload = Encoding.UTF8.GetBytes("cocenglish-storage-probe-" + Guid.NewGuid().ToString("N"));
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        using var adminClient = NewClient();
        using var downloadClient = NewClient();
        Assert.Equal(Encoding.UTF8.GetString(payload), await RunRoundTripAsync(
            adminClient, downloadClient, connection, fileId, fileName, payload, deadline.Token));
    }

    internal static async Task<string?> RunRoundTripAsync(HttpClient adminClient, HttpClient downloadClient,
        AppwriteConnection connection, string fileId, string fileName, byte[] payload, CancellationToken cancellationToken)
    {
        var uploadAttempted = false;
        try
        {
            if (await FileExistsAsync(adminClient, connection, fileId, cancellationToken))
                throw new InvalidOperationException("The generated probe ID already exists; refusing to overwrite it.");

            uploadAttempted = true;
            await UploadAsync(adminClient, connection, fileId, fileName, payload, cancellationToken);

            var storage = new LearningStorageFiles(downloadClient, connection);
            return await storage.ReadAsync(fileId, cancellationToken);
        }
        finally
        {
            if (uploadAttempted)
                await DeleteOwnedFileAsync(adminClient, connection, fileId, fileName);
        }
    }

    private static HttpClient NewClient() => new() { Timeout = TimeSpan.FromSeconds(20) };

    private static async Task UploadAsync(HttpClient client, AppwriteConnection connection, string fileId,
        string fileName, byte[] payload, CancellationToken cancellationToken)
    {
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent(fileId), "fileId");
        var fileContent = new ByteArrayContent(payload);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
        form.Add(fileContent, "file", fileName);

        using var request = CreateRequest(HttpMethod.Post, FileCollectionUri(connection), connection);
        request.Content = form;
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (response.StatusCode != HttpStatusCode.Created)
            throw new InvalidOperationException($"Appwrite Storage upload failed with HTTP {(int)response.StatusCode}; response body omitted.");
    }

    private static async Task<bool> FileExistsAsync(HttpClient client, AppwriteConnection connection,
        string fileId, CancellationToken cancellationToken)
    {
        using var request = CreateRequest(HttpMethod.Get, FileUri(connection, fileId), connection);
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound) return false;
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"Appwrite Storage metadata check failed with HTTP {(int)response.StatusCode}; response body omitted.");
        return true;
    }

    private static async Task DeleteOwnedFileAsync(HttpClient client, AppwriteConnection connection,
        string fileId, string expectedName)
    {
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        using var metadataRequest = CreateRequest(HttpMethod.Get, FileUri(connection, fileId), connection);
        using var metadataResponse = await client.SendAsync(metadataRequest, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
        if (metadataResponse.StatusCode == HttpStatusCode.NotFound) return;
        if (!metadataResponse.IsSuccessStatusCode)
            throw new InvalidOperationException($"Appwrite Storage cleanup inspection failed with HTTP {(int)metadataResponse.StatusCode}; file was left untouched.");

        await using var responseStream = await metadataResponse.Content.ReadAsStreamAsync(deadline.Token);
        using var metadata = await JsonDocument.ParseAsync(responseStream, cancellationToken: deadline.Token);
        var root = metadata.RootElement;
        if (!root.TryGetProperty("$id", out var storedId) || storedId.GetString() != fileId ||
            !root.TryGetProperty("name", out var storedName) || storedName.GetString() != expectedName)
            throw new InvalidOperationException("Appwrite Storage cleanup refused a file without the probe ID and name markers.");

        using var deleteRequest = CreateRequest(HttpMethod.Delete, FileUri(connection, fileId), connection);
        using var deleteResponse = await client.SendAsync(deleteRequest, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
        if (deleteResponse.StatusCode != HttpStatusCode.NoContent)
            throw new InvalidOperationException($"Appwrite Storage cleanup failed with HTTP {(int)deleteResponse.StatusCode}; response body omitted.");

        using var verificationRequest = CreateRequest(HttpMethod.Get, FileUri(connection, fileId), connection);
        using var verificationResponse = await client.SendAsync(verificationRequest, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
        if (verificationResponse.StatusCode != HttpStatusCode.NotFound)
            throw new InvalidOperationException("Appwrite Storage cleanup could not confirm that the probe file was removed.");
    }

    private static HttpRequestMessage CreateRequest(HttpMethod method, Uri uri, AppwriteConnection connection)
    {
        var request = new HttpRequestMessage(method, uri);
        request.Headers.TryAddWithoutValidation("X-Appwrite-Project", connection.ProjectId);
        request.Headers.TryAddWithoutValidation("X-Appwrite-Key", connection.ApiKey);
        return request;
    }

    private static Uri FileCollectionUri(AppwriteConnection connection) => BuildUri(connection,
        $"/storage/buckets/{Uri.EscapeDataString(Bucket)}/files");

    private static Uri FileUri(AppwriteConnection connection, string fileId) => BuildUri(connection,
        $"/storage/buckets/{Uri.EscapeDataString(Bucket)}/files/{Uri.EscapeDataString(fileId)}");

    private static Uri BuildUri(AppwriteConnection connection, string route) => new UriBuilder(connection.Endpoint)
    {
        Path = connection.Endpoint.AbsolutePath.TrimEnd('/') + route,
        Query = "",
        Fragment = ""
    }.Uri;
}

public sealed class AppwriteStorageProbeTests
{
    [Fact]
    public async Task RunRoundTrip_UploadsDownloadsAndDeletesOnlyTheMarkedFile()
    {
        const string fileId = "dn_probe_file";
        const string fileName = "probe-marker.txt";
        const string payloadText = "synthetic-storage-payload";
        var payload = Encoding.UTF8.GetBytes(payloadText);
        var connection = new AppwriteConnection(new Uri("https://appwrite.test/v1"), "test-project", "synthetic-key");
        var collectionPath = "/v1/storage/buckets/learning-assets/files";
        var filePath = collectionPath + "/" + fileId;
        var downloadPath = filePath + "/download";
        var metadataReads = 0;
        var uploadCount = 0;
        var deleteCount = 0;

        using var adminClient = new HttpClient(new Handler(async (request, cancellationToken) =>
        {
            Assert.Equal("test-project", request.Headers.GetValues("X-Appwrite-Project").Single());
            Assert.Equal("synthetic-key", request.Headers.GetValues("X-Appwrite-Key").Single());
            Assert.Equal("appwrite.test", request.RequestUri!.Host);

            if (request.Method == HttpMethod.Get && request.RequestUri.AbsolutePath == filePath)
            {
                metadataReads++;
                if (metadataReads == 2)
                {
                    var body = JsonSerializer.Serialize(new Dictionary<string, string>
                    {
                        ["$id"] = fileId,
                        ["name"] = fileName
                    });
                    return new(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
                }
                return new(HttpStatusCode.NotFound);
            }

            if (request.Method == HttpMethod.Post && request.RequestUri.AbsolutePath == collectionPath)
            {
                uploadCount++;
                Assert.Equal("multipart/form-data", request.Content!.Headers.ContentType!.MediaType);
                var multipart = await request.Content!.ReadAsStringAsync(cancellationToken);
                Assert.Contains(fileId, multipart, StringComparison.Ordinal);
                Assert.Contains(fileName, multipart, StringComparison.Ordinal);
                Assert.Contains(payloadText, multipart, StringComparison.Ordinal);
                return new(HttpStatusCode.Created);
            }

            if (request.Method == HttpMethod.Delete && request.RequestUri.AbsolutePath == filePath)
            {
                deleteCount++;
                return new(HttpStatusCode.NoContent);
            }

            throw new InvalidOperationException($"Unexpected admin request: {request.Method} {request.RequestUri.AbsolutePath}");
        }));

        using var downloadClient = new HttpClient(new Handler((request, _) =>
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal(downloadPath, request.RequestUri!.AbsolutePath);
            Assert.Equal("test-project", request.Headers.GetValues("X-Appwrite-Project").Single());
            Assert.Equal("synthetic-key", request.Headers.GetValues("X-Appwrite-Key").Single());
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(payload) });
        }));

        var result = await AppwriteStorageLiveTests.RunRoundTripAsync(adminClient, downloadClient,
            connection, fileId, fileName, payload, CancellationToken.None);

        Assert.Equal(payloadText, result);
        Assert.Equal(3, metadataReads);
        Assert.Equal(1, uploadCount);
        Assert.Equal(1, deleteCount);
    }

    [Fact]
    public async Task RunRoundTrip_DoesNotDeleteFileWhenCleanupMarkersDoNotMatch()
    {
        const string fileId = "dn_probe_file";
        const string fileName = "probe-marker.txt";
        const string payloadText = "synthetic-storage-payload";
        var payload = Encoding.UTF8.GetBytes(payloadText);
        var connection = new AppwriteConnection(new Uri("https://appwrite.test/v1"), "test-project", "synthetic-key");
        var collectionPath = "/v1/storage/buckets/learning-assets/files";
        var filePath = collectionPath + "/" + fileId;
        var metadataReads = 0;
        var uploadCount = 0;
        var deleteCount = 0;

        using var adminClient = new HttpClient(new Handler((request, _) =>
        {
            if (request.Method == HttpMethod.Get && request.RequestUri!.AbsolutePath == filePath)
            {
                metadataReads++;
                if (metadataReads == 1) return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
                var body = JsonSerializer.Serialize(new Dictionary<string, string>
                {
                    ["$id"] = fileId,
                    ["name"] = "unexpected-file.txt"
                });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(body, Encoding.UTF8, "application/json")
                });
            }

            if (request.Method == HttpMethod.Post && request.RequestUri!.AbsolutePath == collectionPath)
            {
                uploadCount++;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.Created));
            }

            if (request.Method == HttpMethod.Delete && request.RequestUri!.AbsolutePath == filePath)
            {
                deleteCount++;
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NoContent));
            }

            throw new InvalidOperationException($"Unexpected admin request: {request.Method} {request.RequestUri!.AbsolutePath}");
        }));

        using var downloadClient = new HttpClient(new Handler((request, _) =>
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.EndsWith("/download", request.RequestUri!.AbsolutePath, StringComparison.Ordinal);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(payload) });
        }));

        await Assert.ThrowsAsync<InvalidOperationException>(() => AppwriteStorageLiveTests.RunRoundTripAsync(
            adminClient, downloadClient, connection, fileId, fileName, payload, CancellationToken.None));

        Assert.Equal(2, metadataReads);
        Assert.Equal(1, uploadCount);
        Assert.Equal(0, deleteCount);
    }

    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => send(request, cancellationToken);
    }
}

public sealed class AppwriteLiveFactAttribute : FactAttribute
{
    public AppwriteLiveFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("COC_DOTNET_APPWRITE_LIVE") != "1")
            Skip = "Live Appwrite probe is disabled; requires explicit test-project admission and credentials.";
    }
}

internal static class AppwriteStorageLiveConfiguration
{
    public static AppwriteConnection FromEnvironment() => Create(Environment.GetEnvironmentVariable);

    internal static AppwriteConnection Create(Func<string, string?> read)
    {
        var endpoint = read("APPWRITE_ENDPOINT");
        var projectId = read("APPWRITE_PROJECT_ID");
        var apiKey = read("APPWRITE_API_KEY");
        if (read("COC_DOTNET_APPWRITE_LIVE") != "1" ||
            read("APPWRITE_PROJECT_ENV") != "test" ||
            read("ALLOW_LIVE_PROBE") != "reviewed-test-project" ||
            endpoint != "https://sgp.cloud.appwrite.io/v1" ||
            projectId != "6acc656d0025cc57bd81" ||
            read("COC_DATABASE_ID") is not (null or "cocenglish") ||
            string.IsNullOrWhiteSpace(apiKey))
            throw new InvalidOperationException("Live probe requires explicit admission, the selected coccoc-test project and local server credentials. Configuration values are withheld.");

        return new(new Uri(endpoint!), projectId!, apiKey, "cocenglish");
    }
}

public sealed class AppwriteStorageLiveConfigurationTests
{
    [Theory]
    [InlineData("COC_DOTNET_APPWRITE_LIVE", null)]
    [InlineData("APPWRITE_PROJECT_ENV", "production")]
    [InlineData("ALLOW_LIVE_PROBE", null)]
    [InlineData("APPWRITE_ENDPOINT", "https://other.example/v1")]
    [InlineData("APPWRITE_PROJECT_ID", "another-project")]
    [InlineData("COC_DATABASE_ID", "another-database")]
    [InlineData("APPWRITE_API_KEY", " ")]
    public void Create_RefusesMissingAdmissionOrWrongTarget(string key, string? value)
    {
        var values = Valid();
        values[key] = value;
        var error = Assert.Throws<InvalidOperationException>(() => AppwriteStorageLiveConfiguration.Create(name => values.GetValueOrDefault(name)));
        Assert.DoesNotContain("synthetic-probe-key", error.Message);
    }

    [Fact]
    public void Create_AcceptsOnlySelectedTestProjectAndRedactsCredentials()
    {
        var connection = AppwriteStorageLiveConfiguration.Create(name => Valid().GetValueOrDefault(name));
        Assert.Equal("6acc656d0025cc57bd81", connection.ProjectId);
        Assert.Equal("https://sgp.cloud.appwrite.io/v1", connection.Endpoint.AbsoluteUri);
        Assert.Equal("cocenglish", connection.DatabaseId);
        Assert.DoesNotContain("synthetic-probe-key", connection.ToString());
    }

    private static Dictionary<string, string?> Valid() => new()
    {
        ["COC_DOTNET_APPWRITE_LIVE"] = "1", ["APPWRITE_PROJECT_ENV"] = "test",
        ["ALLOW_LIVE_PROBE"] = "reviewed-test-project", ["APPWRITE_ENDPOINT"] = "https://sgp.cloud.appwrite.io/v1",
        ["APPWRITE_PROJECT_ID"] = "6acc656d0025cc57bd81", ["APPWRITE_API_KEY"] = "synthetic-probe-key"
    };
}
