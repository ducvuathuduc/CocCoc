using System.Text.Json.Nodes;
using CocEnglish.Shared.Hosting;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.AI;

[ApiController]
public sealed class AiCapabilitiesController(IAiSpeechEngine speech) : ControllerBase
{
    /// <summary>Expose only AI features that this migrated host can safely serve.</summary>
    [HttpGet("/v1/ai/capabilities")]
    [ContractOperation("getCapabilities")]
    [ProducesResponseType<JsonObject>(200)]
    public JsonObject Get(CancellationToken cancellationToken)
    {
        _ = RequestQuery.Parse(Request);
        return new JsonObject
        {
            ["configVersion"] = speech.ConfigVersion,
            ["textTutor"] = true,
            ["nativeLive"] = false,
            ["turnSpeech"] = speech.Enabled,
            ["pronunciation"] = speech.AzureEnabled,
            ["offlineShadowing"] = true,
            ["nativeLiveReason"] = "NATIVE_LIVE_DISABLED",
            ["pronunciationReason"] = speech.AzureEnabled ? null : "AZURE_DISABLED",
            ["liveUiMaxSeconds"] = 180,
            ["dailyLiveSessionLimit"] = 0
        };
    }
}
