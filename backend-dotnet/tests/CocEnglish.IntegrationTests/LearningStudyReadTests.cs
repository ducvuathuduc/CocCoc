using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CocEnglish.Learning;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningStudyReadTests
{
    [Fact]
    public async Task Mistakes_AreOwnerScopedOrderedFilteredAndPaginated()
    {
        var driver = new Driver();
        driver.Seed("l_mistakes", "older", Mistake("alice", "course", "older-exercise", "2026-11-01T10:00:00.000Z", null));
        driver.Seed("l_mistakes", "newer", Mistake("alice", "course", "newer-exercise", "2026-11-02T10:00:00.000Z", null));
        driver.Seed("l_mistakes", "resolved", Mistake("alice", "course", "resolved-exercise", "2026-11-03T10:00:00.000Z", "2026-11-03T11:00:00.000Z"));
        driver.Seed("l_mistakes", "foreign", Mistake("bob", "course", "foreign-exercise", "2026-11-04T10:00:00.000Z", null));
        driver.Seed("l_mistakes", "other-course", Mistake("alice", "other", "other-exercise", "2026-11-05T10:00:00.000Z", null));
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        var first = (await client.GetFromJsonAsync<JsonObject>("/v1/mistakes?courseId=course&limit=1"))!;
        Assert.Equal("newer-exercise", first["items"]![0]!["exerciseId"]!.GetValue<string>());
        Assert.Equal("bzox", first["nextCursor"]!.GetValue<string>());
        var second = (await client.GetFromJsonAsync<JsonObject>("/v1/mistakes?courseId=course&limit=1&cursor=bzox"))!;
        Assert.Equal("older-exercise", second["items"]![0]!["exerciseId"]!.GetValue<string>());
        Assert.Null(second["nextCursor"]);

        var all = (await client.GetFromJsonAsync<JsonObject>("/v1/mistakes?courseId=course&includeResolved=true"))!;
        Assert.Equal(3, all["items"]!.AsArray().Count);
        Assert.Equal("resolved-exercise", all["items"]![0]!["exerciseId"]!.GetValue<string>());
        Assert.Equal("2026-11-03T11:00:00.000Z", all["items"]![0]!["resolvedAt"]!.GetValue<string>());

        client.DefaultRequestHeaders.Authorization = new("Bearer", "bob");
        var bob = (await client.GetFromJsonAsync<JsonObject>("/v1/mistakes?courseId=course"))!;
        Assert.Single(bob["items"]!.AsArray());
        Assert.Equal("foreign-exercise", bob["items"]![0]!["exerciseId"]!.GetValue<string>());
        using var invalid = await client.GetAsync("/v1/mistakes?courseId=course&includeResolved=1");
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        using var duplicate = await client.GetAsync("/v1/mistakes?courseId=course&courseId=other");
        Assert.Equal(HttpStatusCode.BadRequest, duplicate.StatusCode);
    }

    [Fact]
    public async Task Activities_FilterByKindAndPaginateByActivityId()
    {
        var driver = new Driver();
        driver.Seed("l_activity_progress", "radio", Activity("alice", "course", "RADIO", "radio-1", 3, 86, 2));
        driver.Seed("l_activity_progress", "adventure", Activity("alice", "course", "ADVENTURE", "adventure-1", 2, 91, 3));
        driver.Seed("l_activity_progress", "foreign", Activity("bob", "course", "RADIO", "radio-2", 1, 50, 1));
        using var app = CreateApp(driver);
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        var radio = (await client.GetFromJsonAsync<JsonObject>("/v1/activities?courseId=course&kind=RADIO"))!;
        Assert.Single(radio["items"]!.AsArray());
        Assert.Equal("radio-1", radio["items"]![0]!["activityId"]!.GetValue<string>());
        Assert.Equal(86, radio["items"]![0]!["bestScore"]!.GetValue<long>());

        var first = (await client.GetFromJsonAsync<JsonObject>("/v1/activities?courseId=course&limit=1"))!;
        Assert.Equal("adventure-1", first["items"]![0]!["activityId"]!.GetValue<string>());
        Assert.Equal("bzox", first["nextCursor"]!.GetValue<string>());
        var second = (await client.GetFromJsonAsync<JsonObject>("/v1/activities?courseId=course&limit=1&cursor=bzox"))!;
        Assert.Equal("radio-1", second["items"]![0]!["activityId"]!.GetValue<string>());
        using var invalidKind = await client.GetAsync("/v1/activities?courseId=course&kind=OTHER");
        Assert.Equal(HttpStatusCode.BadRequest, invalidKind.StatusCode);
    }

    [Fact]
    public async Task Review_ListsOnlyOwnedDueItemsAndInterleavesSkills()
    {
        var driver = new Driver();
        driver.Seed("l_review_items", "v1", Review("alice", "course", "v1", "reading", "2026-11-01T10:00:00.000Z", "2026-11-01T11:00:00.000Z", 1, [true, true, true, true, false, false]));
        driver.Seed("l_review_items", "v2", Review("alice", "course", "v2", "reading", "2026-11-01T10:01:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "v3", Review("alice", "course", "v3", "reading", "2026-11-01T10:02:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "v4", Review("alice", "course", "v4", "listening", "2026-11-01T10:03:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "v5", Review("alice", "course", "v5", "reading", "2026-11-01T10:04:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "future", Review("alice", "course", "future", "reading", "2999-01-01T00:00:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "foreign", Review("bob", "course", "foreign", "reading", "2026-11-01T10:00:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        driver.Seed("l_review_items", "other-course", Review("alice", "other", "other-course", "reading", "2026-11-01T10:00:00.000Z", "2026-11-01T11:00:00.000Z", 0, []));
        using var app = CreateApp(driver, now: DateTimeOffset.Parse("2026-11-03T12:00:00Z"));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        var first = (await client.GetFromJsonAsync<JsonObject>("/v1/review?courseId=course&limit=2"))!;
        Assert.Equal(new[] { "v1", "v2" }, first["items"]!.AsArray().Select(item => item!["vocabularyId"]!.GetValue<string>()));
        Assert.Equal("bzoy", first["nextCursor"]!.GetValue<string>());
        Assert.Equal(0.667, first["items"]![0]! ["mastery"]!.GetValue<double>());
        Assert.Equal("2026-11-03T12:00:00.000Z", first["asOf"]!.GetValue<string>());

        var rest = (await client.GetFromJsonAsync<JsonObject>("/v1/review?courseId=course&cursor=bzoy"))!;
        Assert.Equal(new[] { "v4", "v3", "v5" }, rest["items"]!.AsArray().Select(item => item!["vocabularyId"]!.GetValue<string>()));
        Assert.Null(rest["nextCursor"]);
        using var invalidCursor = await client.GetAsync("/v1/review?cursor=");
        Assert.Equal(HttpStatusCode.BadRequest, invalidCursor.StatusCode);
    }

    [Fact]
    public async Task Words_UsesPublishedMatchPairsFallbackStrengthSortAndPagination()
    {
        var driver = new Driver();
        driver.Seed("l_review_items", "apple", Word("alice", "course", "fruit.apple", "vocabulary", "2026-11-01T12:00:00.000Z", "2026-11-02T12:00:00.000Z", 24, 2, 1));
        driver.Seed("l_review_items", "fallback", Word("alice", "course", "other.zebra", "vocabulary", "2026-11-02T12:00:00.000Z", "2026-11-03T11:00:00.000Z", 48, 3, 0));
        driver.Seed("l_review_items", "foreign", Word("bob", "course", "fruit.foreign", "vocabulary", "2026-11-02T12:00:00.000Z", "2026-11-03T11:00:00.000Z", 48, 3, 0));
        var content = new ContentReader();
        content.Bundles["lesson"] = new JsonObject
        {
            ["exercises"] = new JsonArray(new JsonObject
            {
                ["type"] = "matchPairs",
                ["vocabularyIds"] = new JsonArray("fruit.apple"),
                ["content"] = new JsonObject { ["pairs"] = new JsonArray(new JsonObject
                {
                    ["left"] = new JsonObject { ["text"] = "Apple" },
                    ["right"] = new JsonObject { ["text"] = "Táo" }
                }) }
            })
        };
        using var app = CreateApp(driver, content, DateTimeOffset.Parse("2026-11-03T12:00:00Z"));
        using var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "alice");

        var first = (await client.GetFromJsonAsync<JsonObject>("/v1/words?courseId=course&sort=ALPHABETICAL&limit=1"))!;
        var apple = first["items"]![0]!;
        Assert.Equal("fruit.apple", apple["vocabularyId"]!.GetValue<string>());
        Assert.Equal("Apple", apple["term"]!.GetValue<string>());
        Assert.Equal("Táo", apple["translation"]!.GetValue<string>());
        Assert.Equal(2, apple["strength"]!.GetValue<int>());
        Assert.Equal("bzox", first["nextCursor"]!.GetValue<string>());

        var second = (await client.GetFromJsonAsync<JsonObject>("/v1/words?courseId=course&sort=ALPHABETICAL&limit=1&cursor=bzox"))!;
        Assert.Equal("other.zebra", second["items"]![0]!["vocabularyId"]!.GetValue<string>());
        Assert.Equal("zebra", second["items"]![0]!["term"]!.GetValue<string>());
        Assert.Null(second["items"]![0]!["translation"]);
        Assert.Null(second["nextCursor"]);
        using var invalidSort = await client.GetAsync("/v1/words?courseId=course&sort=NEWEST");
        Assert.Equal(HttpStatusCode.BadRequest, invalidSort.StatusCode);
    }

    private static WebApplicationFactory<Learning.Program> CreateApp(Driver driver, ILearningContentReader? content = null, DateTimeOffset? now = null) =>
        new WebApplicationFactory<Learning.Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["APPWRITE_ENDPOINT"] = "https://appwrite.test/v1",
                ["APPWRITE_PROJECT_ID"] = "test",
                ["COC_LEARNING_APPWRITE_KEY"] = "test-key",
                ["COC_LEARNING_PERSISTENCE"] = "appwrite",
                ["COC_LEARNING_ADMITTED"] = "reviewed-cloud-gate"
            }));
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IRowDriver>();
                services.AddSingleton<IRowDriver>(driver);
                services.RemoveAll<IIdentityVerifier>();
                services.AddSingleton<IIdentityVerifier, Identity>();
                if (content is not null)
                {
                    services.RemoveAll<ILearningContentReader>();
                    services.AddSingleton(content);
                }
                if (now is not null)
                {
                    services.RemoveAll<TimeProvider>();
                    services.AddSingleton<TimeProvider>(new Clock(now.Value));
                }
            });
        });

    private static JsonObject Mistake(string user, string course, string exercise, string at, string? resolvedAt) => new()
    {
        ["userId"] = user, ["courseId"] = course, ["exerciseId"] = exercise, ["lessonVersion"] = "v1", ["skillId"] = "general",
        ["mistakeCount"] = 2, ["lastMistakeAt"] = at, ["resolvedAt"] = resolvedAt
    };

    private static JsonObject Activity(string user, string course, string kind, string activity, long completions, long score, long stars) => new()
    {
        ["userId"] = user, ["courseId"] = course, ["kind"] = kind, ["activityId"] = activity, ["completions"] = completions,
        ["bestScore"] = score, ["stars"] = stars, ["firstCompletedAt"] = "2026-11-01T10:00:00.000Z", ["lastCompletedAt"] = null
    };

    private static JsonObject Review(string user, string course, string vocabulary, string skill, string due, string lastReviewed, long incorrect, bool[] window) => new()
    {
        ["userId"] = user, ["courseId"] = course, ["vocabularyId"] = vocabulary, ["skillId"] = skill, ["dueAt"] = due,
        ["lastReviewedAt"] = lastReviewed, ["incorrectCount"] = incorrect, ["stage"] = 2,
        ["firstAttemptWindowJson"] = System.Text.Json.JsonSerializer.Serialize(window)
    };

    private static JsonObject Word(string user, string course, string vocabulary, string skill, string firstSeen, string lastReviewed, long halfLife, long correct, long incorrect) => new()
    {
        ["userId"] = user, ["courseId"] = course, ["vocabularyId"] = vocabulary, ["skillId"] = skill,
        ["stage"] = 2, ["halfLifeHours"] = halfLife, ["correctCount"] = correct, ["incorrectCount"] = incorrect,
        ["firstSeenAt"] = firstSeen, ["lastReviewedAt"] = lastReviewed, ["dueAt"] = "2026-11-04T12:00:00.000Z"
    };

    private sealed class Clock(DateTimeOffset now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now; }

    private sealed class ContentReader : ILearningContentReader
    {
        public Dictionary<string, JsonObject> Bundles { get; } = new(StringComparer.Ordinal);
        public Task<JsonObject> PublishedAsync(string courseId, CancellationToken cancellationToken) => Task.FromResult(new JsonObject
        {
            ["bundles"] = new JsonArray(new JsonObject { ["lessonId"] = "lesson" })
        });
        public Task<JsonObject> BundleAsync(JsonObject manifest, string lessonId, CancellationToken cancellationToken) =>
            Task.FromResult(Bundles[lessonId].DeepClone().AsObject());
        public Task<JsonObject> BundleByLessonVersionAsync(string courseId, string lessonId, string lessonVersion, CancellationToken cancellationToken) =>
            Task.FromResult(Bundles[lessonId].DeepClone().AsObject());
    }

    private sealed class Identity : IIdentityVerifier
    {
        public bool Configured => true;
        public Task<VerifiedSubject> VerifyAsync(string jwt, CancellationToken cancellationToken) => Task.FromResult(new VerifiedSubject(jwt));
    }

    private sealed class Driver : IRowDriver
    {
        private readonly Dictionary<(string Table, string Id), JsonObject> _rows = [];
        public string Owner => "learning";
        public bool Configured => true;
        public void Seed(string table, string id, JsonObject row) => _rows[(table, id)] = row;
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken cancellationToken) =>
            Task.FromResult(_rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), null) : null);

        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken cancellationToken)
        {
            IEnumerable<KeyValuePair<(string Table, string Id), JsonObject>> selected = _rows.Where(entry => entry.Key.Table == table);
            foreach (var (key, value) in query.Where ?? new Dictionary<string, object?>())
                selected = value is null
                    ? selected.Where(entry => entry.Value[key] is null)
                    : selected.Where(entry => entry.Value[key]?.ToString() == value.ToString());
            foreach (var (key, value) in query.LessThanEqual ?? new Dictionary<string, object?>())
                selected = selected.Where(entry => entry.Value[key] is not null && StringComparer.Ordinal.Compare(
                    entry.Value[key]!.GetValue<string>(), value?.ToString()) <= 0);
            foreach (var order in query.OrderBy ?? [])
                selected = order.Descending
                    ? selected.OrderByDescending(entry => entry.Value[order.Column]?.GetValue<string>(), StringComparer.Ordinal)
                    : selected.OrderBy(entry => entry.Value[order.Column]?.GetValue<string>(), StringComparer.Ordinal);
            var rows = selected.Skip(query.Offset).Take(query.Limit)
                .Select(entry => new RowDocument(entry.Key.Id, entry.Value.DeepClone().AsObject(), null)).ToArray();
            return Task.FromResult<IReadOnlyList<RowDocument>>(rows);
        }

        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken cancellationToken) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken cancellationToken) => throw new ServiceException("INTERNAL_ERROR");
    }
}
