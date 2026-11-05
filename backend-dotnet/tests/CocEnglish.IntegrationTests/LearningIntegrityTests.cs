using CocEnglish.Learning;
using CocEnglish.Shared.Security;
using System.Text.Json.Nodes;
using Xunit;
using System.Text;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Crypto.Signers;
using CocEnglish.Shared.Errors;

namespace CocEnglish.IntegrationTests;

public sealed class LearningIntegrityTests
{
    [Fact]
    public void Manifest_VerifiesStructureAndSignatureAndRejectsTampering()
    {
        var secret = new Ed25519PrivateKeyParameters(new byte[32], 0);
        var hex = Convert.ToHexString(secret.GeneratePublicKey().GetEncoded());
        var keys = LearningIntegrity.ParseKeyring($"[{{\"keyId\":\"key\",\"publicKeyHex\":\"{hex}\"}}]");
        var manifest = JsonNode.Parse("""{"courseId":"vi_en","title":"Tiếng Việt","bundles":[{"sha256":"abc"}]}""")!.AsObject();
        manifest["manifestHash"] = LearningIntegrity.StructureHash(manifest);
        var signer = new Ed25519Signer(); signer.Init(true, secret);
        var message = Encoding.UTF8.GetBytes(LearningIntegrity.SigningInput(manifest)); signer.BlockUpdate(message, 0, message.Length);
        manifest["signature"] = Convert.ToBase64String(signer.GenerateSignature()).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        manifest["signatureKeyId"] = "key";
        Assert.True(LearningIntegrity.VerifyManifest(keys, manifest));
        var text = CanonicalWire.Json(manifest);
        Assert.Equal("vi_en", LearningContentRepository.ParseManifest(text, CanonicalWire.Sha256(text), keys)["courseId"]!.GetValue<string>());
        var wrongHash = Assert.Throws<ServiceException>(() => LearningContentRepository.ParseManifest(text, "wrong", keys));
        Assert.Equal("MANIFEST_HASH_MISMATCH", wrongHash.Details["reason"]!.GetValue<string>());
        manifest["bundles"]![0]!["sha256"] = "tampered";
        Assert.False(LearningIntegrity.VerifyManifest(keys, manifest));
        var altered = CanonicalWire.Json(manifest);
        var invalid = Assert.Throws<ServiceException>(() => LearningContentRepository.ParseManifest(altered, CanonicalWire.Sha256(altered), keys));
        Assert.Equal("MANIFEST_SIGNATURE_INVALID", invalid.Details["reason"]!.GetValue<string>());
        Assert.Empty(LearningIntegrity.ParseKeyring(null));
        Assert.Throws<FormatException>(() => LearningIntegrity.ParseKeyring("[{\"keyId\":\"key\",\"publicKeyHex\":\"bad\"}]"));
    }

    [Fact]
    public void Ed25519_VerifiesKnownVectorAndRejectsTamperingAndUnknownKeys()
    {
        var keys = new Dictionary<string, byte[]> { ["key"] = Convert.FromHexString("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a") };
        var signature = Convert.ToBase64String(Convert.FromHexString("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" + "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        Assert.True(LearningIntegrity.VerifyText(keys, "key", "", signature));
        Assert.False(LearningIntegrity.VerifyText(keys, "key", "changed", signature));
        Assert.False(LearningIntegrity.VerifyText(keys, "other", "", signature));
        Assert.False(LearningIntegrity.VerifyText(keys, "key", "", signature + "="));
    }

    [Fact]
    public void ManifestInputs_ExcludeOnlyTheSpecifiedFieldsAndKeepNestedValues()
    {
        var manifest = JsonNode.Parse("""{"z":"Việt 😀","bundles":[{"signature":"inner"}],"placementBundle":{"id":"p"},"manifestHash":"old","signature":"sig","signatureKeyId":"key","a":{"z":1,"a":2}}""")!.AsObject();
        Assert.Equal("{\"a\":{\"a\":2,\"z\":1},\"z\":\"Việt 😀\"}", LearningIntegrity.StructureInput(manifest));
        Assert.Equal(CanonicalWire.Sha256(LearningIntegrity.StructureInput(manifest)), LearningIntegrity.StructureHash(manifest));
        var signing = LearningIntegrity.SigningInput(manifest);
        Assert.Contains("\"signature\":\"inner\"", signing);
        Assert.DoesNotContain("\"signatureKeyId\"", signing);
        Assert.Contains("\"manifestHash\":\"old\"", signing);
        Assert.True(manifest.ContainsKey("signature"));
    }
}
