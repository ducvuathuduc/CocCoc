using System.Globalization;
using System.Text.Json.Nodes;

namespace CocEnglish.Shared.Persistence;

public static class JsonRows
{
    public static string? Text(this JsonObject row, string key) => row[key]?.GetValue<string>();
    public static long Number(this JsonObject row, string key, long fallback = 0) => row[key] is { } value
        ? long.Parse(value.ToJsonString(), NumberStyles.Integer, CultureInfo.InvariantCulture) : fallback;
    public static bool Flag(this JsonObject row, string key) => row[key]?.GetValue<bool>() ?? false;
}
