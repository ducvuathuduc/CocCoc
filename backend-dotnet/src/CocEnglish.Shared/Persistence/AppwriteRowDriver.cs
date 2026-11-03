using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;

namespace CocEnglish.Shared.Persistence;

public sealed record AppwriteConnection(Uri Endpoint, string ProjectId, string ApiKey, string DatabaseId = "cocenglish")
{
    public override string ToString() => $"AppwriteConnection({Endpoint.Host}, project={ProjectId}, credentials=redacted)";
}

public sealed record RowDocument(string Id, JsonObject Data, string? Version);
public sealed record RowOrder(string Column, bool Descending = false);
public sealed record RowQuery(
    IReadOnlyDictionary<string, object?>? Where = null,
    IReadOnlyDictionary<string, object?>? GreaterThanEqual = null,
    IReadOnlyDictionary<string, object?>? LessThan = null,
    IReadOnlyDictionary<string, string[]>? AnyOf = null,
    IReadOnlyList<RowOrder>? OrderBy = null,
    int Limit = 100);
public sealed record RowWrite(string Table, string Id, string Action, JsonObject? Data = null, IReadOnlyList<string>? Readers = null);
public sealed class TransactionConflictException : Exception;

public interface IRowDriver
{
    string Owner { get; }
    bool Configured { get; }
    Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken);
    Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken);
    Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken);
    Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken);
}

public sealed class AppwriteRowDriver(HttpClient client, AppwriteConnection connection, string owner) : IRowDriver
{
    public string Owner => owner;
    public bool Configured => connection.Endpoint.Scheme == "https" && connection.ProjectId.Length > 0 && connection.ApiKey.Length > 0;

