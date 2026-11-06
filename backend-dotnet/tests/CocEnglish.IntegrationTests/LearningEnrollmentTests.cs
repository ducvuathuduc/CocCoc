using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningEnrollmentTests
{
    [Fact]
    public async Task Deletion_PurgesOnlyUserInBatchesAndAcknowledgesOnce()
    {
        var driver = new Driver(); var store = new OwnerStore(driver, new FixedClock());
        for (var i = 0; i < 85; i++) driver.Rows[("l_answers", "a" + i)] = new() { ["userId"] = "alice" };
        driver.Rows[("l_answers", "bob")] = new() { ["userId"] = "bob" };
        driver.Rows[("l_energy", CanonicalWire.RowId("energy", "alice"))] = new() { ["userId"] = "alice" };
        var deletion = new LearningDeletion(driver, store);
        var request = "22222222-2222-4222-8222-222222222222";
        Assert.Equal("accepted", (await deletion.ApplyAsync("event", "hash", "alice", request, CancellationToken.None)).Status);
        Assert.DoesNotContain(driver.Rows, r => r.Key.Item1 == "l_answers" && r.Value.Text("userId") == "alice");
        Assert.True(driver.Rows.ContainsKey(("l_answers", "bob"))); Assert.False(driver.Rows.ContainsKey(("l_energy", CanonicalWire.RowId("energy", "alice"))));
        var outbox = Assert.Single(driver.Rows, r => r.Key.Item1 == "l_outbox").Value;
        Assert.Equal("account.purged.v1", outbox.Text("type")); Assert.Equal("alice", JsonNode.Parse(outbox.Text("payloadJson")!)!["payload"]!["userId"]!.GetValue<string>());
        Assert.Equal("replayed", (await deletion.ApplyAsync("event", "hash", "alice", request, CancellationToken.None)).Status);
        Assert.Single(driver.Rows, r => r.Key.Item1 == "l_outbox"); Assert.True(driver.MaxWrites <= 80);
    }

    [Fact]
    public async Task EnergyEvents_ApplyOnceAndIgnoreOlderEntitlement()
    {
        var driver = new Driver(); var store = new OwnerStore(driver, new FixedClock());
        var id = CanonicalWire.RowId("energy", "alice");
        driver.Rows[("l_energy", id)] = new() { ["userId"] = "alice", ["mode"] = "LIMITED", ["balance"] = 2, ["capacity"] = 4,
            ["anchorAt"] = "2026-11-03T11:00:00.000Z", ["entitlementRevision"] = 3, ["revision"] = 2,
            ["createdAt"] = "2026-11-01T00:00:00.000Z", ["updatedAt"] = "2026-11-01T00:00:00.000Z" };
        async Task<string> Grant(string hash) => await store.ApplyInboxAsync("event1", "energy.granted.v1", hash,
            (tx, ct) => LearningEnergy.GrantAsync(tx, "alice", 1, false, ct));
        Assert.Equal("accepted", await Grant("hash")); Assert.Equal("replayed", await Grant("hash"));
        Assert.Equal(3, driver.Rows[("l_energy", id)].Number("balance"));
        var conflict = await Assert.ThrowsAsync<ServiceException>(() => Grant("different")); Assert.Equal("IDEMPOTENCY_CONFLICT", conflict.Code);
        await store.TransactAsync(async (tx, ct) => { await LearningEnergy.EntitlementAsync(tx, "alice", "SUPER", "ACTIVE", null, 4, ct); return 0; });
        await store.TransactAsync(async (tx, ct) => { await LearningEnergy.EntitlementAsync(tx, "alice", "FREE", "ACTIVE", null, 3, ct); return 0; });
        Assert.Equal("UNLIMITED", driver.Rows[("l_energy", id)].Text("mode")); Assert.Equal(4, driver.Rows[("l_energy", id)].Number("entitlementRevision"));
    }

    private sealed class FixedClock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T12:00:00Z"); }
    [Fact]
    public async Task Reset_RejectsStaleRevisionAndAbandonsOwnedSession()
    {
        var driver = new Driver(); var store = new OwnerStore(driver, TimeProvider.System);
        var enrollmentId = CanonicalWire.RowId("enrollment", "alice", "course");
        var slotId = CanonicalWire.RowId("slot", "alice", "course");
        driver.Rows[("l_enrollments", enrollmentId)] = JsonNode.Parse("""{"userId":"alice","courseId":"course","courseVersion":"v1","frontierNodeOrder":8,"completedLessonsJson":"[\"l1\"]","masteredNodesJson":"[]","legendaryNodesJson":"[]","placementUsed":false,"active":true,"proficiencyScore":8,"lastPracticedAt":null,"removedAt":null,"revision":4,"createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}""")!.AsObject();
        driver.Rows[("l_active_slots", slotId)] = new() { ["userId"] = "alice", ["courseId"] = "course", ["sessionId"] = "session" };
        driver.Rows[("l_sessions", "session")] = JsonNode.Parse("""{"userId":"alice","courseId":"course","lessonId":"l1","lessonVersion":"v1","rewardIdentity":"l1","mode":"LESSON","source":"ONLINE","status":"ACTIVE","bundleHash":"abc","nextOriginalOrdinal":0,"retryPass":0,"assisted":false,"energySpent":0,"energyEarned":0,"startedAt":"2026-01-01T00:00:00.000Z","expiresAt":"2099-01-01T00:00:00.000Z","resultJson":"{}","revision":0,"createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}""")!.AsObject();
        var manifest = JsonNode.Parse("""{"courseVersion":"v2","sections":[],"nodes":[{"unitId":"u1","order":2}]}""")!.AsObject();
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => LearningEnrollment.CommandAsync(tx, "alice", "course", "resetCourse", 3, manifest, "key", "request", ct)));
        Assert.Equal("REVISION_CONFLICT", error.Code); Assert.True(driver.Rows.ContainsKey(("l_active_slots", slotId)));
        var result = await store.TransactAsync((tx, ct) => LearningEnrollment.CommandAsync(tx, "alice", "course", "resetCourse", 4, manifest, "key", "request", ct));
        Assert.Equal(2, result["frontierNodeOrder"]!.GetValue<long>()); Assert.Equal("v2", result["courseVersion"]!.GetValue<string>());
        Assert.Equal("ABANDONED", driver.Rows[("l_sessions", "session")].Text("status")); Assert.False(driver.Rows.ContainsKey(("l_active_slots", slotId)));
        Assert.Equal("[]", driver.Rows[("l_enrollments", enrollmentId)].Text("completedLessonsJson"));
    }

    [Theory]
    [InlineData("2026-11-04T12:00:00.000Z", "ABANDONED")]
    [InlineData("2026-11-03T11:59:59.000Z", "EXPIRED")]
    public async Task Remove_ClosesItsActiveSessionAndPreservesOtherEnrollments(string expiresAt, string expectedSessionStatus)
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new FixedClock());
        const string userId = "alice";
        const string courseId = "course-a";
        const string sessionId = "session-a";
        var now = "2026-11-03T12:00:00.000Z";
        JsonObject Enrollment(string user, string course, bool active) => new()
        {
            ["userId"] = user, ["courseId"] = course, ["courseVersion"] = "v1", ["frontierNodeOrder"] = 2,
            ["completedLessonsJson"] = "[]", ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]",
            ["placementUsed"] = false, ["active"] = active, ["proficiencyScore"] = 0, ["lastPracticedAt"] = null,
            ["removedAt"] = null, ["revision"] = 3, ["createdAt"] = now, ["updatedAt"] = now
        };
        var enrollmentId = CanonicalWire.RowId("enrollment", userId, courseId);
        var otherEnrollmentId = CanonicalWire.RowId("enrollment", userId, "course-b");
        var slotId = CanonicalWire.RowId("slot", userId, courseId);
        driver.Rows[("l_enrollments", enrollmentId)] = Enrollment(userId, courseId, true);
        driver.Rows[("l_enrollments", otherEnrollmentId)] = Enrollment(userId, "course-b", true);
        driver.Rows[("l_active_slots", slotId)] = new JsonObject
        {
            ["userId"] = userId, ["courseId"] = courseId, ["sessionId"] = sessionId, ["expiresAt"] = expiresAt,
            ["revision"] = 0, ["createdAt"] = now, ["updatedAt"] = now
        };
        driver.Rows[("l_sessions", sessionId)] = new JsonObject
        {
            ["userId"] = userId, ["courseId"] = courseId, ["lessonId"] = "lesson-1", ["lessonVersion"] = "v1",
            ["rewardIdentity"] = "lesson-1", ["mode"] = "LESSON", ["source"] = "ONLINE", ["status"] = "ACTIVE",
            ["bundleHash"] = new string('a', 64), ["bundleSnapshotJson"] = null, ["nextOriginalOrdinal"] = 0,
            ["retryPass"] = 0, ["assisted"] = false, ["energySpent"] = 0, ["energyEarned"] = 0,
            ["startedAt"] = now, ["expiresAt"] = expiresAt, ["completedAt"] = null, ["resultJson"] = "{}",
            ["revision"] = 1, ["createdAt"] = now, ["updatedAt"] = now
        };

        var result = await store.TransactAsync((tx, ct) =>
            LearningEnrollment.CommandAsync(tx, userId, courseId, "removeCourse", null, null, "remove-key", "request-1", ct));

        var removed = driver.Rows[("l_enrollments", enrollmentId)];
        Assert.Equal("accepted", result["status"]!.GetValue<string>());
        Assert.Equal("remove-key", result["operationId"]!.GetValue<string>());
        Assert.False(removed.Flag("active"));
        Assert.Equal(now, removed.Text("removedAt"));
        Assert.Equal(4, removed.Number("revision"));
        Assert.Equal(expectedSessionStatus, driver.Rows[("l_sessions", sessionId)].Text("status"));
        Assert.Null(driver.Rows.GetValueOrDefault(("l_active_slots", slotId)));
        Assert.True(driver.Rows[("l_enrollments", otherEnrollmentId)].Flag("active"));
        Assert.Null(driver.Rows[("l_enrollments", otherEnrollmentId)].Text("removedAt"));
    }

    [Fact]
    public async Task Revival_DeactivatesOnlyOwnersOtherCoursesAndPreservesCreationTime()
    {
        var driver = new Driver(); var store = new OwnerStore(driver, TimeProvider.System);
        var manifest = JsonNode.Parse("""{"courseVersion":"v2","sections":[],"nodes":[{"unitId":"u1","order":3}]}""")!.AsObject();
        var oldId = CanonicalWire.RowId("enrollment", "alice", "old");
        var targetId = CanonicalWire.RowId("enrollment", "alice", "course");
        var bobId = CanonicalWire.RowId("enrollment", "bob", "old");
        JsonObject Row(string user, string course, bool active, string? removed) => new() {
            ["userId"] = user, ["courseId"] = course, ["courseVersion"] = "v1", ["frontierNodeOrder"] = 9,
            ["completedLessonsJson"] = "[\"done\"]", ["masteredNodesJson"] = "[]", ["legendaryNodesJson"] = "[]",
            ["placementUsed"] = false, ["active"] = active, ["proficiencyScore"] = 1, ["lastPracticedAt"] = null,
            ["removedAt"] = removed, ["createdAt"] = "2026-01-01T00:00:00.000Z", ["updatedAt"] = "2026-01-01T00:00:00.000Z", ["revision"] = 4 };
        driver.Rows[("l_enrollments", oldId)] = Row("alice", "old", true, null);
        driver.Rows[("l_enrollments", targetId)] = Row("alice", "course", false, "2026-02-01T00:00:00.000Z");
        driver.Rows[("l_enrollments", bobId)] = Row("bob", "old", true, null);
        var result = await store.TransactAsync((tx, ct) => LearningEnrollment.EnrollAsync(tx, "alice", "course", "beginner", null, manifest, ct));
        var revived = driver.Rows[("l_enrollments", targetId)];
        Assert.Equal(3, result["frontierNodeOrder"]!.GetValue<long>()); Assert.Equal(5, result["revision"]!.GetValue<long>());
        Assert.Equal("2026-01-01T00:00:00.000Z", revived.Text("createdAt")); Assert.Equal("[]", revived.Text("completedLessonsJson"));
        Assert.Null(revived["removedAt"]); Assert.True(revived.Flag("active"));
        Assert.False(driver.Rows[("l_enrollments", oldId)].Flag("active"));
        Assert.Equal(5, driver.Rows[("l_enrollments", oldId)].Number("revision"));
        Assert.True(driver.Rows[("l_enrollments", bobId)].Flag("active"));
    }

    [Fact]
    public async Task Placement_RequiresOwnedCompletedSessionAndCreatesEnrollmentAtomically()
    {
        var driver = new Driver(); var store = new OwnerStore(driver, TimeProvider.System);
        var manifest = JsonNode.Parse("""{"courseVersion":"v1","sections":[{"unitIds":["u1","u2"]}],"nodes":[{"unitId":"u1","order":0},{"unitId":"u2","order":5}]}""")!.AsObject();
        driver.Rows[("l_sessions", "session")] = new() { ["userId"] = "bob", ["courseId"] = "course", ["mode"] = "PLACEMENT", ["status"] = "COMPLETED", ["resultJson"] = "{\"completion\":{\"originalCorrect\":8}}" };
        var other = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => LearningEnrollment.EnrollAsync(tx, "alice", "course", "placement", "session", manifest, ct)));
        Assert.Equal("NOT_FOUND", other.Code); Assert.DoesNotContain(driver.Rows, x => x.Key.Item1 == "l_enrollments");
        driver.Rows[("l_sessions", "session")]["userId"] = "alice";
        var response = await store.TransactAsync((tx, ct) => LearningEnrollment.EnrollAsync(tx, "alice", "course", "placement", "session", manifest, ct));
        Assert.Equal(5, response["frontierNodeOrder"]!.GetValue<long>());
        Assert.Equal(0, response["revision"]!.GetValue<long>());
        var saved = driver.Rows[("l_enrollments", CanonicalWire.RowId("enrollment", "alice", "course"))];
        Assert.True(saved.Flag("active")); Assert.True(saved.Flag("placementUsed"));
        var repeated = await store.TransactAsync((tx, ct) => LearningEnrollment.EnrollAsync(tx, "alice", "course", "beginner", null, manifest, ct));
        Assert.Equal(5, repeated["frontierNodeOrder"]!.GetValue<long>()); Assert.Equal(0, repeated["revision"]!.GetValue<long>());
    }

    private sealed class Driver : IRowDriver
    {
        public string Owner => "learning"; public bool Configured => true;
        public int MaxWrites { get; private set; }
        public Dictionary<(string, string), JsonObject> Rows { get; } = [];
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => Task.FromResult(Rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), null) : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => Task.FromResult<IReadOnlyList<RowDocument>>(Rows.Where(p => p.Key.Item1 == table && (query.Where is null || query.Where.All(q => JsonNode.DeepEquals(p.Value[q.Key], System.Text.Json.JsonSerializer.SerializeToNode(q.Value))))).Take(query.Limit).Select(p => new RowDocument(p.Key.Item2, p.Value.DeepClone().AsObject(), null)).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        { MaxWrites = Math.Max(MaxWrites, writes.Count); foreach (var write in writes) if (write.Action == "delete") Rows.Remove((write.Table, write.Id)); else Rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject(); return Task.CompletedTask; }
    }
}
