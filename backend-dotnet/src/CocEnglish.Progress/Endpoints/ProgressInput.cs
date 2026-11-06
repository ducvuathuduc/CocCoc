using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Hosting;

namespace CocEnglish.Progress.Endpoints;

internal static class ProgressInput
{
    public static void Empty(HttpContext context)
    {
        if (context.Items[typeof(ParsedRequestBody)] is ParsedRequestBody { Raw.Length: 0 } parsed)
            context.Items[typeof(ParsedRequestBody)] = parsed with { Value = new JsonObject() };
        Object(context, []);
    }

    public static JsonObject Object(HttpContext context, string[] allowed, params string[] required)
    {
        if ((context.Items[typeof(ParsedRequestBody)] as ParsedRequestBody)?.Value is not JsonObject body) throw RequestQuery.Bad("body");
        foreach (var field in body.Select(p => p.Key)) if (!allowed.Contains(field, StringComparer.Ordinal)) throw RequestQuery.Bad(field);
        foreach (var field in required) if (!body.ContainsKey(field)) throw RequestQuery.Bad(field);
        return body;
    }

    public static long Integer(JsonNode? value, string field, long min, long max)
    {
        if (value?.GetValueKind() != JsonValueKind.Number) throw RequestQuery.Bad(field);
        var number = value.GetValue<double>();
        if (!double.IsFinite(number) || Math.Truncate(number) != number || number < min || number > max) throw RequestQuery.Bad(field);
        return (long)number;
    }

    public static bool Boolean(JsonNode? value, string field)
    {
        if (value?.GetValueKind() is not (JsonValueKind.True or JsonValueKind.False)) throw RequestQuery.Bad(field);
        return value.GetValue<bool>();
    }

    public static string Text(JsonNode? value, string field, int min, int max, string? pattern = null)
    {
        if (value?.GetValueKind() != JsonValueKind.String) throw RequestQuery.Bad(field);
        var text = value.GetValue<string>();
        if (text.Length < min || text.Length > max || pattern is not null && !Regex.IsMatch(text, pattern, RegexOptions.CultureInvariant)) throw RequestQuery.Bad(field);
        return text;
    }
}
