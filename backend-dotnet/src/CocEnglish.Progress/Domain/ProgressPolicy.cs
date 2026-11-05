using CocEnglish.Contracts;
using System.Globalization;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace CocEnglish.Progress.Domain;

public static class QuestChestPolicy
{
    public static string NewOperation() => "ch1_" + Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(12));
    public static QuestChestResponse? Receipt(string operation, long baseGems)
    {
        if (baseGems <= 0 || !Regex.IsMatch(operation, "^ch1_[0-9a-f]{24}$", RegexOptions.CultureInvariant)) return null;
        var rolls = Convert.FromHexString(operation[4..]);
        string[] ranks = ["COMMON", "RARE", "EPIC", "MEGA"];
        var rank = 0;
        var tiers = new List<string> { "COMMON" };
        for (var i = 0; i < 3; i++)
        {
            if (rolls[i] < 64) rank = Math.Min(3, rank + 1);
            tiers.Add(ranks[rank]);
        }
        return new(operation, tiers, baseGems * (1L << rank));
    }
}

public sealed record QuestTemplate(string Id, string Period, long Target, long Gems, bool Badge = false);
public sealed record ShopTemplate(string Id, string Kind, long Price, long MaxOwned, long? Minutes, long Multiplier = 1, bool Available = true);

public static class ProgressCatalog
{
    public const string ShopVersion = "shop-v1";
    public static IReadOnlyList<ShopTemplate> Shop { get; } = Array.AsReadOnly(new ShopTemplate[]
    {
        new("streak_freeze", "FREEZE", 20, 5, null), new("streak_repair", "STREAK_REPAIR", 100, 1, null),
        new("xp_boost_15", "XP_BOOST", 100, 3, 15, 2), new("timer_boost", "TIMER_BOOST", 50, 5, 5),
        new("energy_refill", "ENERGY_REFILL", 50, 0, null), new("weekend_amulet", "WEEKEND_AMULET", 150, 1, null, Available: false)
    });
    public static IReadOnlyList<QuestTemplate> Quests { get; } = Array.AsReadOnly(new QuestTemplate[]
    {
        new("daily_lessons", "DAY", 2, 5), new("daily_correct", "DAY", 15, 5),
        new("daily_review", "DAY", 1, 5), new("monthly_active_days", "MONTH", 20, 0, true)
    });
    public static long FreezeCapacity(long currentStreak) => currentStreak >= 365 ? 5 : 2;
}

public static class ProgressCalendar
{
    public static DateOnly Day(string value) => DateOnly.ParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture);
    public static string DayKey(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    public static DateOnly ZonedDay(DateTimeOffset instant, string zone) => DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(instant, TimeZoneInfo.FindSystemTimeZoneById(zone)).DateTime);
    public static string LeagueWeek(DateTimeOffset instant)
    {
        var day = DateOnly.FromDateTime(instant.UtcDateTime);
        return DayKey(day.AddDays(-(((int)day.DayOfWeek + 6) % 7)));
    }
}
