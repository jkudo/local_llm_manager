using Microsoft.AI.Foundry.Local;
using Microsoft.Extensions.Logging;
using OpenAI;
using System.ClientModel;
using System.Net;

Console.WriteLine("=== Local LLM Manager ===");
Console.WriteLine("Powered by Foundry Local SDK");
Console.WriteLine();
Console.WriteLine("API port is used for the local REST API (Chat / Server / WebUI mode).");
Console.Write("API Port (default: 55588): ");
var portInput = Console.ReadLine() ?? "";
var port = string.IsNullOrWhiteSpace(portInput) ? "55588" : portInput;

Console.Write("Allow external connections? (y/N): ");
var allowExternal = (Console.ReadLine() ?? "").Equals("y", StringComparison.OrdinalIgnoreCase);
var bindAddress = allowExternal ? "0.0.0.0" : "127.0.0.1";
var serverUrl = $"http://{bindAddress}:{port}";
var connectUrl = $"http://127.0.0.1:{port}";

var config = new Configuration
{
    AppName = "LocalLLMManager",
    LogLevel = Microsoft.AI.Foundry.Local.LogLevel.Information,
    Web = new Configuration.WebService
    {
        Urls = serverUrl
    }
};

using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Information);
});
var logger = loggerFactory.CreateLogger<Program>();

// Initialize the singleton instance.
await FoundryLocalManager.CreateAsync(config, logger);
var mgr = FoundryLocalManager.Instance;

// Get the model catalog
var catalog = await mgr.GetCatalogAsync();

