using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace CocEnglish.Learning;

public static class LearningCursor
{
    public static string Encode(int offset) => Convert.ToBase64String(Encoding.UTF8.GetBytes("o:" + offset.ToString(CultureInfo.InvariantCulture))).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    public static int Decode(string? cursor)
    {
        if (string.IsNullOrEmpty(cursor)) return 0;
        try
        {
            var input = new string(cursor.TakeWhile(c => c != '=').Where(c => char.IsAsciiLetterOrDigit(c) || c is '+' or '/' or '-' or '_').ToArray()).Replace('-', '+').Replace('_', '/');
            if (input.Length % 4 == 1) input = input[..^1];
            input = input.PadRight((input.Length + 3) / 4 * 4, '=');
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(input));
            return Regex.IsMatch(decoded, "^o:[0-9]{1,6}$", RegexOptions.CultureInvariant) ? int.Parse(decoded[2..], CultureInfo.InvariantCulture) : -1;
        }
        catch (FormatException) { return -1; }
    }
}
