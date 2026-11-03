using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.Shared.Hosting;

public sealed record RuntimeSettings(string Service, string BuildId, Uri? Endpoint, string? ProjectId, AppwriteConnection? Storage,
    bool Admitted, IReadOnlyDictionary<string, ServiceKey> Keyring, IReadOnlySet<string> CorsOrigins)
{
    public static RuntimeSettings From(IConfiguration config, string service)
    {
        var upper = service.ToUpperInvariant();
        Uri.TryCreate(config["APPWRITE_ENDPOINT"], UriKind.Absolute, out var endpoint);
        var project = config["APPWRITE_PROJECT_ID"];
        var key = config[$"COC_{upper}_APPWRITE_KEY"] ?? config["APPWRITE_API_KEY"];
        var storage = config[$"COC_{upper}_PERSISTENCE"] == "appwrite" && endpoint is { Scheme: "https" } &&
                      !string.IsNullOrEmpty(project) && !string.IsNullOrEmpty(key)
            ? new AppwriteConnection(endpoint, project, key, config["COC_DATABASE_ID"] ?? "cocenglish") : null;
        IReadOnlyDictionary<string, ServiceKey> ring;
        try { ring = ServiceHmac.ParseKeyring(config["COC_SERVICE_KEYS"]); }
        catch (FormatException) { ring = new Dictionary<string, ServiceKey>(); }
        var origins = (config["COC_CORS_ALLOWED_ORIGINS"] ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        var build = config["BUILD_ID"] ?? "local-scaffold";
        return new(service, build[..Math.Min(build.Length, 64)], endpoint, project, storage,
            storage is not null && config[$"COC_{upper}_ADMITTED"] == "reviewed-cloud-gate", ring,
            (origins.Length == 0 ? ["http://localhost:8087", "http://127.0.0.1:8087"] : origins).ToHashSet(StringComparer.Ordinal));
    }
}
