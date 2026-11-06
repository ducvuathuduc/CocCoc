using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class CanonicalWireTests
{
    [Fact]
    public void ParseBody_ReplacesDuplicateKeysRecursivelyAndKeepsFirstInsertionOrder()
    {
        var body = CanonicalWire.ParseBody("""{"z":1,"a":[{"b":2,"b":3}],"z":4}""");
        Assert.Equal("{\"z\":4,\"a\":[{\"b\":3}]}", CanonicalWire.Stringify(body));
        Assert.Equal("{\"a\":[{\"b\":3}],\"z\":4}", CanonicalWire.Json(body));
        Assert.Null(CanonicalWire.ParseBody("null"));
    }
    [Fact]
    public void BodyHash_SortsNestedKeysButPreservesArrayOrderAndUnicode()
    {
        var input = JsonNode.Parse("""{"z":[{"b":"người","a":1},2],"a":null}""");
        const string canonical = """{"a":null,"z":[{"a":1,"b":"người"},2]}""";
        var expected = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
        Assert.Equal(expected, CanonicalWire.BodyHash(input));
        Assert.NotEqual(expected, CanonicalWire.BodyHash(JsonNode.Parse("""{"a":null,"z":[2,{"a":1,"b":"người"}]}""")));
    }

    [Fact]
    public void RowId_IsExactNodePipeSeparatedSha256Prefix()
    {
        const string material = "p_reward_ledger|alice|completion-1|FIRST";
        var expected = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(material)))[..32];
        Assert.Equal(expected, CanonicalWire.RowId("p_reward_ledger", "alice", "completion-1", "FIRST"));
        Assert.NotEqual(expected, CanonicalWire.RowId("p_reward_ledger", "bob", "completion-1", "FIRST"));
    }

    [Theory]
    [InlineData("/", "/")]
    [InlineData("/v1/caf%C3%A9", "/v1/caf%C3%A9")]
    [InlineData("/v1/a!b", "/v1/a%21b")]
    public void Path_UsesStrictRfc3986(string input, string expected) => Assert.Equal(expected, CanonicalWire.Path(input));

    [Theory]
    [InlineData("/v1//x")]
    [InlineData("/v1/%2e%2e")]
    [InlineData("/v1/%2f")]
    [InlineData("/v1/%xy")]
    [InlineData("/v1/%C0%AF")]
    [InlineData("v1/x")]
    public void Path_RejectsAmbiguousOrMalformedPaths(string input) =>
        Assert.Equal("VALIDATION_ERROR", Assert.Throws<ServiceException>(() => CanonicalWire.Path(input)).Code);

    [Fact]
    public void Query_SortsKeysAndDoesNotInterpretPlusAsSpace()
    {
        Assert.Equal("?a=%2B&z=%20", CanonicalWire.Query("z=%20&a=+", new HashSet<string> { "a", "z" }));
        Assert.Equal("", CanonicalWire.Query("", new HashSet<string>()));
    }

    [Theory]
    [InlineData("a=1&a=2")]
    [InlineData("a=1&unknown=2")]
    [InlineData("a=%zz")]
    [InlineData("a=1&")]
    public void Query_RejectsDuplicateUnknownAndMalformedInput(string query) =>
        Assert.Equal("VALIDATION_ERROR", Assert.Throws<ServiceException>(() => CanonicalWire.Query(query, new HashSet<string> { "a" })).Code);
}
