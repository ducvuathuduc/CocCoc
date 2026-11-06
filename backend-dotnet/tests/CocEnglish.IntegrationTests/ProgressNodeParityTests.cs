using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ProgressNodeParityTests
{
    [Fact]
    public async Task ScriptedAccountEconomyShopSequenceMatchesNodeResponsesAndRows()
    {
        var scenarioText = Resource("Scenarios");
        var scenario = JsonNode.Parse(scenarioText)!;
        var baseline = JsonNode.Parse(Resource("Node"))!;
        Assert.Equal(CanonicalWire.Sha256(scenarioText), baseline["scenarioSha256"]!.GetValue<string>());
        var steps = scenario["steps"]!.AsArray();
        var expected = baseline["results"]!.AsArray();
        Assert.Equal(steps.Count, expected.Count);
        await using var factory = new ProgressApiFixture { Now = DateTimeOffset.Parse(scenario["now"]!.GetValue<string>(), CultureInfo.InvariantCulture), CodeSecret = "cocenglish-dev-only-code-secret", UseParityWatermark = true, UseParityRelay = true, EnableSimulatedCommerce = true };
        factory.Driver.Rows.Clear();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Request-ID", scenario["requestId"]!.GetValue<string>());
        string? deletionRequestId = null;
        for (var index = 0; index < steps.Count; index++)
        {
            var step = steps[index]!.AsObject();
            Assert.Equal(index, expected[index]!["index"]!.GetValue<int>());
            if (step["clock"] is { } clock)
            {
                factory.Now = DateTimeOffset.Parse(clock.GetValue<string>(), CultureInfo.InvariantCulture);
                continue;
            }
            if (step["watermarkPending"] is { } pending)
            {
                factory.Watermark.PendingBefore = pending.GetValue<long>();
                Assert.Equal("control", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["relayOutcome"] is { } outcome)
            {
                factory.Relay.Outcome = outcome.GetValue<string>() switch
                {
                    "ack" => RelayOutcome.Ack,
                    "retry" => RelayOutcome.Retry,
                    "dead" => RelayOutcome.Dead,
                    _ => throw new InvalidOperationException("Unexpected parity relay outcome")
                };
                Assert.Equal("control", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["relayRandom"] is { } relayRandom)
            {
                factory.Random.Value = relayRandom.GetValue<double>();
                Assert.Equal("control", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["seedRangeDays"] is JsonObject seedRangeDays)
            {
                var table = seedRangeDays["table"]!.GetValue<string>();
                var userId = seedRangeDays["userId"]!.GetValue<string>();
                var start = DateOnly.ParseExact(seedRangeDays["startDay"]!.GetValue<string>(), "yyyy-MM-dd", CultureInfo.InvariantCulture);
                var count = seedRangeDays["count"]!.GetValue<int>();
                var source = seedRangeDays["row"]!.AsObject();
                var store = new OwnerStore(factory.Driver, factory.Services.GetRequiredService<TimeProvider>());
                await store.TransactAsync(async (tx, ct) =>
                {
                    for (var offset = 0; offset < count; offset++)
                    {
                        var day = start.AddDays(offset).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                        var id = CanonicalWire.RowId(table, userId, day);
                        var row = await tx.GetAsync(table, id, ct) ?? new JsonObject();
                        foreach (var (key, value) in source)
                            row[key] = value is JsonValue scalar && scalar.TryGetValue<string>(out var text)
                                ? JsonValue.Create(text.Replace("{day}", day, StringComparison.Ordinal))
                                : value?.DeepClone();
                        tx.Put(table, id, row);
                    }
                    return 0;
                });
                Assert.Equal("seed", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["seedMany"] is JsonObject seedMany)
            {
                var table = seedMany["table"]!.GetValue<string>();
                var prefix = seedMany["partPrefix"]?.GetValue<string>() ?? string.Empty;
                var count = seedMany["count"]!.GetValue<int>();
                var source = seedMany["row"]!.AsObject();
                var store = new OwnerStore(factory.Driver, factory.Services.GetRequiredService<TimeProvider>());
                await store.TransactAsync(async (tx, ct) =>
                {
                    for (var offset = 0; offset < count; offset++)
                    {
                        var index = offset.ToString("D3", CultureInfo.InvariantCulture);
                        var parts = seedMany["parts"] is JsonArray keyParts
                            ? keyParts.Select(part => part!.GetValue<string>().Replace("{index}", index, StringComparison.Ordinal)).ToArray()
                            : [prefix + index];
                        var id = CanonicalWire.RowId(table, parts);
                        var row = await tx.GetAsync(table, id, ct) ?? new JsonObject();
                        foreach (var (key, value) in source)
                            row[key] = value is JsonValue scalar && scalar.TryGetValue<string>(out var text)
                                ? JsonValue.Create(text.Replace("{index}", index, StringComparison.Ordinal))
                                : value?.DeepClone();
                        tx.Put(table, id, row);
                    }
                    return 0;
                });
                Assert.Equal("seed", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["seed"] is JsonArray seeds)
            {
                var store = new OwnerStore(factory.Driver, factory.Services.GetRequiredService<TimeProvider>());
                await store.TransactAsync(async (tx, ct) =>
                {
                    foreach (var item in seeds)
                    {
                        var table = item!["table"]!.GetValue<string>();
                        var id = CanonicalWire.RowId(table, item["parts"]!.AsArray().Select(p => p!.GetValue<string>()).ToArray());
                        var row = await tx.GetAsync(table, id, ct) ?? new JsonObject();
                        foreach (var (key, value) in item["patch"]!.AsObject()) row[key] = value?.DeepClone();
                        tx.Put(table, id, row);
                    }
                    return 0;
                });
                continue;
            }
            if (step["deleteRows"] is JsonArray deleteRows)
            {
                var writes = deleteRows.Select(item =>
                {
                    var table = item!["table"]!.GetValue<string>();
                    var id = CanonicalWire.RowId(table, item["parts"]!.AsArray().Select(p => p!.GetValue<string>()).ToArray());
                    return new RowWrite(table, id, "delete", null);
                }).ToArray();
                await factory.Driver.CommitAsync(writes, [], CancellationToken.None);
                Assert.Equal("seed", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["seedRaw"] is JsonArray rawSeeds)
            {
                // Emulate malformed legacy storage without passing rows through current schema validation.
                foreach (var item in rawSeeds)
                {
                    var table = item!["table"]!.GetValue<string>();
                    if (table != "p_achievements") throw new InvalidOperationException("Raw parity seeding is restricted to p_achievements.");
                    var id = CanonicalWire.RowId(table, item["parts"]!.AsArray().Select(p => p!.GetValue<string>()).ToArray());
                    factory.Driver.Rows[(table, id)] = item["row"]!.AsObject().DeepClone().AsObject();
                }
                Assert.Equal("seed", expected[index]!["kind"]!.GetValue<string>());
                continue;
            }
            if (step["inspect"] is JsonArray tables)
            {
                var actual = new JsonObject();
                foreach (var name in tables.Select(t => t!.GetValue<string>()))
                {
                    if (name == "@relay-deliveries")
                    {
                        actual[name] = new JsonArray(factory.Relay.Deliveries.OrderBy(CanonicalWire.Json, StringComparer.Ordinal).Select(d => d.DeepClone()).ToArray());
                        continue;
                    }
                    var rows = factory.Driver.Rows.Where(p => p.Key.Table == name)
                        .Select(pair => (pair.Key.Id, Row: ProjectRow(name, pair.Key.Id, pair.Value, deletionRequestId)));
                    var ordered = name == "p_outbox"
                        ? rows.OrderBy(pair => CanonicalWire.Json(pair.Row), StringComparer.Ordinal)
                        : rows.OrderBy(pair => pair.Id, StringComparer.Ordinal);
                    actual[name] = new JsonArray(ordered.Select(pair => pair.Row).ToArray());
                }
                Match(expected[index]!["tables"], actual, $"step {index} persisted tables");
                continue;
            }
            var path = step["path"]!.GetValue<string>();
            using var request = new HttpRequestMessage(new HttpMethod(step["method"]!.GetValue<string>()), path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", step["user"]!.GetValue<string>() + "-jwt");
            if (step["key"] is { } keyNode) request.Headers.Add("Idempotency-Key", keyNode.GetValue<string>());
            if (step.ContainsKey("body")) request.Content = new StringContent(step["body"]?.ToJsonString() ?? "null", Encoding.UTF8, "application/json");
            if (step["sender"] is { } senderNode)
            {
                var sender = senderNode.GetValue<string>();
                var fill = sender switch { "ai" => (byte)12, "learning" => (byte)13, "scheduler" => (byte)14, "maintainer" => (byte)15, _ => throw new InvalidOperationException("Unexpected parity sender") };
                var key = new ServiceKey("parity-" + sender, sender, Enumerable.Repeat(fill, 32).ToArray());
                var signature = ServiceHmac.Sign(key, step["method"]!.GetValue<string>(), path, "", new HashSet<string>(), step["body"]!.ToJsonString(), factory.Now.ToUnixTimeSeconds());
                request.Headers.Add("X-Service-Key-Id", signature.KeyId); request.Headers.Add("X-Service-Timestamp", signature.Timestamp); request.Headers.Add("X-Service-Signature", signature.Signature);
            }
            using var response = await client.SendAsync(request);
            var body = JsonNode.Parse(await response.Content.ReadAsStringAsync());
            if (path == "/v1/me/deletion" && (int)response.StatusCode == 202)
            {
                deletionRequestId = body!["requestId"]!.GetValue<string>();
                body["requestId"] = "$deletion-request-id";
            }
            Assert.True((int)response.StatusCode == expected[index]!["status"]!.GetValue<int>(), $"step {index} {path}: HTTP {(int)response.StatusCode}; expected {expected[index]!["status"]}");
            Match(expected[index]!["body"], body, $"step {index} {path}");
        }
    }

    private static string Resource(string name)
    {
        using var stream = typeof(ProgressNodeParityTests).Assembly.GetManifestResourceStream($"CocEnglish.Progress.Parity.{name}.json")!;
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }

    private static JsonNode ProjectRow(string table, string id, JsonObject data, string? deletionRequestId)
    {
        var row = data.DeepClone().AsObject();
        if (table == "p_outbox") { id = "$event-id"; row["eventId"] = "$event-id"; }
        foreach (var key in new[] { "responseJson", "payloadJson" })
            if (row.Text(key) is { } json) row[key] = JsonNode.Parse(json);
        if (table == "p_outbox" && row.Text("type") == "account.deleted.v1" && deletionRequestId is not null &&
            row["payloadJson"] is JsonObject payload && payload.Text("requestId") == deletionRequestId)
            payload["requestId"] = "$deletion-request-id";
        return new JsonObject { ["id"] = id, ["row"] = row };
    }

    private static void Match(JsonNode? expected, JsonNode? actual, string context)
    {
        var difference = Difference(expected, actual, "$");
        Assert.True(difference is null, context + ": " + difference);
    }
    private static string? Difference(JsonNode? expected, JsonNode? actual, string path)
    {
        if (expected is JsonObject obj && actual is JsonObject other)
        {
            foreach (var key in obj.Select(p => p.Key).Union(other.Select(p => p.Key)).Order(StringComparer.Ordinal))
            {
                if (!obj.ContainsKey(key) || !other.ContainsKey(key)) return path + "." + key + ": missing or unexpected field";
                if (Difference(obj[key], other[key], path + "." + key) is { } failure) return failure;
            }
            return null;
        }
        if (expected is JsonArray array && actual is JsonArray otherArray)
        {
            if (array.Count != otherArray.Count) return $"{path}: expected {array.Count} entries, actual {otherArray.Count}";
            for (var i = 0; i < array.Count; i++) if (Difference(array[i], otherArray[i], $"{path}[{i}]") is { } failure) return failure;
            return null;
        }
        return JsonNode.DeepEquals(expected, actual) ? null : $"{path}: expected {expected?.ToJsonString() ?? "null"}, actual {actual?.ToJsonString() ?? "null"}";
    }
}
