using CocEnglish.Shared.Hosting;

namespace CocEnglish.AI;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("ai", args, typeof(Program).Assembly);
}
