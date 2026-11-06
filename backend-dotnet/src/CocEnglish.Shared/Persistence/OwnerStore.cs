using System.Text.Json.Nodes;
using System.Globalization;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;

namespace CocEnglish.Shared.Persistence;

public sealed record ReceiptKey(string UserId, string Operation, string Key);
public sealed record OperationResponse(int StatusCode, JsonNode? Body);
public sealed record ReceiptResult(string Status, int StatusCode, JsonNode? Body, string ExpiresAt);

public sealed class OwnerStore(IRowDriver driver, TimeProvider clock)
{
    private string Prefix => driver.Owner switch { "learning" => "l_", "progress" => "p_", "ai" => "a_", _ => throw new ServiceException("INTERNAL_ERROR") };

    public async Task<T> TransactAsync<T>(Func<OwnerSession, CancellationToken, Task<T>> work, CancellationToken ct = default)
    {
        for (var attempt = 1; attempt <= 4; attempt++)
        {
            ct.ThrowIfCancellationRequested();
            var session = new OwnerSession(driver) { Now = clock.GetUtcNow() };
            var result = await work(session, ct);
            try
            {
                if (session.Writes.Count != 0) await driver.CommitAsync(session.Writes, session.Reads, ct);
                return result;
            }
            catch (TransactionConflictException)
            {
                if (attempt == 4) throw new ServiceException("REVISION_CONFLICT", new() { ["reason"] = "TRANSACTION_CONFLICT" });
                await Task.Delay(TimeSpan.FromMilliseconds(25 * attempt), clock, ct);
            }
        }
        throw new ServiceException("REVISION_CONFLICT");
    }

    public Task<ReceiptResult> CommitWithReceiptAsync(ReceiptKey key, string bodyHash, Func<OwnerSession, CancellationToken, Task<OperationResponse>> effect, CancellationToken ct = default) =>
        TransactAsync(async (tx, token) =>
        {
            var table = Prefix + "receipts";
            var id = CanonicalWire.RowId(driver.Owner == "progress" ? table : "receipt", key.UserId, key.Operation, key.Key);
            var existing = await tx.GetAsync(table, id, token);
            if (existing is not null && DateTimeOffset.Parse(existing["expiresAt"]!.GetValue<string>(), CultureInfo.InvariantCulture) > tx.Now)
            {
                if (existing["bodyHash"]!.GetValue<string>() != bodyHash) throw new ServiceException("IDEMPOTENCY_CONFLICT");
                return new ReceiptResult("replayed", existing["statusCode"]!.GetValue<int>(), JsonNode.Parse(existing["responseJson"]!.GetValue<string>()), existing["expiresAt"]!.GetValue<string>());
            }
            var result = await effect(tx, token);
            var json = CanonicalWire.Stringify(result.Body);
            if (json.Length > 16384) throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "RECEIPT_TOO_LARGE" });
            var expires = OwnerSchema.Iso(tx.Now.AddDays(30));
            tx.Put(table, id, new()
            {
                ["userId"] = key.UserId, ["operation"] = key.Operation, ["key"] = key.Key, ["bodyHash"] = bodyHash,
                ["statusCode"] = result.StatusCode, ["responseJson"] = json, ["expiresAt"] = expires
            });
            return new ReceiptResult("created", result.StatusCode, result.Body?.DeepClone(), expires);
        }, ct);

    public Task<string> ApplyInboxAsync(string eventId, string type, string bodyHash, Func<OwnerSession, CancellationToken, Task> effect, CancellationToken ct = default) =>
        TransactAsync(async (tx, token) =>
        {
            var table = Prefix + "inbox";
            var id = driver.Owner == "ai" ? CanonicalWire.RowId("inbox", eventId) : eventId;
            var existing = await tx.GetAsync(table, id, token);
            if (existing is not null)
            {
                if (existing["bodyHash"]!.GetValue<string>() != bodyHash || OwnerSchema.HasColumn(driver.Owner, table, "type") && existing["type"]!.GetValue<string>() != type)
                    throw new ServiceException("IDEMPOTENCY_CONFLICT", new() { ["eventId"] = eventId });
                return "replayed";
            }
            await effect(tx, token);
            var row = new JsonObject { ["eventId"] = eventId, ["bodyHash"] = bodyHash, ["appliedAt"] = tx.NowIso };
            if (OwnerSchema.HasColumn(driver.Owner, table, "type")) row["type"] = type;
            if (OwnerSchema.HasColumn(driver.Owner, table, "resultJson")) row["resultJson"] = "{}";
            tx.Put(table, id, row);
            return "accepted";
        }, ct);
}

public sealed class OwnerSession(IRowDriver driver)
{
    private readonly Dictionary<(string Table, string Id), RowDocument?> _reads = [];
    private readonly Dictionary<(string Table, string Id), RowWrite> _writes = [];
    public DateTimeOffset Now { get; internal init; }
    public string NowIso => OwnerSchema.Iso(Now);
    internal IReadOnlyList<RowWrite> Writes => _writes.Values.ToArray();
    internal IReadOnlyList<(string Table, string Id, RowDocument? Document)> Reads => _reads
        .Where(p => driver.Owner != "progress" || _writes.ContainsKey(p.Key)).Select(p => (p.Key.Table, p.Key.Id, p.Value)).ToArray();

