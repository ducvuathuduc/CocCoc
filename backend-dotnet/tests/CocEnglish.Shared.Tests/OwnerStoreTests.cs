using System.Text.Json.Nodes;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class OwnerStoreTests
{
    private static readonly DateTimeOffset Instant = DateTimeOffset.Parse("2026-11-03T10:00:00Z");

    [Fact]
    public async Task Transaction_UpdatePreservesCreatedAtAndIncrementsRevisionOnlyOncePerAttempt()
    {
        var driver = new Driver();
        var clock = new Clock();
        var store = new OwnerStore(driver, clock);
        await store.TransactAsync((tx, ct) =>
        {
            tx.Put("p_first_rewards", "row", new() { ["userId"] = "alice", ["rewardIdentity"] = "lesson", ["completionId"] = "first" });
            return Task.FromResult(0);
        });
        clock.Now = Instant.AddDays(1);
        await store.TransactAsync(async (tx, ct) =>
        {
            var row = (await tx.GetAsync("p_first_rewards", "row", ct))!;
            row["completionId"] = "second";
            tx.Put("p_first_rewards", "row", row);
            row["completionId"] = "final";
            tx.Put("p_first_rewards", "row", row);
            return 0;
        });
        var final = driver.Rows[("p_first_rewards", "row")].Data;
        Assert.Equal("final", final.Text("completionId"));
        Assert.Equal(1, final.Number("revision"));
        Assert.Equal("2026-11-03T10:00:00.000Z", final.Text("createdAt"));
        Assert.Equal("2026-11-04T10:00:00.000Z", final.Text("updatedAt"));
    }

    [Fact]
    public async Task Transaction_ReadYourWritesAndCopyIsolationDoNotLeakMutableRows()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        await store.TransactAsync(async (tx, ct) =>
        {
            Assert.Null(await tx.GetAsync("p_first_rewards", "x", ct));
            tx.Put("p_first_rewards", "x", new() { ["userId"] = "alice", ["rewardIdentity"] = "lesson-1", ["completionId"] = "completion-1" });
            var row = (await tx.GetAsync("p_first_rewards", "x", ct))!;
            Assert.Equal(0L, row["revision"]!.GetValue<long>());
            row["userId"] = "tampered";
            Assert.Equal("alice", (await tx.GetAsync("p_first_rewards", "x", ct))!["userId"]!.GetValue<string>());
            return 0;
        });
        Assert.Equal("alice", driver.Rows[("p_first_rewards", "x")].Data["userId"]!.GetValue<string>());
        Assert.Equal("2026-11-03T10:00:00.000Z", driver.Rows[("p_first_rewards", "x")].Data["createdAt"]!.GetValue<string>());
    }

    [Fact]
    public async Task Receipt_ReplaysSameBodyWithoutEffectAndRejectsSubstitution()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var effects = 0;
        var key = new ReceiptKey("alice", "initializeProfile", "key-1");
        Task<OperationResponse> Effect(OwnerSession _, CancellationToken ct) => Task.FromResult(new OperationResponse(200, new JsonObject { ["count"] = ++effects }));
        var created = await store.CommitWithReceiptAsync(key, "body-1", Effect);
        var replayed = await store.CommitWithReceiptAsync(key, "body-1", Effect);
        Assert.Equal("created", created.Status);
        Assert.Equal("replayed", replayed.Status);
        Assert.Equal(200, replayed.StatusCode);
        Assert.Equal(1, replayed.Body!["count"]!.GetValue<int>());
        Assert.Equal(1, effects);
        Assert.Equal(OwnerSchema.Iso(Instant.AddDays(30)), created.ExpiresAt);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await Assert.ThrowsAsync<ServiceException>(() => store.CommitWithReceiptAsync(key, "body-2", Effect))).Code);
        Assert.Equal(1, effects);
    }

    [Fact]
    public async Task Receipt_UsesJavaScriptStringLengthForUnicodeResponses()
    {
        var store = new OwnerStore(new Driver(), new Clock());
        var text = new string('ư', 4000);
        var receipt = await store.CommitWithReceiptAsync(new("alice", "unicode", "key"), "body",
            (_, _) => Task.FromResult(new OperationResponse(200, new JsonObject { ["text"] = text })));
        Assert.Equal(text, receipt.Body!["text"]!.GetValue<string>());
    }

    [Fact]
    public async Task Receipt_AtExactExpiryReexecutesAndOtherAccountHasOwnKey()
    {
        var driver = new Driver();
        var clock = new Clock();
        var store = new OwnerStore(driver, clock);
        var effects = 0;
        Task<OperationResponse> Effect(OwnerSession _, CancellationToken ct) => Task.FromResult(new OperationResponse(200, JsonValue.Create(++effects)));
        var key = new ReceiptKey("alice", "op", "same-key");
        await store.CommitWithReceiptAsync(key, "body", Effect);
        await store.CommitWithReceiptAsync(key with { UserId = "bob" }, "body", Effect);
        clock.Now = Instant.AddDays(30);
        var expired = await store.CommitWithReceiptAsync(key, "new-body", Effect);
        Assert.Equal("created", expired.Status);
        Assert.Equal(3, effects);
        Assert.Equal(3, expired.Body!.GetValue<int>());
    }

    [Fact]
    public async Task Transaction_FailureDoesNotCommitAndConflictsRetryOnlyFourTimes()
    {
        var driver = new Driver { Conflicts = 4 };
        var store = new OwnerStore(driver, new Clock());
        var attempts = 0;
        var failure = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync(async (tx, ct) =>
        {
            attempts++;
            await tx.GetAsync("p_first_rewards", "x", ct);
            tx.Put("p_first_rewards", "x", new() { ["userId"] = "alice", ["rewardIdentity"] = "lesson", ["completionId"] = "completion" });
            return 0;
        }));
        Assert.Equal("REVISION_CONFLICT", failure.Code);
        Assert.Equal(4, attempts);
        Assert.Empty(driver.Rows);
        driver.Conflicts = 0;
        await Assert.ThrowsAsync<InvalidOperationException>(() => store.TransactAsync<int>((tx, ct) =>
        {
            tx.Put("p_first_rewards", "x", new() { ["userId"] = "alice", ["rewardIdentity"] = "lesson", ["completionId"] = "completion" });
            throw new InvalidOperationException("effect failed");
        }));
        Assert.Empty(driver.Rows);
    }

    [Fact]
    public async Task Inbox_DeduplicatesEventAndRejectsChangedTypeOrPayload()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        var effects = 0;
        Task Effect(OwnerSession _, CancellationToken ct) { effects++; return Task.CompletedTask; }
        Assert.Equal("accepted", await store.ApplyInboxAsync("event-1", "lesson.completed.v1", "body", Effect));
        Assert.Equal("replayed", await store.ApplyInboxAsync("event-1", "lesson.completed.v1", "body", Effect));
        Assert.Equal(1, effects);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await Assert.ThrowsAsync<ServiceException>(() => store.ApplyInboxAsync("event-1", "lesson.completed.v1", "changed", Effect))).Code);
        Assert.Equal("IDEMPOTENCY_CONFLICT", (await Assert.ThrowsAsync<ServiceException>(() => store.ApplyInboxAsync("event-1", "other.type.v1", "body", Effect))).Code);
        Assert.Equal(1, effects);
    }

    [Fact]
    public async Task Schema_RejectsUnknownMissingFieldsAndImmutableRewrites()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        foreach (var row in new[] { new JsonObject { ["userId"] = "alice" }, new JsonObject { ["userId"] = "alice", ["zone"] = "UTC", ["effectiveAt"] = "bad" } })
            Assert.Equal("INTERNAL_ERROR", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync<int>((tx, ct) =>
            { tx.Put("p_zone_history", "zone", row); return Task.FromResult(0); }))).Code);
        await store.TransactAsync<int>((tx, ct) =>
        { tx.Put("p_zone_history", "zone", new() { ["userId"] = "alice", ["zone"] = "UTC", ["effectiveAt"] = "2026-01-01T00:00:00.000Z" }); return Task.FromResult(0); });
        Assert.Equal("INTERNAL_ERROR", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync(async (tx, ct) =>
        { var row = (await tx.GetAsync("p_zone_history", "zone", ct))!; tx.Put("p_zone_history", "zone", row); return 0; }))).Code);
    }

    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = Instant;
        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class Driver : IRowDriver
    {
        public string Owner => "progress";
        public bool Configured => true;
        public int Conflicts { get; set; }
        public Dictionary<(string Table, string Id), RowDocument> Rows { get; } = [];
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken) => Task.FromResult(Rows.GetValueOrDefault((table, id)));
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken) => throw new NotSupportedException();
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken)
        {
            if (Conflicts-- > 0) throw new TransactionConflictException();
            foreach (var write in writes)
            {
                if (write.Action == "delete") Rows.Remove((write.Table, write.Id));
                else Rows[(write.Table, write.Id)] = new(write.Id, write.Data!.DeepClone().AsObject(), "version");
            }
            return Task.CompletedTask;
        }
    }
}
