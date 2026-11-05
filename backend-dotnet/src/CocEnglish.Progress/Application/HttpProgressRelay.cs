using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using System.Text.Json;
using System.Text;

namespace CocEnglish.Progress.Application;

public interface IProgressRelayTransport
{
    bool Configured { get; }
    Task<RelayOutcome> DeliverAsync(string target, JsonObject envelope, CancellationToken ct);
}
public sealed class HttpProgressRelay(HttpClient client, IReadOnlyDictionary<string, Uri> targets, ServiceKey? key, TimeProvider clock) : IProgressRelayTransport
{
    public bool Configured => key is { Sender: "progress", Secret.Length: >= 32 };
    public async Task<RelayOutcome> DeliverAsync(string target, JsonObject envelope, CancellationToken ct)
    {
        if (!Configured || !targets.TryGetValue(target, out var endpoint) || !endpoint.IsAbsoluteUri || endpoint.Scheme != "https" ||
            endpoint.UserInfo.Length != 0 || endpoint.Query.Length != 0 || endpoint.Fragment.Length != 0) return RelayOutcome.Retry;
        const string path = "/internal/events";
        var body = CanonicalWire.Stringify(envelope);
        var signature = ServiceHmac.Sign(key!, "POST", path, "", new HashSet<string>(), body, clock.GetUtcNow().ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint.AbsoluteUri.TrimEnd('/') + path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
        request.Headers.Add("X-Request-ID", Guid.NewGuid().ToString());
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            var text = await response.Content.ReadAsStringAsync(timeout.Token);
            string? code = null;
            if (text.Length > 0)
            {
                using var document = JsonDocument.Parse(text);
                if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("error", out var error) &&
                    error.ValueKind == JsonValueKind.Object && error.TryGetProperty("code", out var value) && value.ValueKind == JsonValueKind.String) code = value.GetString();
            }
            var status = (int)response.StatusCode;
            if (status == 200) return RelayOutcome.Ack;
            if (status is 400 or 403 || status == 409 && code == "IDEMPOTENCY_CONFLICT") return RelayOutcome.Dead;
            return RelayOutcome.Retry;
        }
        catch (HttpRequestException) { return RelayOutcome.Retry; }
        catch (JsonException) { return RelayOutcome.Retry; }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { return RelayOutcome.Retry; }
    }
}
