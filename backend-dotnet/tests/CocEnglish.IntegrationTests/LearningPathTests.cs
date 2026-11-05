using System.Text.Json.Nodes;
using CocEnglish.Learning;
using Xunit;

namespace CocEnglish.IntegrationTests;

public sealed class LearningPathTests
{
    [Fact]
    public void NodeState_UsesMasteryThenFrontierAndCompletedLessons()
    {
        var node = JsonNode.Parse("""{"nodeId":"n1","order":3,"lessonIds":["l1","l2"]}""")!.AsObject();
        Assert.Equal("mastered", LearningPath.NodeState(node, 2, [], ["n1"]));
        Assert.Equal("completed", LearningPath.NodeState(node, 4, [], []));
        Assert.Equal("locked", LearningPath.NodeState(node, 2, [], []));
        Assert.Equal("available", LearningPath.NodeState(node, 3, [], []));
        Assert.Equal("current", LearningPath.NodeState(node, 3, ["l2"], []));
    }

    [Fact]
    public void Placement_UsesSortedFirstNodeOrSecondUnitWhenPassed()
    {
        var manifest = JsonNode.Parse("""{"sections":[{"unitIds":["u1","u2"]}],"nodes":[{"nodeId":"c","unitId":"u2","order":7},{"nodeId":"a","unitId":"u1","order":2},{"nodeId":"b","unitId":"u2","order":4}]}""")!.AsObject();
        Assert.Equal(2, LearningPath.PlacementFrontier(manifest, false));
        Assert.Equal(4, LearningPath.PlacementFrontier(manifest, true));
        manifest["sections"]![0]!["unitIds"] = new JsonArray("u1");
        Assert.Equal(2, LearningPath.PlacementFrontier(manifest, true));
        manifest["nodes"] = new JsonArray();
        Assert.Equal(0, LearningPath.PlacementFrontier(manifest, false));
    }
}
