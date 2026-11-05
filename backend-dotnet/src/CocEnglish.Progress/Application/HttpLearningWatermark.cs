using CocEnglish.Shared.Security;
using CocEnglish.Shared.Persistence;
using System.Net;
using System.Text.Json;

namespace CocEnglish.Progress.Application;

public sealed class HttpLearningWatermark(HttpClient client, Uri? baseUrl, ServiceKey? key, TimeProvider clock) : ILearningWatermark
{
    public async Task<long> PendingBeforeAsync(DateTimeOffset cutoff, CancellationToken ct)
    {
        if (baseUrl is null || !baseUrl.IsAbsoluteUri || baseUrl.Scheme != "https" ||
            baseUrl.UserInfo.Length != 0 || baseUrl.Query.Length != 0 || baseUrl.Fragment.Length != 0 ||
            key is null || key.Sender != "progress" || key.Secret.Length < 32)
            throw new InvalidOperationException("WATERMARK_NOT_CONFIGURED");

        const string path = "/internal/outbox-watermark";
        var query = "before=" + Uri.EscapeDataString(OwnerSchema.Iso(cutoff));
        var signature = ServiceHmac.Sign(key, "GET", path, query, new HashSet<string> { "before" }, "", clock.GetUtcNow().ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Get, baseUrl.AbsoluteUri.TrimEnd('/') + path + "?" + query);
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        request.Headers.Add("X-Request-ID", Guid.NewGuid().ToString());
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            if (response.StatusCode != HttpStatusCode.OK) throw new InvalidOperationException("WATERMARK_UNAVAILABLE");
            await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: timeout.Token);
            if (document.RootElement.ValueKind != JsonValueKind.Object ||
                !document.RootElement.TryGetProperty("pendingBefore", out var value) ||
                value.ValueKind != JsonValueKind.Number || !value.TryGetDouble(out var number) ||
                !double.IsFinite(number) || Math.Truncate(number) != number || number < long.MinValue || number >= 9223372036854775808d)
                throw new InvalidOperationException("WATERMARK_UNAVAILABLE");
            return (long)number;
        }
        catch (JsonException) { throw new InvalidOperationException("WATERMARK_UNAVAILABLE"); }
        catch (HttpRequestException) { throw new InvalidOperationException("WATERMARK_UNAVAILABLE"); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        { throw new InvalidOperationException("WATERMARK_UNAVAILABLE"); }
    }
}