while (true)
{
// Main menu
Console.WriteLine("\n=== Main Menu ===");
Console.WriteLine("  1. Chat mode");
Console.WriteLine("  2. Server mode");
Console.WriteLine("  3. WebUI mode");
Console.WriteLine("  4. Delete cached models");
Console.WriteLine("  5. End");
Console.WriteLine();
Console.Write("Select (1-5): ");
var menuInput = Console.ReadLine() ?? "";

if (menuInput == "5")
{
    Console.WriteLine("Bye!");
    return;
}

if (menuInput == "2")
{
    // Server mode - select device and model, then start REST server
    Console.WriteLine("\n=== Server Mode: Select Device Type ===");
    Console.WriteLine("  0. Back");
    Console.WriteLine("  1. CPU");
    Console.WriteLine("  2. GPU");
    Console.WriteLine("  3. NPU");
    Console.WriteLine("  4. Cached models");
    Console.WriteLine();
    Console.Write("Select device (0-4): ");
    var srvDeviceInput = Console.ReadLine() ?? "";
    if (!int.TryParse(srvDeviceInput, out int srvDeviceSelection) || srvDeviceSelection < 0 || srvDeviceSelection > 4)
    {
        Console.WriteLine("Invalid selection.");
        continue;
    }
    if (srvDeviceSelection == 0) continue;

    List<Model> srvFilteredModels;

    if (srvDeviceSelection == 4)
    {
        var srvCachedVariants = (await catalog.GetCachedModelsAsync()).ToList();
        if (srvCachedVariants.Count == 0)
        {
            Console.WriteLine("No cached models found.");
            continue;
        }
        var srvModelIds = new HashSet<string>();
        srvFilteredModels = new List<Model>();
        foreach (var cv in srvCachedVariants)
        {
            var m = await catalog.GetModelAsync(cv.Info.Alias ?? cv.Id);
            if (m != null && srvModelIds.Add(m.Id))
                srvFilteredModels.Add(m);
        }
        if (srvFilteredModels.Count == 0)
        {
            Console.WriteLine("No cached models found.");
            continue;
        }
        Console.WriteLine($"\n=== Cached Models ({srvFilteredModels.Count}) ===");
    }
    else
    {
        var srvDeviceType = srvDeviceSelection switch
        {
            1 => DeviceType.CPU,
            2 => DeviceType.GPU,
            3 => DeviceType.NPU,
            _ => DeviceType.CPU
        };
        var srvAllModels = (await catalog.ListModelsAsync()).ToList();
        srvFilteredModels = srvAllModels
            .Where(m => m.Variants.Any(v => v.Info.Runtime?.DeviceType == srvDeviceType))
            .ToList();
        if (srvFilteredModels.Count == 0)
        {
            Console.WriteLine($"No models available for {srvDeviceType}.");
            continue;
        }
        Console.WriteLine($"\n=== Models for {srvDeviceType} ({srvFilteredModels.Count}) ===");
    }

    Console.WriteLine($"  0. Back");
    for (int i = 0; i < srvFilteredModels.Count; i++)
        Console.WriteLine($"  {i + 1}. {srvFilteredModels[i].Id}");
    Console.WriteLine();

    Console.Write($"Select model number (0-{srvFilteredModels.Count}): ");
    var srvInput = Console.ReadLine() ?? "";
    if (!int.TryParse(srvInput, out int srvSelection) || srvSelection < 0 || srvSelection > srvFilteredModels.Count)
    {
        Console.WriteLine("Invalid selection.");
        continue;
    }
    if (srvSelection == 0) continue;

    var srvModel = srvFilteredModels[srvSelection - 1];

    if (srvDeviceSelection != 4)
    {
        var srvDt = srvDeviceSelection switch
        {
            1 => DeviceType.CPU,
            2 => DeviceType.GPU,
            3 => DeviceType.NPU,
            _ => DeviceType.CPU
        };
        var srvVariant = srvModel.Variants.First(v => v.Info.Runtime?.DeviceType == srvDt);
        srvModel.SelectVariant(srvVariant);
    }

    await srvModel.DownloadAsync(progress =>
    {
        Console.Write($"\rDownloading model: {progress:F1}%          ");
        if (progress >= 100f) Console.WriteLine();
    });

    Console.Write("Loading model...");
    var srvLoadingCts = new CancellationTokenSource();
    var srvSw = System.Diagnostics.Stopwatch.StartNew();
    var srvLoadingTask = Task.Run(async () =>
    {
        while (!srvLoadingCts.Token.IsCancellationRequested)
        {
            Console.Write($"\rLoading model... {srvSw.Elapsed.TotalSeconds:F0}s");
            try { await Task.Delay(500, srvLoadingCts.Token); } catch { break; }
        }
    });
    await srvModel.LoadAsync();
    srvSw.Stop();
    srvLoadingCts.Cancel();
    await srvLoadingTask;
    Console.WriteLine($"\rModel loaded in {srvSw.Elapsed.TotalSeconds:F1}s          ");

    await mgr.StartWebServiceAsync();

    Console.WriteLine($"\n=== Server Running ===");
    if (mgr.Urls != null)
    {
        foreach (var u in mgr.Urls)
            Console.WriteLine($"  Listening: {u}/v1");
    }
    else
    {
        Console.WriteLine($"  Endpoint: {connectUrl}/v1");
    }
    Console.WriteLine($"  Model:    {srvModel.Id}");
    if (allowExternal)
    {
        var hostName = System.Net.Dns.GetHostName();
        var addresses = System.Net.Dns.GetHostAddresses(hostName)
            .Where(a => a.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
            .Select(a => a.ToString());
        Console.WriteLine($"  LAN access: {string.Join(", ", addresses.Select(a => $"http://{a}:{port}/v1"))}");
    }
    Console.WriteLine();
    Console.WriteLine("  POST /v1/chat/completions");
    Console.WriteLine("  GET  /v1/models");
    Console.WriteLine();
    Console.WriteLine("Press Enter to stop server...");
    Console.ReadLine();

    await mgr.StopWebServiceAsync();
    await srvModel.UnloadAsync();
    Console.WriteLine("Server stopped.");
    continue;
}

if (menuInput == "3")
{
    // WebUI mode - same as server mode but also serves a web chat UI
    Console.Write("\nWebUI Port (default: 8080): ");
    var webUiPortInput = Console.ReadLine() ?? "";
    var webUiPort = string.IsNullOrWhiteSpace(webUiPortInput) ? 8080 : int.Parse(webUiPortInput);

    Console.WriteLine("\n=== WebUI Mode: Select Device Type ===");
    Console.WriteLine("  0. Back");
    Console.WriteLine("  1. CPU");
    Console.WriteLine("  2. GPU");
    Console.WriteLine("  3. NPU");
    Console.WriteLine("  4. Cached models");
    Console.WriteLine();
    Console.Write("Select device (0-4): ");
    var webDeviceInput = Console.ReadLine() ?? "";
    if (!int.TryParse(webDeviceInput, out int webDeviceSelection) || webDeviceSelection < 0 || webDeviceSelection > 4)
    {
        Console.WriteLine("Invalid selection.");
        continue;
    }
    if (webDeviceSelection == 0) continue;

    List<Model> webFilteredModels;

    if (webDeviceSelection == 4)
    {
        var webCachedVariants = (await catalog.GetCachedModelsAsync()).ToList();
        if (webCachedVariants.Count == 0) { Console.WriteLine("No cached models found."); continue; }
        var webModelIds = new HashSet<string>();
        webFilteredModels = new List<Model>();
        foreach (var cv in webCachedVariants)
        {
            var m = await catalog.GetModelAsync(cv.Info.Alias ?? cv.Id);
            if (m != null && webModelIds.Add(m.Id)) webFilteredModels.Add(m);
        }
        if (webFilteredModels.Count == 0) { Console.WriteLine("No cached models found."); continue; }
        Console.WriteLine($"\n=== Cached Models ({webFilteredModels.Count}) ===");
    }
    else
    {
        var webDeviceType = webDeviceSelection switch { 1 => DeviceType.CPU, 2 => DeviceType.GPU, 3 => DeviceType.NPU, _ => DeviceType.CPU };
        var webAllModels = (await catalog.ListModelsAsync()).ToList();
        webFilteredModels = webAllModels.Where(m => m.Variants.Any(v => v.Info.Runtime?.DeviceType == webDeviceType)).ToList();
        if (webFilteredModels.Count == 0) { Console.WriteLine($"No models available for {webDeviceType}."); continue; }
        Console.WriteLine($"\n=== Models for {webDeviceType} ({webFilteredModels.Count}) ===");
    }

    Console.WriteLine($"  0. Back");
    for (int i = 0; i < webFilteredModels.Count; i++)
        Console.WriteLine($"  {i + 1}. {webFilteredModels[i].Id}");
    Console.WriteLine();

    Console.Write($"Select model number (0-{webFilteredModels.Count}): ");
    var webInput = Console.ReadLine() ?? "";
    if (!int.TryParse(webInput, out int webSelection) || webSelection < 0 || webSelection > webFilteredModels.Count)
    { Console.WriteLine("Invalid selection."); continue; }
    if (webSelection == 0) continue;

    var webModel = webFilteredModels[webSelection - 1];
    if (webDeviceSelection != 4)
    {
        var webDt = webDeviceSelection switch { 1 => DeviceType.CPU, 2 => DeviceType.GPU, 3 => DeviceType.NPU, _ => DeviceType.CPU };
        var webVariant = webModel.Variants.First(v => v.Info.Runtime?.DeviceType == webDt);
        webModel.SelectVariant(webVariant);
    }

    await webModel.DownloadAsync(progress =>
    {
        Console.Write($"\rDownloading model: {progress:F1}%          ");
        if (progress >= 100f) Console.WriteLine();
    });

    Console.Write("Loading model...");
    var webLoadingCts = new CancellationTokenSource();
    var webSw = System.Diagnostics.Stopwatch.StartNew();
    var webLoadingTask = Task.Run(async () =>
    {
        while (!webLoadingCts.Token.IsCancellationRequested)
        {
            Console.Write($"\rLoading model... {webSw.Elapsed.TotalSeconds:F0}s");
            try { await Task.Delay(500, webLoadingCts.Token); } catch { break; }
        }
    });
    await webModel.LoadAsync();
    webSw.Stop();
    webLoadingCts.Cancel();
    await webLoadingTask;
    Console.WriteLine($"\rModel loaded in {webSw.Elapsed.TotalSeconds:F1}s          ");

    await mgr.StartWebServiceAsync();

    // Start a simple HTTP server for the WebUI
    var htmlPath = Path.Combine(AppContext.BaseDirectory, "wwwroot", "index.html");
    if (!File.Exists(htmlPath))
        htmlPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "index.html");
    if (!File.Exists(htmlPath))
        htmlPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "wwwroot", "index.html");

    var htmlContent = File.ReadAllText(htmlPath);
    var listener = new HttpListener();
    listener.Prefixes.Add($"http://localhost:{webUiPort}/");
    listener.Start();

    var webUiCts = new CancellationTokenSource();
    var listenerTask = Task.Run(async () =>
    {
        while (!webUiCts.Token.IsCancellationRequested)
        {
            try
            {
                var ctx = await listener.GetContextAsync();
                ctx.Response.ContentType = "text/html; charset=utf-8";
                ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*");
                var buffer = System.Text.Encoding.UTF8.GetBytes(htmlContent);
                ctx.Response.ContentLength64 = buffer.Length;
                await ctx.Response.OutputStream.WriteAsync(buffer);
                ctx.Response.Close();
            }
            catch { break; }
        }
    });

    Console.WriteLine($"\n=== WebUI Running ===");
    Console.WriteLine($"  WebUI:    http://localhost:{webUiPort}?apiPort={port}");
    Console.WriteLine($"  API:      {connectUrl}/v1");
    Console.WriteLine($"  Model:    {webModel.Id}");
    Console.WriteLine();

    // Open browser
    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
    {
        FileName = $"http://localhost:{webUiPort}?apiPort={port}",
        UseShellExecute = true
    });

    Console.WriteLine("Press Enter to stop...");
    Console.ReadLine();

    webUiCts.Cancel();
    listener.Stop();
    listener.Close();
    await mgr.StopWebServiceAsync();
    await webModel.UnloadAsync();
    Console.WriteLine("WebUI stopped.");
    continue;
}

