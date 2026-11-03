using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Shared.Security;

public static class CanonicalWire
{
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    public static string Sha256(string text) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text)));
    public static string BodyHash(JsonNode? value) => Sha256(Json(value));
    public static string RowId(string table, params string[] parts) => Sha256(string.Join('|', new[] { table }.Concat(parts)))[..32];

    /// <summary>Matches JSON.parse duplicate-key semantics before validation and receipt hashing.</summary>
    public static JsonNode? ParseBody(string json)
    {
        using var document = JsonDocument.Parse(json);
        return Materialize(document.RootElement);
        static JsonNode? Materialize(JsonElement value)
        {
            if (value.ValueKind == JsonValueKind.Object)
            {
                var result = new JsonObject();
                foreach (var property in value.EnumerateObject()) result[property.Name] = Materialize(property.Value);
                return result;
            }
            if (value.ValueKind == JsonValueKind.Array) return new JsonArray(value.EnumerateArray().Select(Materialize).ToArray());
            return JsonNode.Parse(value.GetRawText());
        }
    }

    /// <summary>Matches the existing sorted-key JavaScript canonical JSON, including Unicode and numeric formatting.</summary>
    public static string Json(JsonNode? value) => Serialize(value, true);
    public static string Stringify(JsonNode? value) => Serialize(value, false);
    private static string Serialize(JsonNode? value, bool sortKeys) => value switch
    {
        null => "null",
        JsonObject obj => "{" + string.Join(',', (sortKeys ? obj.OrderBy(p => p.Key, StringComparer.Ordinal) : obj.AsEnumerable()).Select(p => Quote(p.Key) + ":" + Serialize(p.Value, sortKeys))) + "}",
        JsonArray array => "[" + string.Join(',', array.Select(v => Serialize(v, sortKeys))) + "]",
        _ => Scalar(value)
    };

    private static string Scalar(JsonNode value)
    {
        using var document = JsonDocument.Parse(value.ToJsonString());
        var element = document.RootElement;
        return element.ValueKind switch
        {
            JsonValueKind.String => Quote(element.GetString()!),
            JsonValueKind.Number => JsNumber(element.GetDouble()),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            JsonValueKind.Null => "null",
            _ => throw new ServiceException("VALIDATION_ERROR")
        };
    }

    public static string Quote(string text)
    {
        var output = new StringBuilder("\"");
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            switch (c)
            {
                case '"': output.Append("\\\""); break;
                case '\\': output.Append("\\\\"); break;
                case '\b': output.Append("\\b"); break;
                case '\f': output.Append("\\f"); break;
                case '\n': output.Append("\\n"); break;
                case '\r': output.Append("\\r"); break;
                case '\t': output.Append("\\t"); break;
                default:
                    if (c < 0x20 || char.IsSurrogate(c) &&
                        !(char.IsHighSurrogate(c) && i + 1 < text.Length && char.IsLowSurrogate(text[i + 1])) &&
                        !(char.IsLowSurrogate(c) && i > 0 && char.IsHighSurrogate(text[i - 1])))
                        output.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                    else output.Append(c);
                    break;
            }
        }
        return output.Append('"').ToString();
    }

    private static string JsNumber(double value)
    {
        if (!double.IsFinite(value)) return "null";
        if (value == 0) return "0";
        var negative = value < 0;
        var text = Math.Abs(value).ToString("R", CultureInfo.InvariantCulture);
        var parts = text.Split(['E', 'e']);
        var exponent = parts.Length == 2 ? int.Parse(parts[1], CultureInfo.InvariantCulture) : 0;
        var decimalPoint = parts[0].IndexOf('.');
        var digits = parts[0].Replace(".", "", StringComparison.Ordinal);
        var point = (decimalPoint >= 0 ? decimalPoint : parts[0].Length) + exponent;
        while (digits.Length > 1 && digits[0] == '0') { digits = digits[1..]; point--; }
        digits = digits.TrimEnd('0');
        var sign = negative ? "-" : "";
        if (point > 0 && point <= 21)
            return sign + (point >= digits.Length ? digits.PadRight(point, '0') : digits.Insert(point, "."));
        if (point <= 0 && point > -6) return sign + "0." + new string('0', -point) + digits;
        var scientific = point - 1;
        return sign + digits[0] + (digits.Length > 1 ? "." + digits[1..] : "") + "e" +
            (scientific >= 0 ? "+" : "") + scientific.ToString(CultureInfo.InvariantCulture);
    }

    public static string Path(string path)
    {
        if (!path.StartsWith('/')) throw new ServiceException("VALIDATION_ERROR");
        if (path == "/") return path;
        return "/" + string.Join('/', path[1..].Split('/').Select(segment =>
        {
            var decoded = Decode(segment);
            if (decoded is "" or "." or ".." || decoded.Contains('/')) throw new ServiceException("VALIDATION_ERROR");
            return Encode(decoded);
        }));
    }

    public static string Query(string query, IReadOnlySet<string> allowed)
    {
        var raw = query.StartsWith('?') ? query[1..] : query;
        if (raw.Length == 0) return "";
        var values = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (var part in raw.Split('&'))
        {
            if (part.Length == 0) throw new ServiceException("VALIDATION_ERROR");
            var index = part.IndexOf('=');
            var key = Decode(index < 0 ? part : part[..index]);
            if (!allowed.Contains(key) || !values.TryAdd(key, index < 0 ? "" : Decode(part[(index + 1)..])))
                throw new ServiceException("VALIDATION_ERROR");
        }
        return "?" + string.Join('&', values.Select(p => Encode(p.Key) + "=" + Encode(p.Value)));
    }

    public static string Encode(string text)
    {
        try
        {
            var output = new StringBuilder();
            foreach (var b in StrictUtf8.GetBytes(text))
            {
                if (b is >= (byte)'A' and <= (byte)'Z' or >= (byte)'a' and <= (byte)'z' or
                    >= (byte)'0' and <= (byte)'9' or (byte)'-' or (byte)'_' or (byte)'.' or (byte)'~') output.Append((char)b);
                else output.Append('%').Append(b.ToString("X2", CultureInfo.InvariantCulture));
            }
            return output.ToString();
        }
        catch (EncoderFallbackException) { throw new ServiceException("VALIDATION_ERROR"); }
    }

    public static string Decode(string raw)
    {
        var output = new StringBuilder();
        try
        {
            for (var i = 0; i < raw.Length; i++)
            {
                if (raw[i] != '%') { output.Append(raw[i]); continue; }
                var bytes = new List<byte>();
                while (i < raw.Length && raw[i] == '%')
                {
                    if (i + 2 >= raw.Length || !byte.TryParse(raw.AsSpan(i + 1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var b))
                        throw new ServiceException("VALIDATION_ERROR");
                    bytes.Add(b); i += 3;
                }
                output.Append(StrictUtf8.GetString(bytes.ToArray())); i--;
            }
            return output.ToString();
        }
        catch (DecoderFallbackException) { throw new ServiceException("VALIDATION_ERROR"); }
    }
}