    public async Task<JsonObject?> GetAsync(string table, string id, CancellationToken ct)
    {
        OwnerSchema.For(driver.Owner, table);
        if (_writes.TryGetValue((table, id), out var staged)) return staged.Data?.DeepClone().AsObject();
        if (!_reads.TryGetValue((table, id), out var row))
        {
            row = await driver.ReadAsync(table, id, ct);
            _reads[(table, id)] = row is null ? null : row with { Data = row.Data.DeepClone().AsObject() };
        }
        return row?.Data.DeepClone().AsObject();
    }

    public async Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct)
    {
        OwnerSchema.For(driver.Owner, table);
        var committed = await driver.ListAsync(table, query with { Limit = 500 }, ct);
        foreach (var row in committed) _reads.TryAdd((table, row.Id), row with { Data = row.Data.DeepClone().AsObject() });
        var rows = committed.ToDictionary(r => r.Id, r => r with { Data = r.Data.DeepClone().AsObject() }, StringComparer.Ordinal);
        foreach (var write in _writes.Values.Where(w => w.Table == table))
        {
            if (write.Action == "delete" || write.Data is null || !Matches(write.Data, query)) rows.Remove(write.Id);
            else rows[write.Id] = new(write.Id, write.Data.DeepClone().AsObject(), null);
        }
        var result = rows.Values.ToList();
        result.Sort((a, b) =>
        {
            foreach (var order in query.OrderBy ?? [])
            {
                var x = a.Data[order.Column]; var y = b.Data[order.Column];
                if (x is null && y is null)
                {
                    // Match Node's legacy-row ordering: an absent value precedes an explicit null.
                    var xMissing = !a.Data.ContainsKey(order.Column);
                    var yMissing = !b.Data.ContainsKey(order.Column);
                    if (xMissing != yMissing) return xMissing ? -1 : 1;
                    continue;
                }
                if (x is null) return 1;
                if (y is null) return -1;
                var compare = Compare(x, y);
                if (compare != 0) return order.Descending ? -compare : compare;
            }
            return StringComparer.Ordinal.Compare(a.Id, b.Id);
        });
        return result.Take(Math.Clamp(query.Limit, 1, 500)).ToArray();
    }

    public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct)
    { OwnerSchema.For(driver.Owner, table); return driver.CountAsync(table, where, ct); }

    public Task<long> CountAsync(string table, RowQuery query, CancellationToken ct)
    { OwnerSchema.For(driver.Owner, table); return driver.CountAsync(table, query, ct); }

    public void Put(string table, string id, JsonObject row, IReadOnlyList<string>? readers = null)
    {
        var mutable = OwnerSchema.IsMutable(driver.Owner, table);
        var key = (table, id);
        var input = row.DeepClone().AsObject();
        var original = _reads.GetValueOrDefault(key)?.Data;
        var prior = _writes.GetValueOrDefault(key)?.Data ?? original;
        if (!mutable && (original is not null || prior is not null)) throw new ServiceException("INTERNAL_ERROR", new() { ["reason"] = "IMMUTABLE_ROW_REWRITTEN" });
        if (mutable)
        {
            input["createdAt"] = prior?["createdAt"]?.DeepClone() ?? JsonValue.Create(NowIso);
            input["updatedAt"] = NowIso;
            input["revision"] = original is null ? 0 : original.Number("revision") + 1;
        }
        OwnerSchema.Validate(driver.Owner, table, input);
        _writes[key] = new(table, id, original is null ? "create" : "update", input, readers);
    }

    public void Delete(string table, string id)
    {
        OwnerSchema.For(driver.Owner, table);
        if (_reads.GetValueOrDefault((table, id)) is null) _writes.Remove((table, id));
        else _writes[(table, id)] = new(table, id, "delete");
    }

    private static bool Matches(JsonObject row, RowQuery query)
    {
        foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>()) if (!JsonNode.DeepEquals(row[key], System.Text.Json.JsonSerializer.SerializeToNode(value))) return false;
        foreach (var (key, values) in query.AnyOf ?? new Dictionary<string, string[]>()) if (row[key] is null || !values.Contains(row[key]!.GetValue<string>(), StringComparer.Ordinal)) return false;
        foreach (var (key, value) in query.GreaterThanEqual ?? new Dictionary<string, object?>()) if (row[key] is null || Compare(row[key]!, System.Text.Json.JsonSerializer.SerializeToNode(value)!) < 0) return false;
        foreach (var (key, value) in query.LessThan ?? new Dictionary<string, object?>()) if (row[key] is null || Compare(row[key]!, System.Text.Json.JsonSerializer.SerializeToNode(value)!) >= 0) return false;
        foreach (var (key, value) in query.LessThanEqual ?? new Dictionary<string, object?>()) if (row[key] is null || Compare(row[key]!, System.Text.Json.JsonSerializer.SerializeToNode(value)!) > 0) return false;
        return true;
    }

    private static int Compare(JsonNode a, JsonNode b) => a.GetValueKind() == System.Text.Json.JsonValueKind.Number && b.GetValueKind() == System.Text.Json.JsonValueKind.Number
        ? double.Parse(a.ToJsonString(), CultureInfo.InvariantCulture).CompareTo(double.Parse(b.ToJsonString(), CultureInfo.InvariantCulture))
        : StringComparer.Ordinal.Compare(a.GetValue<string>(), b.GetValue<string>());
}
