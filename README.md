# Local LLM Manager

A Windows console application for easily managing and running local LLMs.  
Powered by [Foundry Local SDK](https://learn.microsoft.com/windows/ai/foundry/get-started/foundry-local-sdk-quickstart)

## Features

| Mode | Description |
|------|-------------|
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

## Installation

### Installer (Recommended)

Download `LocalLLMManager_Setup_x.x.x.exe` from [Releases](https://github.com/jkudo/local_llm_manager/releases) and run it.  
If .NET Runtime is not installed, the installer will automatically prompt you to download and install it.

### Build from Source

```bash
git clone https://github.com/jkudo/local_llm_manager.git
cd local_llm_manager
dotnet run -r win-x64
```

## Usage

```
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

```bash
dotnet publish -r win-x64 -c Release
build-installer.bat
```

Requires [Inno Setup 6](https://jrsoftware.org/isdl.php).

## Tech Stack

- [Foundry Local SDK](https://www.nuget.org/packages/Microsoft.AI.Foundry.Local.WinML) (WinML)
- [OpenAI .NET SDK](https://www.nuget.org/packages/OpenAI)
- ONNX Runtime / DirectML
- .NET 10

## License

MIT
