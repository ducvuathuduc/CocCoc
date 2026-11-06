using System.Net;
using System.Text;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

/// <summary>Reads immutable published content from the Appwrite learning-assets bucket.</summary>
public sealed class LearningStorageFiles(HttpClient client, AppwriteConnection connection)
{
    private const string BucketId = "learning-assets";

    public async Task<string?> ReadAsync(string fileId, CancellationToken cancellationToken)
    {
        if (connection.Endpoint.Scheme is not ("https" or "http") ||
            string.IsNullOrWhiteSpace(connection.ProjectId) || string.IsNullOrWhiteSpace(connection.ApiKey))
            throw new ServiceException("STORAGE_UNAVAILABLE");

        var endpoint = new UriBuilder(connection.Endpoint)
        {
            Path = connection.Endpoint.AbsolutePath.TrimEnd('/') + "/storage/buckets/" +
                   CanonicalWire.Encode(BucketId) + "/files/" + CanonicalWire.Encode(fileId) + "/download",
            Query = "",
            Fragment = ""
        }.Uri;

        using var request = new HttpRequestMessage(HttpMethod.Get, endpoint);
        request.Headers.TryAddWithoutValidation("X-Appwrite-Project", connection.ProjectId);
        request.Headers.TryAddWithoutValidation("X-Appwrite-Key", connection.ApiKey);

        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (response.StatusCode == HttpStatusCode.NotFound) return null;
            if (!response.IsSuccessStatusCode) throw new ServiceException("STORAGE_UNAVAILABLE");
            var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
            return Encoding.UTF8.GetString(bytes);
        }
        catch (HttpRequestException)
        {
            throw new ServiceException("STORAGE_UNAVAILABLE");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new ServiceException("STORAGE_UNAVAILABLE");
        }
    }
}
