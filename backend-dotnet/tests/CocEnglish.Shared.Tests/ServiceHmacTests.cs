using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Shared.Tests;

public sealed class ServiceHmacTests
{
    private static readonly ServiceKey Key = new("learning-1", "learning", Enumerable.Range(0, 32).Select(i => (byte)i).ToArray());
    private static readonly IReadOnlySet<string> Empty = new HashSet<string>();
    private static readonly IReadOnlySet<string> Senders = new HashSet<string> { "learning" };
    private static readonly IReadOnlyDictionary<string, ServiceKey> Ring = new Dictionary<string, ServiceKey> { [Key.KeyId] = Key };

    [Fact]
    public void Sign_IsByteCompatibleWithNodeGolden()
    {
        var signature = ServiceHmac.Sign(Key, "post", "/internal/events", "", Empty, "{\"text\":\"người\"}", 1700000000);
        Assert.Equal("learning-1", signature.KeyId);
        Assert.Equal("1700000000", signature.Timestamp);
        Assert.Equal("86b4ee464df4f7857c552ac0b9f324c2251883bf2fa27c8ef30a8646d7d81de2", signature.Signature);
        Assert.Equal("learning", ServiceHmac.Verify(Ring, signature, "POST", "/internal/events", "", Empty, "{\"text\":\"người\"}", 1700000000, Senders));
    }

    [Theory]
    [InlineData(-300)]
    [InlineData(300)]
    public void Verify_AcceptsExactClockBoundary(int skew)
    {
        var signature = ServiceHmac.Sign(Key, "POST", "/internal/events", "", Empty, "{}", 1700000000);
        Assert.Equal("learning", ServiceHmac.Verify(Ring, signature, "POST", "/internal/events", "", Empty, "{}", 1700000000 + skew, Senders));
    }

    [Theory]
    [InlineData(-301)]
    [InlineData(301)]
    public void Verify_RejectsExpiredOrFutureRequest(int skew)
    {
        var signature = ServiceHmac.Sign(Key, "POST", "/internal/events", "", Empty, "{}", 1700000000);
        Assert.Equal("AUTH_EXPIRED", Assert.Throws<ServiceException>(() => ServiceHmac.Verify(Ring, signature, "POST", "/internal/events", "", Empty, "{}", 1700000000 + skew, Senders)).Code);
    }

    [Theory]
    [InlineData("DELETE", "/internal/events", "{}")]
    [InlineData("POST", "/internal/jobs/x", "{}")]
    [InlineData("POST", "/internal/events", "{\"tampered\":true}")]
    public void Verify_RejectsChangedMethodPathOrBody(string method, string path, string body)
    {
        var signature = ServiceHmac.Sign(Key, "POST", "/internal/events", "", Empty, "{}", 1700000000);
        Assert.Equal("AUTH_REQUIRED", Assert.Throws<ServiceException>(() => ServiceHmac.Verify(Ring, signature, method, path, "", Empty, body, 1700000000, Senders)).Code);
    }

    [Fact]
    public void Verify_DistinguishesUnknownKeyFromDisallowedSender()
    {
        var signature = ServiceHmac.Sign(Key, "POST", "/internal/events", "", Empty, "{}", 1700000000);
        Assert.Equal("AUTH_REQUIRED", Assert.Throws<ServiceException>(() => ServiceHmac.Verify(Ring, signature with { KeyId = "missing" }, "POST", "/internal/events", "", Empty, "{}", 1700000000, Senders)).Code);
        Assert.Equal("FORBIDDEN", Assert.Throws<ServiceException>(() => ServiceHmac.Verify(Ring, signature, "POST", "/internal/events", "", Empty, "{}", 1700000000, new HashSet<string> { "scheduler" })).Code);
    }

    [Theory]
    [InlineData("bad", "00")]
    [InlineData("1700000000", "ABC")]
    [InlineData("01700000000", "0000000000000000000000000000000000000000000000000000000000000000")]
    public void Verify_RejectsMalformedHeaders(string timestamp, string signature)
    {
        Assert.Equal("AUTH_REQUIRED", Assert.Throws<ServiceException>(() => ServiceHmac.Verify(Ring, new(Key.KeyId, timestamp, signature), "POST", "/internal/events", "", Empty, "{}", 1700000000, Senders)).Code);
    }

    [Fact]
    public void ParseKeyring_RequiresUniqueKeysKnownSendersAnd32ByteSecrets()
    {
        var hex = Convert.ToHexStringLower(Key.Secret);
        var entry = $$"""{"keyId":"learning-1","sender":"learning","secretHex":"{{hex}}"}""";
        Assert.Equal(Key.Secret, ServiceHmac.ParseKeyring("[" + entry + "]")[Key.KeyId].Secret);
        Assert.Empty(ServiceHmac.ParseKeyring(null));
        Assert.Throws<FormatException>(() => ServiceHmac.ParseKeyring("[" + entry + "," + entry + "]"));
        Assert.Throws<FormatException>(() => ServiceHmac.ParseKeyring("[" + entry.Replace("learning\"", "foreign\"") + "]"));
        Assert.Throws<FormatException>(() => ServiceHmac.ParseKeyring("[" + entry.Replace(hex, "00") + "]"));
    }
}
