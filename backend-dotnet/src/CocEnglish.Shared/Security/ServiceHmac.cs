using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Shared.Security;

public sealed record ServiceKey(string KeyId, string Sender, byte[] Secret);
public sealed record ServiceSignature(string KeyId, string Timestamp, string Signature);

public static class ServiceHmac
{
    private static readonly HashSet<string> Senders = new(StringComparer.Ordinal) { "learning", "progress", "ai", "maintainer", "scheduler" };
    private static bool Matches(string value, string pattern) => Regex.IsMatch(value, pattern, RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1));

    public static IReadOnlyDictionary<string, ServiceKey> ParseKeyring(string? json)
    {
        var keys = new Dictionary<string, ServiceKey>(StringComparer.Ordinal);
        if (string.IsNullOrEmpty(json)) return keys;
        try
        {
            if (JsonNode.Parse(json) is not JsonArray array) throw new FormatException("INVALID_SERVICE_KEYRING");
            foreach (var entry in array)
            {
                var id = entry?["keyId"]?.GetValue<string>() ?? "";
                var sender = entry?["sender"]?.GetValue<string>() ?? "";
                var hex = entry?["secretHex"]?.GetValue<string>() ?? "";
                if (!Matches(id, "^[A-Za-z0-9._-]{1,64}$") || !Senders.Contains(sender) ||
                    !Matches(hex, "^(?:[0-9a-fA-F]{2}){32,}$")) throw new FormatException("INVALID_SERVICE_KEYRING");
                if (!keys.TryAdd(id, new(id, sender, Convert.FromHexString(hex)))) throw new FormatException("DUPLICATE_SERVICE_KEY_ID");
            }
            return keys;
        }
        catch (Exception e) when (e is System.Text.Json.JsonException or InvalidOperationException or ArgumentException)
        {
            throw new FormatException("INVALID_SERVICE_KEYRING");
        }
    }

    public static ServiceSignature Sign(ServiceKey key, string method, string path, string query, IReadOnlySet<string> allowedQueryKeys, string body, long nowSeconds)
    {
        var timestamp = nowSeconds.ToString(CultureInfo.InvariantCulture);
        var material = Material(timestamp, method, path, query, allowedQueryKeys, body);
        return new(key.KeyId, timestamp, Convert.ToHexStringLower(HMACSHA256.HashData(key.Secret, Encoding.UTF8.GetBytes(material))));
    }

    public static string Verify(IReadOnlyDictionary<string, ServiceKey> keyring, ServiceSignature signature, string method, string path, string query, IReadOnlySet<string> allowedQueryKeys, string body, long nowSeconds, IReadOnlySet<string> senders)
    {
        if (!Matches(signature.KeyId, "^[A-Za-z0-9._-]{1,64}$") ||
            !Matches(signature.Timestamp, "^[1-9][0-9]{0,15}$") ||
            !Matches(signature.Signature, "^[0-9a-f]{64}$") || !keyring.TryGetValue(signature.KeyId, out var key))
            throw new ServiceException("AUTH_REQUIRED");
        if (Math.Abs((double)nowSeconds - double.Parse(signature.Timestamp, CultureInfo.InvariantCulture)) > 300)
            throw new ServiceException("AUTH_EXPIRED");
        var expected = HMACSHA256.HashData(key.Secret, Encoding.UTF8.GetBytes(Material(signature.Timestamp, method, path, query, allowedQueryKeys, body)));
        if (!CryptographicOperations.FixedTimeEquals(expected, Convert.FromHexString(signature.Signature)))
            throw new ServiceException("AUTH_REQUIRED");
        if (!senders.Contains(key.Sender)) throw new ServiceException("FORBIDDEN");
        return key.Sender;
    }

    private static string Material(string timestamp, string method, string path, string query, IReadOnlySet<string> keys, string body) =>
        timestamp + "\n" + method.ToUpperInvariant() + "\n" + CanonicalWire.Path(path) + CanonicalWire.Query(query, keys) + "\n" + CanonicalWire.Sha256(body);
}
