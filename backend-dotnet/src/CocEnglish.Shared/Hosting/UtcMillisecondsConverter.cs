using System.Text.Json;
using System.Text.Json.Serialization;
using CocEnglish.Shared.Persistence;

namespace CocEnglish.Shared.Hosting;

public sealed class UtcMillisecondsConverter : JsonConverter<DateTimeOffset>
{
    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) => reader.GetDateTimeOffset();
    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) => writer.WriteStringValue(OwnerSchema.Iso(value));
}
