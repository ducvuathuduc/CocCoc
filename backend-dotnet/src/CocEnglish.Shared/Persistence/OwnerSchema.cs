using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.Json;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Shared.Persistence;

public static class OwnerSchema
{
    private static readonly IReadOnlyDictionary<string, JsonObject> Tables = Load();
    private static IReadOnlyDictionary<string, JsonObject> Load()
    {
        using var stream = typeof(OwnerSchema).Assembly.GetManifestResourceStream("CocEnglish.StorageSchema.json")!;
        return JsonNode.Parse(stream)!["tables"]!.AsArray().Select(v => v!.AsObject())
            .ToDictionary(v => v["id"]!.GetValue<string>(), StringComparer.Ordinal);
    }

    public static JsonObject For(string owner, string table)
    {
        if (!Tables.TryGetValue(table, out var definition) || definition["owner"]!.GetValue<string>() != owner)
            throw new ServiceException("FORBIDDEN", new() { ["table"] = table });
        return definition;
    }

    public static bool IsMutable(string owner, string table) => For(owner, table)["mutable"]!.GetValue<bool>();
    public static bool HasColumn(string owner, string table, string key) => For(owner, table)["columns"]!.AsArray().Any(c => c!["key"]!.GetValue<string>() == key);
    public static string Iso(DateTimeOffset value) => value.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture);

    public static JsonObject Normalize(string owner, string table, JsonObject raw)
    {
        var dates = For(owner, table)["columns"]!.AsArray().Where(c => c!["type"]!.GetValue<string>() == "datetime")
            .Select(c => c!["key"]!.GetValue<string>()).ToHashSet(StringComparer.Ordinal);
        var output = new JsonObject();
        foreach (var (key, value) in raw)
        {
            if (key.StartsWith('$')) continue;
            output[key] = dates.Contains(key) && value is not null
                ? JsonValue.Create(Iso(DateTimeOffset.Parse(value.GetValue<string>(), CultureInfo.InvariantCulture)))
                : value?.DeepClone();
        }
        return output;
    }

    public static void Validate(string owner, string table, JsonObject row)
    {
        var columns = For(owner, table)["columns"]!.AsArray().ToDictionary(c => c!["key"]!.GetValue<string>(), c => c!.AsObject(), StringComparer.Ordinal);
        foreach (var key in row.Select(p => p.Key)) if (!columns.ContainsKey(key)) Invalid(table, key, "undeclared column");
        foreach (var (key, spec) in columns)
        {
            var value = row[key];
            if (value is null)
            {
                if (spec["required"]?.GetValue<bool>() != false) Invalid(table, key, "required");
                continue;
            }
            var type = spec["type"]!.GetValue<string>();
            if (type is "string" or "enum" or "datetime")
            {
                if (value.GetValueKind() != JsonValueKind.String) Invalid(table, key, "type");
                var text = value.GetValue<string>();
                if (spec["size"] is { } size && text.Length > size.GetValue<int>()) Invalid(table, key, "size");
                if (type == "enum" && !spec["elements"]!.AsArray().Any(v => v!.GetValue<string>() == text)) Invalid(table, key, "enum");
                if (type == "datetime" && (!Regex.IsMatch(text, @"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$", RegexOptions.CultureInvariant) ||
                                          !DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.None, out _))) Invalid(table, key, "type");
            }
            else if (type == "boolean")
            {
                if (value.GetValueKind() is not (JsonValueKind.True or JsonValueKind.False)) Invalid(table, key, "type");
            }
            else if (type == "integer")
            {
                if (value.GetValueKind() != JsonValueKind.Number || !double.TryParse(value.ToJsonString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var number) ||
                    !double.IsFinite(number) || Math.Truncate(number) != number || Math.Abs(number) > 9007199254740991) Invalid(table, key, "type");
                var n = double.Parse(value.ToJsonString(), CultureInfo.InvariantCulture);
                if (spec["min"] is { } min && n < min.GetValue<double>()) Invalid(table, key, "min");
                if (spec["max"] is { } max && n > max.GetValue<double>()) Invalid(table, key, "max");
            }
        }
    }

    private static void Invalid(string table, string column, string violation) => throw new ServiceException("INTERNAL_ERROR", new()
    { ["reason"] = "ROW_SCHEMA_VIOLATION", ["table"] = table, ["column"] = column, ["violation"] = violation });
}
