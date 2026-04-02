using System.Diagnostics;

var appDir = AppContext.BaseDirectory;
var appExe = Path.Combine(appDir, "LocalLLMManager.App.exe");

var requiredFiles = new[]
{
    "Microsoft.AI.Foundry.Local.WinML.dll",
    "Microsoft.AI.Foundry.Local.Core.dll",
    "Microsoft.ML.OnnxRuntimeGenAI.dll",
    "onnxruntime-genai.dll"
};

var missing = requiredFiles
    .Where(f => !File.Exists(Path.Combine(appDir, f)))
    .ToList();

if (missing.Count > 0)
{
    Console.WriteLine("=== Local LLM Manager ===");
    Console.WriteLine();
    Console.WriteLine("Required runtime files are missing.");
    Console.WriteLine("Please install the runtime files in this folder:");
    Console.WriteLine($"  {appDir}");
    Console.WriteLine();
    Console.WriteLine("Missing files:");
    foreach (var file in missing)
    {
        Console.WriteLine($"  - {file}");
    }
    Console.WriteLine();
    Console.WriteLine("Setup script:");
    Console.WriteLine("  https://raw.githubusercontent.com/jkudo/local_llm_manager/master/FoundryLocalSample/setup-runtime-files.ps1");
    Console.WriteLine();
    Console.WriteLine("Run these commands in PowerShell:");
    Console.WriteLine("  $url = \"https://raw.githubusercontent.com/jkudo/local_llm_manager/master/FoundryLocalSample/setup-runtime-files.ps1\"");
    Console.WriteLine("  Invoke-WebRequest -Uri $url -OutFile .\\setup-runtime-files.ps1");
    Console.WriteLine("  .\\setup-runtime-files.ps1");
    Console.WriteLine();
    Console.WriteLine("If you installed to a custom folder:");
    Console.WriteLine("  .\\setup-runtime-files.ps1 -InstallDir \"C:\\Path\\To\\Local LLM Manager\"");
    Console.WriteLine();
    Console.WriteLine("Press Enter to exit.");
    Console.ReadLine();
    return;
}

if (!File.Exists(appExe))
{
    Console.WriteLine("Application executable was not found:");
    Console.WriteLine($"  {appExe}");
    Console.WriteLine();
    Console.WriteLine("Press Enter to exit.");
    Console.ReadLine();
    return;
}

var process = Process.Start(new ProcessStartInfo
{
    FileName = appExe,
    WorkingDirectory = appDir,
    UseShellExecute = false
});

if (process is null)
{
    Console.WriteLine("Failed to launch application.");
    Console.WriteLine("Press Enter to exit.");
    Console.ReadLine();
    return;
}

process.WaitForExit();
Environment.ExitCode = process.ExitCode;
