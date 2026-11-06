using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using CocEnglish.Shared.Security;
using CocEnglish.Shared.Errors;

namespace CocEnglish.Progress.Application;

public sealed class ProgressCodes(string? secret)
{
    public string Derive(string kind, string id)
    {
        if (secret is null || Regex.Replace(secret, @"^[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+|[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+$", "").Length < 16) throw new ServiceException("SERVICE_NOT_CONFIGURED");
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var digest = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(kind + "|" + id));
        return new string(digest.Take(8).Select(b => alphabet[b % alphabet.Length]).ToArray());
    }
    public static string Hash(string code) => CanonicalWire.Sha256(Regex.Replace(code.Normalize(NormalizationForm.FormKC).ToUpperInvariant(), @"[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF-]+", ""));
}
