using CocEnglish.Contracts;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using System.Text.Json.Nodes;
using System.Text;
using System.Text.RegularExpressions;
using System.Globalization;
using static CocEnglish.Progress.Domain.ProgressCalendar;

namespace CocEnglish.Progress.Application;

public sealed class ProgressClassrooms
{
    public async Task<ClassroomMembershipResponse> JoinAsync(OwnerSession tx, string user, string code, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var normalized = Regex.Replace(code.Normalize(NormalizationForm.FormKC).ToUpperInvariant(), "[\\s\uFEFF-]+", "");
        var rows = await tx.ListAsync("p_classrooms", new(Where: new Dictionary<string, object?> { ["joinCodeHash"] = CanonicalWire.Sha256(normalized), ["status"] = "ACTIVE" }, Limit: 1), ct);
        var classroom = rows.FirstOrDefault()?.Data ?? throw new ServiceException("CLASSROOM_CODE_INVALID");
        var classroomId = classroom.Text("classroomId")!;
        var id = CanonicalWire.RowId("p_classroom_members", classroomId, user);
        var member = await tx.GetAsync("p_classroom_members", id, ct);
        var joined = member?.Text("status") == "ACTIVE" ? DateTimeOffset.Parse(member.Text("joinedAt")!, CultureInfo.InvariantCulture) : tx.Now;
        if (member?.Text("status") != "ACTIVE")
        {
            member ??= new();
            member["classroomId"] = classroomId; member["userId"] = user; member["joinedAt"] = OwnerSchema.Iso(joined); member["status"] = "ACTIVE";
            tx.Put("p_classroom_members", id, member);
        }
        return new(classroomId, classroom.Text("name")!, classroom.Text("courseId")!, "ACTIVE", joined);
    }
    public async Task<string> LeaveAsync(OwnerSession tx, string user, string classroomId, CancellationToken ct)
    {
        await ProgressReads.RequireProfile(tx, user, ct);
        var id = CanonicalWire.RowId("p_classroom_members", classroomId, user);
        var row = await tx.GetAsync("p_classroom_members", id, ct);
        if (row?.Text("status") != "ACTIVE") return "replayed";
        row["status"] = "LEFT"; tx.Put("p_classroom_members", id, row);
        return "completed";
    }
    public async Task<YearReviewResponse> YearAsync(OwnerSession tx, string user, int year, CancellationToken ct)
    {
        var profile = await ProgressReads.RequireProfile(tx, user, ct);
        var currentYear = ZonedDay(tx.Now, profile.Text("learningZone") ?? "UTC").Year;
        if (year < 2020 || year > currentYear) throw new ServiceException("NOT_FOUND");
        var id = CanonicalWire.RowId("p_year_reviews", user, year.ToString(CultureInfo.InvariantCulture));
        if (await tx.GetAsync("p_year_reviews", id, ct) is { } stored)
        {
            var snapshot = JsonNode.Parse(stored.Text("snapshotJson")!)!.AsObject();
            return View(snapshot, DateTimeOffset.Parse(stored.Text("generatedAt")!, CultureInfo.InvariantCulture));
        }
        var days = await tx.ListAsync("p_day_activity", new(Where: new Dictionary<string, object?> { ["userId"] = user },
            GreaterThanEqual: new Dictionary<string, object?> { ["day"] = $"{year}-01-01" }, LessThan: new Dictionary<string, object?> { ["day"] = $"{year + 1}-01-01" }, OrderBy: [new("day")], Limit: 366), ct);
        long longest = 0, run = 0, xp = 0, active = 0, lessons = 0, minutes = 0;
        DateOnly? previous = null;
        foreach (var document in days)
        {
            var row = document.Data;
            xp += row.Number("studyXp"); lessons += row.Number("completedLessons"); minutes += row.Number("minutesSpent");
            if (row.Flag("active")) active++;
            if (row.Flag("active") || row.Flag("protected"))
            {
                var day = Day(row.Text("day")!);
                run = previous?.AddDays(1) == day ? run + 1 : 1;
                previous = day; longest = Math.Max(longest, run);
            }
        }
        var achievements = await tx.ListAsync("p_achievements", new(Where: new Dictionary<string, object?> { ["userId"] = user }, Limit: 200), ct);
        var league = await tx.GetAsync("p_league_profiles", CanonicalWire.RowId("p_league_profiles", user), ct);
        var result = new JsonObject { ["totalXp"] = xp, ["activeDays"] = active, ["longestStreak"] = longest, ["lessonsCompleted"] = lessons,
            ["wordsLearned"] = 0, ["minutesSpent"] = minutes, ["achievementsEarned"] = achievements.Count(a => a.Data.Text("earnedAt")?.StartsWith(year.ToString(CultureInfo.InvariantCulture), StringComparison.Ordinal) == true),
            ["topLeagueTier"] = league?.Number("weeksParticipated") > 0 ? JsonValue.Create(league.Number("tier")) : null, ["courseIds"] = new JsonArray() };
        if (year < currentYear) tx.Put("p_year_reviews", id, new() { ["userId"] = user, ["year"] = year, ["snapshotJson"] = CanonicalWire.Stringify(result), ["generatedAt"] = tx.NowIso });
        return View(result, tx.Now);
        YearReviewResponse View(JsonObject row, DateTimeOffset generated) => new(year, generated, row.Number("totalXp"), row.Number("activeDays"), row.Number("longestStreak"),
            row.Number("lessonsCompleted"), row.Number("wordsLearned"), row.Number("minutesSpent"), row.Number("achievementsEarned"), row["topLeagueTier"] is null ? null : row.Number("topLeagueTier"),
            row["courseIds"]!.AsArray().Select(v => v!.GetValue<string>()).ToArray());
    }
}
