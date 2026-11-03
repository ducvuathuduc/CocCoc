using CocEnglish.Shared.Hosting;
using CocEnglish.Progress.Application;

namespace CocEnglish.Progress;

public partial class Program
{
    public static Task<int> Main(string[] args) => ServiceHost.RunAsync("progress", args, typeof(Program).Assembly,
        services => { services.AddScoped<IProgressReads, ProgressReads>(); services.AddScoped<ProgressWrites>(); });
}
