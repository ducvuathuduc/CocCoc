using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.Configuration;

namespace CocEnglish.Shared.Hosting;

public sealed record RuntimeSettings(string Service, string BuildId, Uri? Endpoint, string? ProjectId, AppwriteConnection? Storage,
    bool Admitted, IReadOnlyDictionary<string, ServiceKey> Keyring, IReadOnlySet<string> CorsOrigins,
    bool AcceptanceGatesReviewed = false, string? ActiveSigningKeyId = null)
{
    private static readonly string[] RequiredAcceptanceGates =
    [
        "durable-owner-storage",
        "mixed-node-dotnet-event-boundaries",
        "all-dotnet-docker",
        "flutter-native-end-to-end",
        "one-writer-cutover-and-rollback"
    ];

    public bool ReadinessAdmitted => Admitted && AcceptanceGatesReviewed;

    public ServiceKey? SigningKey(string sender)
    {
        if (!string.IsNullOrWhiteSpace(ActiveSigningKeyId))
            return Keyring.TryGetValue(ActiveSigningKeyId, out var selected) && selected.Sender == sender ? selected : null;

        ServiceKey? only = null;
        foreach (var candidate in Keyring.Values)
        {
            if (candidate.Sender != sender) continue;
            if (only is not null) return null;
            only = candidate;
        }
        return only;
    }

    public static RuntimeSettings From(IConfiguration config, string service)
    {
        var upper = service.ToUpperInvariant();
        Uri.TryCreate(config["APPWRITE_ENDPOINT"], UriKind.Absolute, out var endpoint);
        var project = config["APPWRITE_PROJECT_ID"];
        var ownerKey = config[$"COC_{upper}_APPWRITE_KEY"];
        // A shared project key is convenient for a local Development host, but it
        // defeats owner-level credential isolation in Staging/Production. Live probe
        // runners configure APPWRITE_API_KEY directly and do not use this host path.
        var sharedDevelopmentKey = string.Equals(config["ASPNETCORE_ENVIRONMENT"], "Development", StringComparison.OrdinalIgnoreCase)
            ? config["APPWRITE_API_KEY"] : null;
        var key = ownerKey ?? sharedDevelopmentKey;
        var storage = config[$"COC_{upper}_PERSISTENCE"] == "appwrite" && endpoint is { Scheme: "https" } &&
                      !string.IsNullOrWhiteSpace(project) && !string.IsNullOrWhiteSpace(key)
            ? new AppwriteConnection(endpoint, project, key, config["COC_DATABASE_ID"] ?? "cocenglish") : null;
        IReadOnlyDictionary<string, ServiceKey> ring;
        try { ring = ServiceHmac.ParseKeyring(config["COC_SERVICE_KEYS"]); }
        catch (FormatException) { ring = new Dictionary<string, ServiceKey>(); }
        var origins = (config["COC_CORS_ALLOWED_ORIGINS"] ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        var build = config["BUILD_ID"] ?? "local-scaffold";
        var readinessGates = (config[$"COC_{upper}_READINESS_GATES"] ?? "")
            .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        var acceptanceGatesReviewed = readinessGates.Length == RequiredAcceptanceGates.Length &&
            readinessGates.Distinct(StringComparer.Ordinal).Count() == RequiredAcceptanceGates.Length &&
            RequiredAcceptanceGates.All(required => readinessGates.Contains(required, StringComparer.Ordinal));
        return new(service, build[..Math.Min(build.Length, 64)], endpoint, project, storage,
            storage is not null && config[$"COC_{upper}_ADMITTED"] == "reviewed-cloud-gate", ring,
            (origins.Length == 0 ? ["http://localhost:8087", "http://127.0.0.1:8087"] : origins).ToHashSet(StringComparer.Ordinal),
            acceptanceGatesReviewed, config[$"COC_{upper}_SIGNING_KEY_ID"]);
    }
}
