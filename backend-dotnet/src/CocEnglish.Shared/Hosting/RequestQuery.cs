using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Http;

namespace CocEnglish.Shared.Hosting;

public static class RequestQuery
{
    public static IReadOnlyDictionary<string, string> Parse(HttpRequest request, params string[] allowed)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        var raw = request.QueryString.Value?.TrimStart('?') ?? "";
        if (raw.Length == 0) return result;
        foreach (var part in raw.Split('&'))
        {
            if (part.Length == 0) throw Bad("query");
            var index = part.IndexOf('=');
            string key, value;
            try
            {
                key = CanonicalWire.Decode(index < 0 ? part : part[..index]);
                value = CanonicalWire.Decode(index < 0 ? "" : part[(index + 1)..].Replace('+', ' '));
            }
            catch (ServiceException) { throw Bad("query"); }
            if (!allowed.Contains(key, StringComparer.Ordinal) || !result.TryAdd(key, value)) throw Bad(key);
        }
        return result;
    }

    public static ServiceException Bad(string field) => new("VALIDATION_ERROR", new() { ["field"] = field });
}
