using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningOutboxWatermarkTests
{
    private static readonly ServiceKey ProgressKey = new("progress-test", "progress", Enumerable.Repeat((byte)17, 32).ToArray());
    private static readonly ServiceKey AiKey = new("ai-test", "ai", Enumerable.Repeat((byte)34, 32).ToArray());
    private const string Path = "/internal/outbox-watermark";
    private const string Query = "?before=2026-11-03T12%3A00%3A00.000Z";

    [Fact]
    public async Task SignedWatermark_CountsPendingLeasedAndDeadBeforeCutoff()
    {
        var driver = new Driver();
        driver.Seed("pending", "PENDING", "2026-11-03T10:00:00.000Z");
        driver.Seed("dead", "DEAD", "2026-11-03T10:15:00.000Z");
        driver.Seed("leased", "LEASED", "2026-11-03T11:59:59.000Z");
        driver.Seed("acknowledged", "ACK", "2026-11-03T09:00:00.000Z");
        driver.Seed("after-cutoff", "DEAD", "2026-11-03T12:00:00.000Z");
        using var app = CreateApp(driver);
        using var client = app.CreateClient();

        using var response = await Send(client, ProgressKey, Query);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("2026-11-03T12:00:00.000Z", body["before"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", body["oldestUndeliveredAt"]!.GetValue<string>());
        Assert.Equal(3, body["pendingBefore"]!.GetValue<int>());
    }

    [Fact]
    public async Task Watermark_RejectsUnapprovedSenderAndInvalidCutoff()
    {
        using var app = CreateApp(new Driver());
        using var client = app.CreateClient();

        using var wrongSender = await Send(client, AiKey, Query);
        Assert.Equal(HttpStatusCode.Forbidden, wrongSender.StatusCode);

        const string invalidQuery = "?before=not-a-date";
        using var invalid = await Send(client, ProgressKey, invalidQuery);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Equal("before", (await invalid.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["details"]!["field"]!.GetValue<string>());
    }

    private static WebApplicationFactory<Learning.Program> CreateApp(Driver driver) =>
        new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            var progressHex = Convert.ToHexStringLower(ProgressKey.Secret);
            var aiHex = Convert.ToHexStringLower(AiKey.Secret);
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["COC_SERVICE_KEYS"] = "[{\"keyId\":\"progress-test\",\"sender\":\"progress\",\"secretHex\":\"" + progressHex + "\"},{\"keyId\":\"ai-test\",\"sender\":\"ai\",\"secretHex\":\"" + aiHex + "\"}]"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
            });
        });

    private static async Task<HttpResponseMessage> Send(HttpClient client, ServiceKey key, string query)
    {
        var signature = ServiceHmac.Sign(key, "GET", Path, query, new HashSet<string>(StringComparer.Ordinal) { "before" }, "", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        using var request = new HttpRequestMessage(HttpMethod.Get, Path + query);
        request.Headers.Add("X-Service-Key-Id", signature.KeyId);
        request.Headers.Add("X-Service-Timestamp", signature.Timestamp);
        request.Headers.Add("X-Service-Signature", signature.Signature);
        return await client.SendAsync(request);
    }

    private sealed class Driver : IRowDriver
    {
        private readonly Dictionary<string, JsonObject> rows = new(StringComparer.Ordinal);
        public string Owner => "learning";
        public bool Configured => true;

        public void Seed(string id, string status, string occurredAt) => rows[id] = new JsonObject
        {
            ["status"] = status,
            ["occurredAt"] = occurredAt
        };

        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken) => Task.FromResult<RowDocument?>(null);

        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
        {
            IEnumerable<KeyValuePair<string, JsonObject>> selected = rows;
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
                selected = selected.Where(row => row.Value[key]?.ToString() == value?.ToString());
            foreach (var (key, values) in query.AnyOf ?? new Dictionary<string, string[]>())
                selected = selected.Where(row => row.Value[key]?.GetValue<string>() is { } actual && values.Contains(actual, StringComparer.Ordinal));
            foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>())
                selected = selected.Where(row => string.CompareOrdinal(row.Value[key]?.GetValue<string>(), value?.ToString()) < 0);
            foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>())
                selected = selected.Where(row => string.CompareOrdinal(row.Value[key]?.GetValue<string>(), value?.ToString()) >= 0);
            foreach (var order in query.OrderBy ?? [])
                selected = order.Descending
                    ? selected.OrderByDescending(row => row.Value[order.Column]?.GetValue<string>(), StringComparer.Ordinal)
                    : selected.OrderBy(row => row.Value[order.Column]?.GetValue<string>(), StringComparer.Ordinal);
            var result = selected.Skip(query.Offset).Take(query.Limit)
                .Select(row => new RowDocument(row.Key, row.Value.DeepClone().AsObject(), null)).ToArray();
            return Task.FromResult<IReadOnlyList<RowDocument>>(result);
        }

        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken) => throw new NotSupportedException();
    }
}