if (menuInput == "4")
{
    // Delete cached models
    var cachedModels = (await catalog.GetCachedModelsAsync()).ToList();
    if (cachedModels.Count == 0)
    {
        Console.WriteLine("No cached models found.");
        continue;
    }

    Console.WriteLine($"\n=== Cached Models ({cachedModels.Count}) ===");
    Console.WriteLine($"  0. Back");
    for (int i = 0; i < cachedModels.Count; i++)
    {
        Console.WriteLine($"  {i + 1}. {cachedModels[i].Id}");
    }
    Console.WriteLine($"  {cachedModels.Count + 1}. [All Delete]");
    Console.WriteLine();
    Console.Write($"Select model to delete (0-{cachedModels.Count + 1}): ");
    var delInput = Console.ReadLine() ?? "";

    if (!int.TryParse(delInput, out int delSelection) || delSelection < 0 || delSelection > cachedModels.Count + 1)
    {
        Console.WriteLine("Invalid selection.");
    }
    else if (delSelection == 0)
    {
        // Back to main menu
    }
    else if (delSelection == cachedModels.Count + 1)
    {
        Console.Write("Delete ALL cached models? (y/N): ");
        if ((Console.ReadLine() ?? "").Equals("y", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var m in cachedModels)
            {
                await m.RemoveFromCacheAsync();
                Console.WriteLine($"  Deleted: {m.Id}");
            }
        }
    }
    else if (delSelection >= 1 && delSelection <= cachedModels.Count)
    {
        var target = cachedModels[delSelection - 1];
        Console.Write($"Delete '{target.Id}'? (y/N): ");
        if ((Console.ReadLine() ?? "").Equals("y", StringComparison.OrdinalIgnoreCase))
        {
            await target.RemoveFromCacheAsync();
            Console.WriteLine($"Deleted: {target.Id}");
        }
    }
    continue;
}

