using System.Text.RegularExpressions;
using CocEnglish.Contracts;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Progress.Endpoints;

[ApiController]
public sealed class ProgressReadController(IProgressReads reads) : ControllerBase
{
    private string UserId => ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;

    /// <summary>Read the verified account's preferences without creating defaults in storage.</summary>
    [HttpGet("/v1/me/preferences")]
    [ContractOperation("getPreferences")]
    [ProducesResponseType<PreferencesResponse>(200)]
    public Task<PreferencesResponse> Preferences(CancellationToken ct) => reads.GetPreferencesAsync(UserId, ct);

    /// <summary>Read the account's current daily, monthly and friend quests.</summary>
    [HttpGet("/v1/quests")]
    [ContractOperation("listQuests")]
    [ProducesResponseType<QuestPageResponse>(200)]
    public Task<QuestPageResponse> Quests(CancellationToken ct)
    {
        var (offset, limit) = ProgressPaging.Parse(Request);
        return reads.GetQuestsAsync(UserId, offset, limit, ct);
    }

    /// <summary>Read only the verified account's profile.</summary>
    [HttpGet("/v1/me")]
    [ContractOperation("getMe")]
    [ProducesResponseType<ProfileResponse>(200)]
    public Task<ProfileResponse> Me(CancellationToken ct) => reads.GetMeAsync(UserId, ct);

    /// <summary>Read own authoritative reward totals and optional completion credit.</summary>
    [HttpGet("/v1/me/rewards")]
    [ContractOperation("getRewards")]
    [ProducesResponseType<RewardsResponse>(200)]
    public Task<RewardsResponse> Rewards(CancellationToken ct)
    {
        var query = RequestQuery.Parse(Request, "completionId");
        var completionId = query.GetValueOrDefault("completionId");
        if (completionId is not null && !Regex.IsMatch(completionId, "^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$", RegexOptions.CultureInvariant))
            throw RequestQuery.Bad("completionId");
        return reads.GetRewardsAsync(UserId, completionId, ct);
    }

    /// <summary>Read own bounded 28-day history, using the server's learning calendar.</summary>
    [HttpGet("/v1/me/learning-stats")]
    [ContractOperation("getLearningStats")]
    [ProducesResponseType<LearningStatsResponse>(200)]
    public Task<LearningStatsResponse> Statistics(CancellationToken ct)
    {
        RequestQuery.Parse(Request);
        return reads.GetLearningStatsAsync(UserId, ct);
    }
}
