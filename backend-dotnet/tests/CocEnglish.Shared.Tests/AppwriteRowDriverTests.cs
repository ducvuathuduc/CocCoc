using System.Net;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class AppwriteRowDriverTests
{
    [Fact]
    public async Task ListAsync_UsesOffsetOnlyOnFirstPageThenCursor()
    {
        var calls = 0;
        using var handler = new Handler((request, _) => {
            var query = Uri.UnescapeDataString(request.RequestUri!.Query);
            if (++calls == 1)
            {
                Assert.Contains("\"method\":\"offset\",\"values\":[150]", query);
                return Task.FromResult(Response(200, new JsonObject { ["rows"] = new JsonArray(Enumerable.Range(0, 100).Select(i => (JsonNode)new JsonObject { ["$id"] = "row-" + i }).ToArray()) }.ToJsonString()));
            }
            Assert.DoesNotContain("\"method\":\"offset\"", query);
            Assert.Contains("\"method\":\"cursorAfter\",\"values\":[\"row-99\"]", query);
            return Task.FromResult(Response(200, "{\"rows\":[{\"$id\":\"last\"}]}"));
        });
        using var client = new HttpClient(handler);
        var rows = await new AppwriteRowDriver(client, Connection, "learning").ListAsync("l_courses", new(Limit: 101, Offset: 150), CancellationToken.None);
        Assert.Equal(101, rows.Count); Assert.Equal("last", rows[^1].Id); Assert.Equal(2, calls);
    }
    private static readonly AppwriteConnection Connection = new(new("https://appwrite.test/v1"), "local-project", "private-test-key");

    [Fact]
    public async Task ReadAsync_NormalizesSchemaDatesAndHidesAppwriteMetadata()
    {
        using var handler = new Handler((request, _) =>
        {
            Assert.Equal("/v1/tablesdb/cocenglish/tables/p_profiles/rows/alice", request.RequestUri!.AbsolutePath);
            Assert.Equal("private-test-key", Assert.Single(request.Headers.GetValues("X-Appwrite-Key")));
            Assert.Equal("local-project", Assert.Single(request.Headers.GetValues("X-Appwrite-Project")));
            return Task.FromResult(Response(200, """{"$id":"alice","$updatedAt":"2026-11-03T10:00:00+00:00","createdAt":"2026-11-03T10:00:00+00:00","nickname":"Alice"}"""));
        });
        using var client = new HttpClient(handler);
        var row = await new AppwriteRowDriver(client, Connection, "progress").ReadAsync("p_profiles", "alice", CancellationToken.None);
        Assert.NotNull(row);
        Assert.Equal("alice", row.Id);
        Assert.Equal("Alice", row.Data["nickname"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", row.Data["createdAt"]!.GetValue<string>());
        Assert.False(row.Data.ContainsKey("$id"));
        Assert.False(Connection.ToString().Contains("private-test-key", StringComparison.Ordinal));
    }

    [Fact]
    public async Task ReadAsync_HidesMissingRowsAndRejectsForeignTablesBeforeNetwork()
    {
        using var handler = new Handler((_, _) => Task.FromResult(Response(404, "{}")));
        using var client = new HttpClient(handler);
        var driver = new AppwriteRowDriver(client, Connection, "progress");
        Assert.Null(await driver.ReadAsync("p_profiles", "missing", CancellationToken.None));
        Assert.Equal("FORBIDDEN", (await Assert.ThrowsAsync<ServiceException>(() => driver.ReadAsync("l_sessions", "x", CancellationToken.None))).Code);
        Assert.Single(handler.Calls);
    }

    [Fact]
    public async Task ListAsync_PaginatesWithStableIdAndOwnerFilter()
    {
        var calls = 0;
        using var handler = new Handler((request, _) =>
        {
            var query = Uri.UnescapeDataString(request.RequestUri!.Query);
            Assert.Contains("\"attribute\":\"userId\",\"values\":[\"alice\"]", query);
            Assert.Contains("\"method\":\"orderAsc\",\"attribute\":\"$id\"", query);
            if (++calls == 1)
            {
                var rows = Enumerable.Range(0, 100).Select(i => new JsonObject { ["$id"] = "row-" + i, ["userId"] = "alice" }).ToArray();
                return Task.FromResult(Response(200, new JsonObject { ["rows"] = new JsonArray(rows) }.ToJsonString()));
            }
            Assert.Contains("\"method\":\"cursorAfter\",\"values\":[\"row-99\"]", query);
            return Task.FromResult(Response(200, """{"rows":[{"$id":"last","userId":"alice"}]}"""));
        });
        using var client = new HttpClient(handler);
        var rows = await new AppwriteRowDriver(client, Connection, "progress").ListAsync("p_day_activity", new(Where: new Dictionary<string, object?> { ["userId"] = "alice" }, Limit: 101), CancellationToken.None);
        Assert.Equal(101, rows.Count);
        Assert.Equal("last", rows[^1].Id);
        Assert.Equal(2, calls);
    }

    [Fact]
    public async Task CountAsync_AppliesStatusSetAndCutoffWithoutAnOrderingLimit()
    {
        using var handler = new Handler((request, _) =>
        {
            var query = Uri.UnescapeDataString(request.RequestUri!.Query);
            Assert.Contains("\"method\":\"equal\",\"attribute\":\"status\",\"values\":[\"PENDING\",\"LEASED\",\"DEAD\"]", query);
            Assert.Contains("\"method\":\"lessThan\",\"attribute\":\"occurredAt\",\"values\":[\"2026-11-03T12:00:00.000Z\"]", query);
            Assert.Contains("\"method\":\"limit\",\"values\":[1]", query);
            Assert.DoesNotContain("\"method\":\"orderAsc\"", query);
            return Task.FromResult(Response(200, "{\"total\":3,\"rows\":[]}"));
        });
        using var client = new HttpClient(handler);

        var count = await new AppwriteRowDriver(client, Connection, "learning").CountAsync("l_outbox", new RowQuery(
            LessThan: new Dictionary<string, object?> { ["occurredAt"] = "2026-11-03T12:00:00.000Z" },
            AnyOf: new Dictionary<string, string[]> { ["status"] = ["PENDING", "LEASED", "DEAD"] }), CancellationToken.None);

        Assert.Equal(3, count);
        Assert.Single(handler.Calls);
    }

    [Fact]
    public async Task ListAsync_AppliesInclusiveDueAtCutoff()
    {
        using var handler = new Handler((request, _) =>
        {
            var query = Uri.UnescapeDataString(request.RequestUri!.Query);
            Assert.Contains("\"method\":\"lessThanEqual\",\"attribute\":\"dueAt\",\"values\":[\"2026-11-03T12:00:00.000Z\"]", query);
            Assert.Contains("\"method\":\"equal\",\"attribute\":\"userId\",\"values\":[\"alice\"]", query);
            return Task.FromResult(Response(200, "{\"rows\":[{\"$id\":\"due\",\"userId\":\"alice\"}]}"));
        });
        using var client = new HttpClient(handler);

        var rows = await new AppwriteRowDriver(client, Connection, "learning").ListAsync("l_review_items", new RowQuery(
            Where: new Dictionary<string, object?> { ["userId"] = "alice" },
            LessThanEqual: new Dictionary<string, object?> { ["dueAt"] = "2026-11-03T12:00:00.000Z" }), CancellationToken.None);

        Assert.Equal("due", Assert.Single(rows).Id);
    }

    [Fact]
    public async Task CommitAsync_StagesOneAtomicBatchThenChecksReadsAndCommits()
    {
        using var handler = new Handler(async (request, ct) =>
        {
            var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(ct);
            if (request.Method == HttpMethod.Post && request.RequestUri!.AbsolutePath.EndsWith("/transactions", StringComparison.Ordinal))
            {
                Assert.Equal(60, JsonNode.Parse(body)!["ttl"]!.GetValue<int>());
                return Response(201, "{\"$id\":\"tx-1\"}");
            }
            if (request.RequestUri!.AbsolutePath.EndsWith("/operations", StringComparison.Ordinal))
            {
                var operations = JsonNode.Parse(body)!["operations"]!.AsArray();
                Assert.Single(operations);
                Assert.Equal("update", operations[0]!["action"]!.GetValue<string>());
                Assert.Equal("p_profiles", operations[0]!["tableId"]!.GetValue<string>());
                return Response(200, "{}");
            }
            if (request.Method == HttpMethod.Get) return Response(200, """{"$id":"alice","$updatedAt":"v1","revision":1}""");
            Assert.Equal(HttpMethod.Patch, request.Method);
            Assert.True(JsonNode.Parse(body)!["commit"]!.GetValue<bool>());
            return Response(200, "{}");
        });
        using var client = new HttpClient(handler);
        var read = new RowDocument("alice", new() { ["revision"] = 1 }, "v1");
        await new AppwriteRowDriver(client, Connection, "progress").CommitAsync(
            [new("p_profiles", "alice", "update", new() { ["revision"] = 2 })], [("p_profiles", "alice", read)], CancellationToken.None);
        Assert.Equal(4, handler.Calls.Count);
    }

    [Theory]
    [InlineData("read-moved")]
    [InlineData("commit-conflict")]
    public async Task CommitAsync_RollsBackOnReadConflictOrCommitConflict(string failure)
    {
        var rollback = false;
        using var handler = new Handler(async (request, ct) =>
        {
            if (request.Method == HttpMethod.Get) return Response(200, failure == "read-moved" ? """{"$id":"alice","$updatedAt":"v2","revision":2}""" : """{"$id":"alice","$updatedAt":"v1","revision":1}""");
            if (request.Method == HttpMethod.Post) return Response(201, "{\"$id\":\"tx-1\"}");
            var body = JsonNode.Parse(await request.Content!.ReadAsStringAsync(ct))!;
            if (body["rollback"]?.GetValue<bool>() == true) { rollback = true; return Response(200, "{}"); }
            return Response(409, "{}");
        });
        using var client = new HttpClient(handler);
        await Assert.ThrowsAsync<TransactionConflictException>(() => new AppwriteRowDriver(client, Connection, "progress").CommitAsync(
            [new("p_profiles", "alice", "update", new() { ["revision"] = 2 })],
            [("p_profiles", "alice", new("alice", new() { ["revision"] = 1 }, "v1"))], CancellationToken.None));
        Assert.True(rollback);
    }

    [Theory]
    [InlineData(400, "INTERNAL_ERROR")]
    [InlineData(500, "DB_UNAVAILABLE")]
    public async Task ReadAsync_RedactsDatabaseFailures(int status, string code)
    {
        using var handler = new Handler((_, _) => Task.FromResult(Response(status, "{\"message\":\"private-test-key\"}")));
        using var client = new HttpClient(handler);
        var failure = await Assert.ThrowsAsync<ServiceException>(() => new AppwriteRowDriver(client, Connection, "progress").ReadAsync("p_profiles", "alice", CancellationToken.None));
        Assert.Equal(code, failure.Code);
        Assert.DoesNotContain("private-test-key", failure.Envelope("r").ToJsonString());
    }

    private static HttpResponseMessage Response(int status, string body) => new((HttpStatusCode)status) { Content = new StringContent(body) };
    private sealed class Handler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        public List<string> Calls { get; } = [];
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls.Add(request.Method + " " + request.RequestUri!.AbsolutePath);
            return send(request, cancellationToken);
        }
    }
}
