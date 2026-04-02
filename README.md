# Local LLM Manager

A Windows console application for easily managing and running local LLMs.  
Powered by [Foundry Local SDK](https://learn.microsoft.com/windows/ai/foundry/get-started/foundry-local-sdk-quickstart)

## Features

| Mode | Description |
| ------ | ------------- |
| **Chat** | Streaming chat with AI in the terminal |
| **Server** | Launch an OpenAI-compatible REST API server |
| **WebUI** | Launch a browser-based chat UI |
| **Delete** | Delete downloaded/cached models |

## Highlights

- CPU / GPU / NPU device selection
- Automatic model download with progress display
- Cached model management
- OpenAI SDK-compatible API endpoint
- External connection support (LAN access for Server mode)
- Dark-themed WebUI with streaming support
- Automatically replies in the user's language

## Requirements

- Windows 10/11 (Build 26100 or later)
- .NET 10 Runtime
- Foundry Local / ONNX runtime files (manual install)

## Installation

### Installer (Recommended)

Download `LocalLLMManager_Setup_x.x.x.exe` from [Releases](https://github.com/jkudo/local_llm_manager/releases) and run it.  

If .NET 10 Runtime is missing, setup asks whether to install it.
If you choose No, setup exits without installing Local LLM Manager.

This installer does not bundle Foundry Local / ONNX runtime files.
On first launch, if runtime files are missing, the app shows a setup guide and exits.

Install guide:

- [Foundry Local SDK Quickstart](https://learn.microsoft.com/windows/ai/foundry/get-started/foundry-local-sdk-quickstart)
- Place required runtime files in the app install folder (same folder as `LocalLLMManager.exe`).

For end users (no npm/NuGet required):

1. Run `LocalLLMManager_Setup_x.x.x.exe`.
2. If prompted, choose Yes to install .NET 10 Runtime and continue setup.
3. Install Local LLM Manager.
4. Launch the app once and read the "missing files" message.
5. Install the required runtime files via NuGet (recommended) or copy them manually into the install folder (same folder as `LocalLLMManager.exe`).
6. Launch the app again.

Note: npm/NuGet-based steps in official docs are mainly for developer workflows. For this app's end-user setup, npm and NuGet are not required.

Runtime setup (required for all users):

Because the installer does not bundle Foundry Local / ONNX runtime files, this setup is required for both installer users and source users.

### Option A: Run the setup script (recommended)

If .NET 10 SDK is not installed, install it first.

The commands below assume the default install folder: `C:\Program Files\Local LLM Manager`.
If you installed the app in a custom folder, replace the install path accordingly.

1. Download `setup-runtime-files.ps1` from GitHub and place it in any local folder.
  - Repository file: https://github.com/jkudo/local_llm_manager/blob/master/FoundryLocalSample/setup-runtime-files.ps1
  - Direct download: https://raw.githubusercontent.com/jkudo/local_llm_manager/master/FoundryLocalSample/setup-runtime-files.ps1

2. Open PowerShell in that folder and run:

```powershell
./setup-runtime-files.ps1
```

3. If your app is installed in a custom folder, pass it explicitly:

```powershell
# Replace the path below with your actual install folder
./setup-runtime-files.ps1 -InstallDir "C:\Path\To\Local LLM Manager"
```

### Option B: Manual setup

1. If .NET 10 SDK is not installed, install it first.

2. Create a temporary working folder and restore the required package into the global NuGet cache:

```bash
dotnet new console -o foundry-runtime-setup
cd foundry-runtime-setup
dotnet add package Microsoft.AI.Foundry.Local.WinML --version 0.9.0
dotnet restore
```

3. Copy required runtime files from the global NuGet cache into the app install folder (same folder as `LocalLLMManager.exe`):

```powershell
$NuGetRoot = Join-Path $env:USERPROFILE ".nuget\packages"
# Default install folder. If you installed elsewhere, replace this path.
$InstallDir = Join-Path $env:ProgramFiles "Local LLM Manager"
$Rid = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "win-arm64" } else { "win-x64" }

function Get-LatestPackageDir([string]$PackageId) {
  $Root = Join-Path $NuGetRoot $PackageId
  Get-ChildItem $Root -Directory | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}

$WinMLDir = Get-LatestPackageDir "microsoft.ai.foundry.local.winml"
$CoreDir = Get-LatestPackageDir "microsoft.ai.foundry.local.core.winml"
$ManagedDir = Get-LatestPackageDir "microsoft.ml.onnxruntimegenai.managed"
$FoundryDir = Get-LatestPackageDir "microsoft.ml.onnxruntimegenai.foundry"

$WinMLSrc = Get-ChildItem (Join-Path $WinMLDir "lib") -Recurse -File -Filter "Microsoft.AI.Foundry.Local.WinML.dll" |
  Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
$ManagedSrc = Get-ChildItem (Join-Path $ManagedDir "lib") -Recurse -File -Filter "Microsoft.ML.OnnxRuntimeGenAI.dll" |
  Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
$CoreSrc = Join-Path $CoreDir "runtimes\$Rid\native\Microsoft.AI.Foundry.Local.Core.dll"
$GenAISrc = Join-Path $FoundryDir "runtimes\$Rid\native\onnxruntime-genai.dll"

$CopyMap = @(
  @{ Src = $WinMLSrc; Dst = Join-Path $InstallDir "Microsoft.AI.Foundry.Local.WinML.dll" },
  @{ Src = $CoreSrc; Dst = Join-Path $InstallDir "Microsoft.AI.Foundry.Local.Core.dll" },
  @{ Src = $ManagedSrc; Dst = Join-Path $InstallDir "Microsoft.ML.OnnxRuntimeGenAI.dll" },
  @{ Src = $GenAISrc; Dst = Join-Path $InstallDir "onnxruntime-genai.dll" }
)

foreach ($Item in $CopyMap) {
  if (-not (Test-Path $Item.Src)) { throw "Missing file: $($Item.Src)" }
  Copy-Item $Item.Src $Item.Dst -Force
}
```

4. Launch Local LLM Manager.

When running from source, the app searches the global NuGet cache (`%USERPROFILE%\.nuget\packages`) on startup if runtime files are not next to the executable.

You can delete the temporary folder after copying:

```powershell
Set-Location ..
Remove-Item foundry-runtime-setup -Recurse -Force
```

### Build from Source

```bash
git clone https://github.com/jkudo/local_llm_manager.git
cd local_llm_manager
dotnet run --project .\\FoundryLocalSample\\LocalLLMManager.csproj -r win-x64
```

## Usage

```text
=== Local LLM Manager ===
Powered by Foundry Local SDK

API Port (default: 55588): [Enter]
Allow external connections? (y/N): [Enter]

=== Main Menu ===
  1. Chat mode
  2. Server mode
  3. WebUI mode
  4. Delete cached models
  5. End
```

1. Specify the API port (default: 55588)
2. Choose whether to allow external connections (for LAN access in Server mode)
3. Select a mode from the menu
4. Choose a device type (CPU / GPU / NPU / Cached)
5. Select a model → automatic download & load

### Server Mode

Use as a REST API from other applications:

```bash
curl http://127.0.0.1:55588/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"phi-4-mini","messages":[{"role":"user","content":"Hello"}]}'
```

### WebUI Mode

A browser window opens automatically with the chat UI.

## Building the Installer

```powershell
dotnet publish .\LocalLLMManager.csproj -r win-x64 -c Release
.\build-installer-inno.ps1 -Version 1.0.0
```

Prerequisites:

- .NET 10 SDK
- Inno Setup 6 (ISCC.exe)

Note:

- If .NET 10 Runtime is missing and you choose not to install it, setup exits.
- Foundry Local / ONNX runtime files are excluded by design and must be installed manually.

## Tech Stack

- [Foundry Local SDK](https://www.nuget.org/packages/Microsoft.AI.Foundry.Local.WinML) (WinML)
- [OpenAI .NET SDK](https://www.nuget.org/packages/OpenAI)
- ONNX Runtime / DirectML
- .NET 10

## License

MIT
