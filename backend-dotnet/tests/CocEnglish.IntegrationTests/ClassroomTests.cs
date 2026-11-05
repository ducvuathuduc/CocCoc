using CocEnglish.Progress.Application;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class ClassroomTests
{
    [Fact]
    public async Task Membership_NormalizesCodeAndJoinLeaveAreIdempotent()
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows[("p_classrooms", "class")] = new() { ["classroomId"] = "class", ["joinCodeHash"] = CanonicalWire.Sha256("ABCD"), ["status"] = "ACTIVE", ["name"] = "English", ["courseId"] = "vi_en" };
        var app = new ProgressClassrooms();
        var first = await store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", "ab-cd", ct));
        Assert.Equal("class", first.ClassroomId);
        Assert.Equal("English", first.Name);
        Assert.Equal("vi_en", first.CourseId);
        Assert.Equal("ACTIVE", first.Status);
        var commits = fixture.Driver.Commits;
        fixture.Now = fixture.Now.AddDays(1);
        Assert.Equal(first, await store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", "ABCD", ct)));
        Assert.Equal(commits, fixture.Driver.Commits);
        Assert.Equal("completed", await store.TransactAsync((tx, ct) => app.LeaveAsync(tx, "alice", "class", ct)));
        Assert.Equal("replayed", await store.TransactAsync((tx, ct) => app.LeaveAsync(tx, "alice", "class", ct)));
        var rejoin = await store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", "ABCD", ct));
        Assert.Equal(fixture.Now, rejoin.JoinedAt);
        Assert.Equal("CLASSROOM_CODE_INVALID", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.JoinAsync(tx, "alice", "UNKNOWN", ct)))).Code);
    }

    [Fact]
    public async Task Year_IgnoresMissingOrNullAchievementDatesAndCountsOnlyTheRequestedYear()
    {
        await using var fixture = new ProgressApiFixture();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        fixture.Driver.Rows[("p_achievements", "missing-date")] = new() { ["userId"] = "alice", ["achievementId"] = "missing-date", ["tier"] = 1 };
        fixture.Driver.Rows[("p_achievements", "null-date")] = new() { ["userId"] = "alice", ["achievementId"] = "null-date", ["tier"] = 1, ["earnedAt"] = null };
        fixture.Driver.Rows[("p_achievements", "other-year")] = new() { ["userId"] = "alice", ["achievementId"] = "other-year", ["tier"] = 1, ["earnedAt"] = "2024-12-31T23:59:59Z" };
        fixture.Driver.Rows[("p_achievements", "in-year")] = new() { ["userId"] = "alice", ["achievementId"] = "in-year", ["tier"] = 1, ["earnedAt"] = "2025-12-31T23:59:59Z" };
        var app = new ProgressClassrooms();

        var result = await store.TransactAsync((tx, ct) => app.YearAsync(tx, "alice", 2025, ct));

        Assert.Equal(1, result.AchievementsEarned);
    }

    [Theory]
    [InlineData(2025, true)]
    [InlineData(2026, false)]
    public async Task Year_SumsOwnDaysAndFreezesOnlyFinishedYears(int year, bool frozen)
    {
        await using var fixture = new ProgressApiFixture();
        using var client = fixture.CreateClient();
        using var scope = fixture.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<OwnerStore>();
        foreach (var (id, owner, day, active, protect, xp) in new[] { ("one", "alice", "01-01", true, false, 10), ("two", "alice", "01-02", false, true, 0), ("three", "alice", "01-03", true, false, 20), ("foreign", "bob", "01-01", true, false, 999) })
            fixture.Driver.Rows[("p_day_activity", id)] = new() { ["userId"] = owner, ["day"] = year + "-" + day, ["active"] = active, ["protected"] = protect, ["studyXp"] = xp, ["completedLessons"] = active ? 1 : 0, ["minutesSpent"] = 5 };
        var app = new ProgressClassrooms();
        var result = await store.TransactAsync((tx, ct) => app.YearAsync(tx, "alice", year, ct));
        Assert.Equal(30, result.TotalXp);
        Assert.Equal(2, result.ActiveDays);
        Assert.Equal(3, result.LongestStreak);
        Assert.Equal(2, result.LessonsCompleted);
        Assert.Equal(15, result.MinutesSpent);
        Assert.Equal(0, result.WordsLearned);
        Assert.Empty(result.CourseIds);
        Assert.Null(result.TopLeagueTier);
        Assert.Equal(frozen ? 1 : 0, fixture.Driver.Commits);
        fixture.Driver.Rows[("p_day_activity", "one")]["studyXp"] = 99;
        var next = await store.TransactAsync((tx, ct) => app.YearAsync(tx, "alice", year, ct));
        Assert.Equal(frozen ? 30 : 119, next.TotalXp);
        Assert.Equal(frozen ? 1 : 0, fixture.Driver.Commits);
        Assert.Equal("NOT_FOUND", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.YearAsync(tx, "alice", 2027, ct)))).Code);
    }
}
