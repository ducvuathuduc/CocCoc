using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Http;

namespace CocEnglish.Progress.Endpoints;

/// <summary>Preserves the Progress Node offset cursor and limit contract.</summary>
internal static class ProgressPaging
{
    public static (int Offset, int Limit) Parse(HttpRequest request)
    {
        var query = RequestQuery.Parse(request, "cursor", "limit");
        var limit = 20;
        if (query.TryGetValue("limit", out var rawLimit))
        {
            if (!Regex.IsMatch(rawLimit, "^[0-9]{1,3}$", RegexOptions.CultureInvariant)) throw RequestQuery.Bad("limit");
            limit = int.Parse(rawLimit, CultureInfo.InvariantCulture);
            if (limit is < 1 or > 100) throw RequestQuery.Bad("limit");
        }
        if (!query.TryGetValue("cursor", out var cursor) || cursor.Length == 0) return (0, limit);
        if (cursor.Length > 256) throw RequestQuery.Bad("cursor");
        try
        {
            // Buffer.from(base64url) accepts either alphabet, padding and ignored characters.
            var filtered = new string(cursor.TakeWhile(c => c != '=').Where(c => char.IsAsciiLetterOrDigit(c) || c is '+' or '/' or '-' or '_').ToArray())
                .Replace('-', '+').Replace('_', '/');
            if (filtered.Length % 4 == 1) filtered = filtered[..^1];
            filtered = filtered.PadRight((filtered.Length + 3) / 4 * 4, '=');
            using var document = JsonDocument.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(filtered)));
            if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("o", out var value)
                && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var offset)
                && offset >= 0 && offset < 100000 && Math.Truncate(offset) == offset)
                return ((int)offset, limit);
        }
        catch (Exception error) when (error is FormatException or JsonException) { }
        throw RequestQuery.Bad("cursor");
    }
}