if (menuInput != "1")
{
    Console.WriteLine("Invalid selection.");
    continue;
}

// Select device type
Console.WriteLine("\n=== Select Device Type ===");
Console.WriteLine("  0. Back");
Console.WriteLine("  1. CPU");
Console.WriteLine("  2. GPU");
Console.WriteLine("  3. NPU");
Console.WriteLine("  4. Cached models");
Console.WriteLine();
Console.Write("Select device (0-4): ");
var deviceInput = Console.ReadLine() ?? "";
if (!int.TryParse(deviceInput, out int deviceSelection) || deviceSelection < 0 || deviceSelection > 4)
{
    Console.WriteLine("Invalid selection.");
    continue;
}
if (deviceSelection == 0) continue;

List<Model> filteredModels;

if (deviceSelection == 4)
{
    // Show cached models - get variants and resolve to models
    var cachedVariants = (await catalog.GetCachedModelsAsync()).ToList();
    if (cachedVariants.Count == 0)
    {
        Console.WriteLine("No cached models found.");
        continue;
    }
    // Get unique models from cached variants
    var modelIds = new HashSet<string>();
    filteredModels = new List<Model>();
    foreach (var cv in cachedVariants)
    {
        var m = await catalog.GetModelAsync(cv.Info.Alias ?? cv.Id);
        if (m != null && modelIds.Add(m.Id))
        {
            filteredModels.Add(m);
        }
    }
    if (filteredModels.Count == 0)
    {
        Console.WriteLine("No cached models found.");
        continue;
    }
    Console.WriteLine($"\n=== Cached Models ({filteredModels.Count}) ===");
}
else
{
    var selectedDeviceType = deviceSelection switch
    {
        1 => DeviceType.CPU,
        2 => DeviceType.GPU,
        3 => DeviceType.NPU,
        _ => DeviceType.CPU
    };
    Console.WriteLine($"Selected device: {selectedDeviceType}");

    // List models that have a variant for the selected device type
    var allModels = (await catalog.ListModelsAsync()).ToList();
    filteredModels = allModels
        .Where(m => m.Variants.Any(v => v.Info.Runtime?.DeviceType == selectedDeviceType))
        .ToList();

    if (filteredModels.Count == 0)
    {
        Console.WriteLine($"No models available for {selectedDeviceType}.");
        continue;
    }
    Console.WriteLine($"\n=== Models for {selectedDeviceType} ({filteredModels.Count}) ===");
}

