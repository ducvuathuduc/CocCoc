using CocEnglish.Shared.Hosting;

namespace CocEnglish.Learning;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("learning", args, typeof(Program).Assembly);
}
