using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class QuestChestNodeParityTests
{
    public static IEnumerable<object[]> Cases()
    {
        using var stream = typeof(QuestChestNodeParityTests).Assembly.GetManifestResourceStream("CocEnglish.Progress.Parity.QuestChest.json")!;
        using var reader = new StreamReader(stream);
        return JsonNode.Parse(reader.ReadToEnd())!["cases"]!.AsArray().Select(c => new object[] { c!["operation"]!.GetValue<string>(), c.ToJsonString() }).ToArray();
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public async Task CreationAndReplayMatchNodeResponsesAndEveryDomainRow(string operation, string expectedJson)
    {
        var expected = JsonNode.Parse(expectedJson)!;
        await using var factory = new ProgressApiFixture { Now = DateTimeOffset.Parse("2026-11-05T10:00:00Z") };
        factory.Driver.Rows.Clear();
        var generated = 0;
        await using var configured = factory.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
        {
            services.RemoveAll<ProgressEconomy>();
            services.AddSingleton(new ProgressEconomy(() => { generated++; return operation; }));
        }));
        using var client = configured.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "alice-jwt");
        client.DefaultRequestHeaders.Add("X-Request-ID", "chest-parity");
        async Task<JsonObject> Call(string path, string key, string body)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
            request.Headers.Add("Idempotency-Key", key);
            using var response = await client.SendAsync(request);
            return new() { ["status"] = (int)response.StatusCode, ["body"] = JsonNode.Parse(await response.Content.ReadAsStringAsync()) };
        }
        var initialized = await Call("/v1/me/initialize", "33333333-3333-4333-8333-333333333333", "");
        Assert.Equal(200, initialized["status"]!.GetValue<int>());
        using var scope = configured.Services.CreateScope();
        await scope.ServiceProvider.GetRequiredService<OwnerStore>().TransactAsync(async (tx, ct) =>
        {
            tx.Put("p_quests", CanonicalWire.RowId("p_quests", "alice", "DAY", "2026-11-05", "daily_lessons"), new()
            { ["userId"] = "alice", ["questId"] = "daily_lessons", ["period"] = "DAY", ["periodKey"] = "2026-11-05", ["metricValue"] = 2, ["target"] = 2, ["claimed"] = false, ["claimOperationId"] = null });
            await Task.CompletedTask;
            return 0;
        });
        var responses = new JsonArray();
        foreach (var key in new[] { "11111111-1111-4111-8111-111111111111", "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222" })
            responses.Add(await Call("/v1/quests/daily_lessons/claim", key, """{"periodKey":"2026-11-05","upgradeChest":true}"""));
        Assert.True(JsonNode.DeepEquals(expected["responses"], responses), $"Chest response mismatch for {operation}: {responses}");
        Assert.Equal(1, generated); // Neither HTTP replay nor another request key may reroll.
        foreach (var (table, baseline) in expected["tables"]!.AsObject())
        {
            var rows = new JsonArray(factory.Driver.Rows.Where(p => p.Key.Table == table).OrderBy(p => p.Key.Id, StringComparer.Ordinal).Select(p =>
            {
                var row = p.Value.DeepClone().AsObject();
                if (row.Text("responseJson") is { } json) row["responseJson"] = JsonNode.Parse(json);
                return (JsonNode)new JsonObject { ["id"] = p.Key.Id, ["row"] = row };
            }).ToArray());
            Assert.True(JsonNode.DeepEquals(baseline, rows), $"Chest persisted {table} mismatch for {operation}: {rows}");
        }
    }
}