Console.WriteLine($"  0. Back");
for (int i = 0; i < filteredModels.Count; i++)
{
    Console.WriteLine($"  {i + 1}. {filteredModels[i].Id}");
}
Console.WriteLine();

// Select model interactively
Console.Write($"Select model number (0-{filteredModels.Count}): ");
var input = Console.ReadLine() ?? "";
if (!int.TryParse(input, out int selection) || selection < 0 || selection > filteredModels.Count)
{
    Console.WriteLine("Invalid selection.");
    continue;
}
if (selection == 0) continue;

var model = filteredModels[selection - 1];

// Select the variant for the chosen device type (skip for cached models)
if (deviceSelection != 4)
{
    var selectedDeviceType2 = deviceSelection switch
    {
        1 => DeviceType.CPU,
        2 => DeviceType.GPU,
        3 => DeviceType.NPU,
        _ => DeviceType.CPU
    };
    var variant = model.Variants.First(v => v.Info.Runtime?.DeviceType == selectedDeviceType2);
    model.SelectVariant(variant);
    Console.WriteLine($"Selected: {model.Id} ({selectedDeviceType2})");
}
else
{
    Console.WriteLine($"Selected: {model.Id} (cached)");
}

// Download the model (the method skips download if already cached)
await model.DownloadAsync(progress =>
{
    Console.Write($"\rDownloading model: {progress:F1}%          ");
    if (progress >= 100f)
    {
        Console.WriteLine();
    }
});

// Load the model with elapsed time indicator
Console.Write("Loading model...");
var loadingCts = new CancellationTokenSource();
var sw = System.Diagnostics.Stopwatch.StartNew();
var loadingTask = Task.Run(async () =>
{
    while (!loadingCts.Token.IsCancellationRequested)
    {
        Console.Write($"\rLoading model... {sw.Elapsed.TotalSeconds:F0}s");
        try { await Task.Delay(500, loadingCts.Token); } catch { break; }
    }
});
await model.LoadAsync();
sw.Stop();
loadingCts.Cancel();
await loadingTask;
Console.WriteLine($"\rModel loaded in {sw.Elapsed.TotalSeconds:F1}s          ");

// Start the web service
await mgr.StartWebServiceAsync();

// Use the OpenAI SDK to call the local Foundry web service
ApiKeyCredential key = new ApiKeyCredential("notneeded");
OpenAIClient client = new OpenAIClient(key, new OpenAIClientOptions
{
    Endpoint = new Uri(connectUrl + "/v1"),
});

var chatClient = client.GetChatClient(model.Id);

Console.WriteLine("\nChat started. Enter empty line to quit.\n");

while (true)
{
    Console.Write("🧑: ");
    var userInput = Console.ReadLine();
    if (string.IsNullOrEmpty(userInput)) break;

    var completionUpdates = chatClient.CompleteChatStreaming(
        [
            new OpenAI.Chat.SystemChatMessage("Reply in the same language as the user's input."),
            new OpenAI.Chat.UserChatMessage(userInput)
        ]);

    Console.Write("🤖: ");
    foreach (var completionUpdate in completionUpdates)
    {
        if (completionUpdate.ContentUpdate.Count > 0)
        {
            Console.Write(completionUpdate.ContentUpdate[0].Text);
        }
    }
    Console.WriteLine();
    Console.WriteLine();
}

// Tidy up
await mgr.StopWebServiceAsync();
await model.UnloadAsync();
} // end main menu loop
