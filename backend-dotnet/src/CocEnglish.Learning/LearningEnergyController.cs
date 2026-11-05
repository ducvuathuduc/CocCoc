using System.Text.Json.Nodes;
using CocEnglish.Shared.Hosting;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Microsoft.AspNetCore.Mvc;

namespace CocEnglish.Learning;

[ApiController]
public sealed class LearningEnergyController(IRowDriver rows, TimeProvider clock, IConfiguration config) : ControllerBase
{
    /// <summary>Read the authenticated learner's energy balance.</summary>
    [HttpGet("/v1/me/energy")]
    [ContractOperation("getEnergy")]
    [ProducesResponseType<JsonObject>(200)]
    public async Task<JsonObject> Get(CancellationToken ct)
    {
        RequestQuery.Parse(Request);
        var user = ((VerifiedSubject)HttpContext.Items[typeof(VerifiedSubject)]!).UserId;
        var row = (await rows.ReadAsync("l_energy", CanonicalWire.RowId("energy", user), ct))?.Data;
        return LearningEnergy.View(row, clock.GetUtcNow(), config["COC_ENERGY_MODE"] ?? "UNLIMITED");
    }
}