    public async Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken)
    {
        OwnerSchema.For(owner, table);
        var raw = await SendAsync(HttpMethod.Get, RowsPath(table) + "/" + CanonicalWire.Encode(id), null, cancellationToken, missingIsNull: true);
        return raw is null ? null : Document(table, raw);
    }

    public async Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
    {
        OwnerSchema.For(owner, table);
        var limit = Math.Clamp(query.Limit, 1, 500);
        var result = new List<RowDocument>();
        var baseQueries = Queries(query);
        string? cursor = null;
        while (result.Count < limit)
        {
            var pageSize = Math.Min(100, limit - result.Count);
            var queries = new List<string>(baseQueries) { Query("limit", values: [pageSize]) };
            if (cursor is not null) queries.Add(Query("cursorAfter", values: [cursor]));
            var response = await SendAsync(HttpMethod.Get, RowsPath(table) + QueryString(queries) + "&total=false", null, cancellationToken);
            var rows = response?["rows"]?.AsArray() ?? throw new ServiceException("DB_UNAVAILABLE");
            foreach (var raw in rows) result.Add(Document(table, raw!.AsObject()));
            if (rows.Count < pageSize) break;
            var next = result[^1].Id;
            if (next == cursor) throw new ServiceException("DB_UNAVAILABLE");
            cursor = next;
        }
        return result;
    }

    public async Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken)
    {
        OwnerSchema.For(owner, table);
        var queries = Queries(new(Where: where)).Where(q => !q.Contains("\"$id\"", StringComparison.Ordinal)).ToList();
        queries.Add(Query("limit", values: [1]));
        var response = await SendAsync(HttpMethod.Get, RowsPath(table) + QueryString(queries), null, cancellationToken);
        return response?["total"]?.GetValue<long>() ?? throw new ServiceException("DB_UNAVAILABLE");
    }

    public async Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken)
    {
        if (writes.Count == 0) return;
        if (writes.Count > 95) throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "TRANSACTION_TOO_LARGE" });
        var operations = new JsonArray();
        foreach (var write in writes)
        {
            OwnerSchema.For(owner, write.Table);
            if (write.Action is not ("create" or "update" or "delete")) throw new ServiceException("INTERNAL_ERROR");
            var operation = new JsonObject
            {
                ["action"] = write.Action, ["databaseId"] = connection.DatabaseId,
                ["tableId"] = write.Table, ["rowId"] = write.Id
            };
            if (write.Action != "delete")
            {
                var data = write.Data?.DeepClone().AsObject() ?? throw new ServiceException("INTERNAL_ERROR");
                if (write.Readers is not null && write.Action == "create")
                {
                    if (write.Table != "p_notifications") throw new ServiceException("INTERNAL_ERROR");
                    data["$permissions"] = new JsonArray(write.Readers.Select(user => JsonValue.Create($"read(\"user:{user}\")")).ToArray());
                }
                operation["data"] = data;
            }
            operations.Add(operation);
        }
        string? transactionId = null;
        try
        {
            var transaction = await SendAsync(HttpMethod.Post, "/tablesdb/transactions", new() { ["ttl"] = 60 }, cancellationToken);
            transactionId = transaction?["$id"]?.GetValue<string>() ?? throw new ServiceException("DB_UNAVAILABLE");
            var path = "/tablesdb/transactions/" + CanonicalWire.Encode(transactionId);
            await SendAsync(HttpMethod.Post, path + "/operations", new() { ["operations"] = operations }, cancellationToken);
            foreach (var read in reads)
            {
                var actual = await ReadAsync(read.Table, read.Id, cancellationToken);
                var expected = read.Document;
                if (expected is null ? actual is not null : actual is null ||
                    expected.Version is not null && actual.Version != expected.Version ||
                    !JsonNode.DeepEquals(expected.Data["revision"], actual.Data["revision"]))
                    throw new TransactionConflictException();
            }
            await SendAsync(HttpMethod.Patch, path, new() { ["commit"] = true }, cancellationToken);
            transactionId = null;
        }
        finally
        {
            if (transactionId is not null)
            {
                using var rollbackTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                try { await SendAsync(HttpMethod.Patch, "/tablesdb/transactions/" + CanonicalWire.Encode(transactionId), new() { ["rollback"] = true }, rollbackTimeout.Token); }
                catch (Exception e) when (e is ServiceException or TransactionConflictException or OperationCanceledException) { /* Keep the original failure; abandoned transactions expire. */ }
            }
        }
    }

    private string RowsPath(string table) => "/tablesdb/" + CanonicalWire.Encode(connection.DatabaseId) + "/tables/" + CanonicalWire.Encode(table) + "/rows";
    private RowDocument Document(string table, JsonObject raw) => new(raw["$id"]!.GetValue<string>(), OwnerSchema.Normalize(owner, table, raw), raw["$updatedAt"]?.GetValue<string>());

    private static List<string> Queries(RowQuery query)
    {
        var queries = new List<string>();
        foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
            queries.Add(value is null ? Query("isNull", key) : Query("equal", key, [value]));
        foreach (var (key, values) in query.AnyOf ?? new Dictionary<string, string[]>())
        {
            if (values.Length == 0) throw new ServiceException("INTERNAL_ERROR");
            queries.Add(Query("equal", key, values.Cast<object?>().ToArray()));
        }
        foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>()) queries.Add(Query("greaterThanEqual", key, [value]));
        foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>()) queries.Add(Query("lessThan", key, [value]));
        foreach (var order in query.OrderBy ?? []) queries.Add(Query(order.Descending ? "orderDesc" : "orderAsc", order.Column));
        queries.Add(Query("orderAsc", "$id"));
        return queries;
    }

    private static string Query(string method, string? attribute = null, object?[]? values = null)
    {
        var query = new JsonObject { ["method"] = method };
        if (attribute is not null) query["attribute"] = attribute;
        if (values is not null) query["values"] = JsonSerializer.SerializeToNode(values);
        return query.ToJsonString(new() { WriteIndented = false });
    }

    private static string QueryString(IEnumerable<string> queries) => "?" + string.Join('&', queries.Select(q => "queries[]=" + Uri.EscapeDataString(q)));

    private async Task<JsonObject?> SendAsync(HttpMethod method, string path, JsonObject? body, CancellationToken cancellationToken, bool missingIsNull = false)
    {
        if (!Configured || connection.Endpoint.UserInfo.Length != 0 || connection.Endpoint.Query.Length != 0 || connection.Endpoint.Fragment.Length != 0)
            throw new ServiceException("SERVICE_NOT_CONFIGURED");
        try
        {
            using var request = new HttpRequestMessage(method, connection.Endpoint.AbsoluteUri.TrimEnd('/') + path);
            request.Headers.Add("X-Appwrite-Project", connection.ProjectId);
            request.Headers.Add("X-Appwrite-Key", connection.ApiKey);
            if (body is not null) request.Content = JsonContent.Create(body);
            using var response = await client.SendAsync(request, cancellationToken);
            if (missingIsNull && response.StatusCode == HttpStatusCode.NotFound) return null;
            if (response.StatusCode == HttpStatusCode.Conflict || method != HttpMethod.Get && response.StatusCode == HttpStatusCode.NotFound)
                throw new TransactionConflictException();
            if (response.StatusCode == HttpStatusCode.BadRequest)
                throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "STORAGE_REJECTED_ROW" });
            if (!response.IsSuccessStatusCode) throw new ServiceException("DB_UNAVAILABLE");
            return JsonNode.Parse(await response.Content.ReadAsStringAsync(cancellationToken))?.AsObject() ?? throw new ServiceException("DB_UNAVAILABLE");
        }
        catch (Exception e) when (e is HttpRequestException or JsonException || e is OperationCanceledException && !cancellationToken.IsCancellationRequested)
        {
            throw new ServiceException("DB_UNAVAILABLE");
        }
    }
}
