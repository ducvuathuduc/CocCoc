using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using System.Text;
using System.Text.Json;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Crypto.Signers;

namespace CocEnglish.Learning;

public static class LearningIntegrity
{
    public static string StructureInput(JsonObject manifest) => Omit(manifest, ["bundles", "placementBundle", "manifestHash", "signature", "signatureKeyId"]);
    public static string StructureHash(JsonObject manifest) => CanonicalWire.Sha256(StructureInput(manifest));
    public static string SigningInput(JsonObject document) => Omit(document, ["signature", "signatureKeyId"]);
    public static IReadOnlyDictionary<string, byte[]> ParseKeyring(string? raw)
    {
        var keys = new Dictionary<string, byte[]>(StringComparer.Ordinal);
        if (string.IsNullOrEmpty(raw)) return keys;
        try
        {
            using var json = JsonDocument.Parse(raw);
            if (json.RootElement.ValueKind != JsonValueKind.Array) throw new FormatException("INVALID_CONTENT_KEYRING");
            foreach (var entry in json.RootElement.EnumerateArray())
            {
                if (entry.ValueKind != JsonValueKind.Object || !entry.TryGetProperty("keyId", out var id) || id.ValueKind != JsonValueKind.String ||
                    !entry.TryGetProperty("publicKeyHex", out var hex) || hex.ValueKind != JsonValueKind.String)
                    throw new FormatException("INVALID_CONTENT_KEYRING");
                var value = hex.GetString()!;
                if (value.Length != 64) throw new FormatException("CONTENT_PUBLIC_KEY_FORMAT");
                keys[id.GetString()!] = Convert.FromHexString(value);
            }
            return keys;
        }
        catch (JsonException) { throw new FormatException("INVALID_CONTENT_KEYRING"); }
    }

    public static bool VerifyManifest(IReadOnlyDictionary<string, byte[]> keys, JsonObject manifest) =>
        StringField(manifest, "manifestHash") == StructureHash(manifest) && VerifyBundle(keys, manifest);

    public static bool VerifyBundle(IReadOnlyDictionary<string, byte[]> keys, JsonObject bundle)
    {
        var key = StringField(bundle, "signatureKeyId"); var signature = StringField(bundle, "signature");
        return key is not null && signature is not null && VerifyText(keys, key, SigningInput(bundle), signature);
    }

    private static string? StringField(JsonObject document, string field) =>
        document[field] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
    public static bool VerifyText(IReadOnlyDictionary<string, byte[]> keys, string keyId, string text, string signature)
    {
        if (!keys.TryGetValue(keyId, out var key) || key.Length != 32 || signature.Length != 86 ||
            signature.Any(c => !(c is >= 'A' and <= 'Z' or >= 'a' and <= 'z' or >= '0' and <= '9' or '-' or '_'))) return false;
        try
        {
            var bytes = Convert.FromBase64String(signature.Replace('-', '+').Replace('_', '/') + "==");
            var signer = new Ed25519Signer();
            signer.Init(false, new Ed25519PublicKeyParameters(key, 0));
            var message = Encoding.UTF8.GetBytes(text);
            signer.BlockUpdate(message, 0, message.Length);
            return signer.VerifySignature(bytes);
        }
        catch (Exception e) when (e is FormatException or ArgumentException) { return false; }
    }
    private static string Omit(JsonObject source, string[] keys)
    {
        var copy = source.DeepClone().AsObject();
        foreach (var key in keys) copy.Remove(key);
        return CanonicalWire.Json(copy);
    }
}
