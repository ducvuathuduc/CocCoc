using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;

namespace CocEnglish.Learning;

/// <summary>Signed Learning-to-Progress event delivery using the existing HMAC wire contract.</summary>
public sealed class HttpLearningRelay(HttpClient client, Uri? progressUrl, ServiceKey? key, TimeProvider clock) : ILearningRelayTransport
{
    public bool Configured => ValidEndpoint(progressUrl) && key is { Sender: "learning", Secret.Length: >= 32 };

    public async Task<LearningRelayOutcome> DeliverAsync(JsonObject envelope, CancellationToken ct)
    {
        if (!Configured) return LearningRelayOutcome.Retry;
        const string path = "/internal/events";
        var body = CanonicalWire.Stringify(envelope);
        var signature = ServiceHmac.Sign(key!, "POST", path, "", new HashSet<string>(), body, clock.GetUtcNow().ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, progressUrl!.AbsoluteUri.TrimEnd('/') + path)
        { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        request.Headers.Add("X-Request-ID", Guid.NewGuid().ToString());
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            var text = await response.Content.ReadAsStringAsync(timeout.Token);
            string? code = null;
            if (text.Length > 0)
            {
                using var document = JsonDocument.Parse(text);
                if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("error", out var error) &&
                    error.ValueKind == JsonValueKind.Object && error.TryGetProperty("code", out var value) && value.ValueKind == JsonValueKind.String)
                    code = value.GetString();
            }
            var status = (int)response.StatusCode;
            if (status == (int)HttpStatusCode.OK) return LearningRelayOutcome.Ack;
            if (status is 400 or 403 || status == 409 && code == "IDEMPOTENCY_CONFLICT") return LearningRelayOutcome.Dead;
            return LearningRelayOutcome.Retry;
        }
        catch (HttpRequestException) { return LearningRelayOutcome.Retry; }
        catch (JsonException) { return LearningRelayOutcome.Retry; }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { return LearningRelayOutcome.Retry; }
    }

    private static bool ValidEndpoint(Uri? endpoint) => endpoint is { IsAbsoluteUri: true, Scheme: "https" } &&
        endpoint.UserInfo.Length == 0 && endpoint.Query.Length == 0 && endpoint.Fragment.Length == 0;
}
