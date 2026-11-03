using System.Text.Json;

namespace CocEnglish.Shared.Hosting;

public static class ServiceProbe
{
    public static async Task<int> CheckAsync(HttpClient client, string service, CancellationToken ct = default)
    {
        try
        {
            using var response = await client.GetAsync("http://127.0.0.1:8080/health", ct);
            if (!response.IsSuccessStatusCode) return 1;
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            var root = body.RootElement;
            return root.ValueKind == JsonValueKind.Object && root.TryGetProperty("service", out var owner) && owner.ValueKind == JsonValueKind.String && owner.GetString() == service
                && root.TryGetProperty("status", out var status) && status.ValueKind == JsonValueKind.String && status.GetString() is "ok" or "degraded" ? 0 : 1;
        }
        catch (Exception error) when (error is HttpRequestException or JsonException || error is OperationCanceledException && !ct.IsCancellationRequested) { return 1; }
    }
}
