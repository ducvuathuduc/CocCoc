using System.Text.Json.Nodes;
using CocEnglish.Learning;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningEnergyTests
{
    [Fact]
    public void View_RegeneratesAtUnitBoundariesAndRespectsUnlimitedMode()
    {
        var now = DateTimeOffset.Parse("2026-11-03T12:00:00Z");
        var row = new JsonObject { ["mode"] = "LIMITED", ["capacity"] = 4, ["balance"] = 1, ["anchorAt"] = "2026-11-03T00:00:00.000Z", ["revision"] = 7 };
        var limited = LearningEnergy.View(row, now, "LIMITED");
        Assert.Equal(3, limited["balance"]!.GetValue<long>()); Assert.Equal("2026-11-03T18:00:00.000Z", limited["nextUnitAt"]!.GetValue<string>());
        Assert.Equal("2026-11-03T18:00:00.000Z", limited["fullAt"]!.GetValue<string>());
        var unlimited = LearningEnergy.View(row, now, "UNLIMITED");
        Assert.Equal(4, unlimited["balance"]!.GetValue<long>()); Assert.Null(unlimited["nextUnitAt"]);
        row["mode"] = "UNLIMITED";
        Assert.Equal("UNLIMITED", LearningEnergy.View(row, now, "LIMITED")["mode"]!.GetValue<string>());
        Assert.Equal(25, LearningEnergy.View(null, now, "LIMITED")["balance"]!.GetValue<long>());
    }
}
