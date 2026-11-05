namespace CocEnglish.Contracts;

/// <summary>Stored simulated ad result, current wallet and original daily slot.</summary>
public sealed record AdResponse(string AdEventId, string Placement, string Kind, string LearningDay, long DailyIndex,
    long RemainingToday, long RewardGems, long RewardEnergy, long Gems, bool EnergyGrantPending);
