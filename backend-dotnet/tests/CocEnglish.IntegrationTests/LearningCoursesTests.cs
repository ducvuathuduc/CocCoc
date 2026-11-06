using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningCoursesTests
{
    [Fact]
    public async Task Courses_ReturnPublishedRowsInOrderedPagesAndRejectInvalidCursor()
    {
        using var app = new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder => {
            builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1", ["APPWRITE_PROJECT_ID"] = "test", ["COC_LEARNING_APPWRITE_KEY"] = "test", ["COC_LEARNING_PERSISTENCE"] = "appwrite", ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate" }));
            builder.ConfigureServices(s => { s.RemoveAll<IRowDriver>(); s.AddSingleton<IRowDriver, Driver>(); s.RemoveAll<IIdentityVerifier>(); s.AddSingleton<IIdentityVerifier, Identity>(); });
        });
        using var client = app.CreateClient(); client.DefaultRequestHeaders.Add("Authorization", "Bearer token");
        var page = await client.GetFromJsonAsync<JsonObject>("/v1/courses?limit=1");
        Assert.Equal("a", page!["items"]![0]!["courseId"]!.GetValue<string>()); Assert.Equal("bzox", page["nextCursor"]!.GetValue<string>());
        var second = await client.GetFromJsonAsync<JsonObject>("/v1/courses?limit=1&cursor=bzox");
        Assert.Equal("b", second!["items"]![0]!["courseId"]!.GetValue<string>()); Assert.Null(second["nextCursor"]);
        using var invalid = await client.GetAsync("/v1/courses?cursor=invalid"); Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        using var empty = await client.GetAsync("/v1/courses?cursor="); Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        using var missing = await client.GetAsync("/v1/courses/missing/manifest"); Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        var energy = await client.GetFromJsonAsync<JsonObject>("/v1/me/energy");
        Assert.Equal("UNLIMITED", energy!["mode"]!.GetValue<string>()); Assert.Equal(25, energy["balance"]!.GetValue<int>());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/v1/me/energy?extra=1")).StatusCode);
    }
    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken ct) => Task.FromResult(new VerifiedSubject("alice"));
    }
    private sealed class Driver : IRowDriver
    {
        public string Owner => "learning"; public bool Configured => true;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => Task.FromResult<RowDocument?>(null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct)
        {
            Assert.Equal("l_courses", table); Assert.Equal("PUBLISHED", query.Where!["status"]); Assert.Equal("courseId", query.OrderBy![0].Column);
            IReadOnlyList<RowDocument> rows = new[] { "a", "b" }.Skip(query.Offset).Take(query.Limit).Select(id => new RowDocument(id, new JsonObject {
                ["courseId"] = id, ["title"] = id.ToUpperInvariant(), ["sourceLocale"] = "vi", ["targetLocale"] = "en", ["publishedVersion"] = "v1", ["status"] = "PUBLISHED" }, null)).ToArray();
            return Task.FromResult(rows);
        }
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => Task.FromResult(2L);
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct) => throw new ServiceException("INTERNAL_ERROR");
    }
}
