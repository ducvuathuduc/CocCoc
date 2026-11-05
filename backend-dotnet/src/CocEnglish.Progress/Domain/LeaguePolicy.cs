namespace CocEnglish.Progress.Domain;

public static class LeaguePolicy
{
    public static string Movement(int rank, int size, long tier) => size < 10 ? "STAY" : rank <= 5 && tier < 9 ? "PROMOTE" : rank > size - 5 && tier > 0 ? "DEMOTE" : "STAY";
    public static long NextTier(long tier, string movement) => movement == "PROMOTE" ? Math.Min(9, tier + 1) : movement == "DEMOTE" ? Math.Max(0, tier - 1) : tier;
}
