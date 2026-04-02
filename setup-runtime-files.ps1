param(
    [string]$InstallDir = "$env:ProgramFiles\Local LLM Manager",
    [string]$WorkingRoot = "$env:TEMP\foundry-runtime-setup",
    [switch]$KeepWorkingDir
)

$ErrorActionPreference = "Stop"

# If installing to Program Files, require administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$targetDir = if ($PSBoundParameters.ContainsKey('InstallDir')) { $InstallDir } else { "$env:ProgramFiles\Local LLM Manager" }
if ($targetDir -like "$env:ProgramFiles*" -and -not $isAdmin) {
    Write-Error "Administrator privileges are required to write to '$targetDir'.`nPlease run this script from an elevated PowerShell (Run as Administrator)."
    exit 1
}

function Assert-CommandExists {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $CommandName"
    }
}

function Get-LatestPackageDir {
    param(
        [string]$NuGetRoot,
        [string]$PackageId
    )

    $packageRoot = Join-Path $NuGetRoot $PackageId
    if (-not (Test-Path $packageRoot)) {
        throw "Package folder not found: $packageRoot"
    }

    $latest = Get-ChildItem $packageRoot -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $latest) {
        throw "No package versions found under: $packageRoot"
    }

    return $latest
}

function Get-LatestFileFromLib {
    param(
        [string]$PackageDir,
        [string]$FileName
    )

    $libRoot = Join-Path $PackageDir "lib"
    if (-not (Test-Path $libRoot)) {
        throw "lib folder not found: $libRoot"
    }

    $file = Get-ChildItem $libRoot -Recurse -File -Filter $FileName |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $file) {
        throw "File not found in package lib folder: $FileName"
    }

    return $file
}

Assert-CommandExists -CommandName "dotnet"

$sdkList = & dotnet --list-sdks 2>$null
if ([string]::IsNullOrWhiteSpace(($sdkList | Out-String))) {
    throw ".NET SDK is required for this script. Install .NET 10 SDK and try again."
}

$startLocation = Get-Location
if ([System.IO.Path]::IsPathRooted($InstallDir)) {
    $resolvedInstallDir = $InstallDir
}
else {
    $resolvedInstallDir = Join-Path $startLocation.Path $InstallDir
}

$rid = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "win-arm64" } else { "win-x64" }

$nuGetRoot = $env:NUGET_PACKAGES
if ([string]::IsNullOrWhiteSpace($nuGetRoot)) {
    $nuGetRoot = Join-Path $env:USERPROFILE ".nuget\packages"
}

$runDir = Join-Path $WorkingRoot ("run-" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

try {
    Push-Location $runDir

    & dotnet new console --force | Out-Null
    & dotnet add package Microsoft.AI.Foundry.Local.WinML --version 0.9.0 | Out-Null
    & dotnet restore | Out-Null

    $winMLDir = Get-LatestPackageDir -NuGetRoot $nuGetRoot -PackageId "microsoft.ai.foundry.local.winml"
    $coreDir = Get-LatestPackageDir -NuGetRoot $nuGetRoot -PackageId "microsoft.ai.foundry.local.core.winml"
    $managedDir = Get-LatestPackageDir -NuGetRoot $nuGetRoot -PackageId "microsoft.ml.onnxruntimegenai.managed"
    $foundryDir = Get-LatestPackageDir -NuGetRoot $nuGetRoot -PackageId "microsoft.ml.onnxruntimegenai.foundry"

    $copyMap = @(
        @{
            Src = Get-LatestFileFromLib -PackageDir $winMLDir -FileName "Microsoft.AI.Foundry.Local.WinML.dll"
            Dst = Join-Path $resolvedInstallDir "Microsoft.AI.Foundry.Local.WinML.dll"
        },
        @{
            Src = Join-Path $coreDir "runtimes\$rid\native\Microsoft.AI.Foundry.Local.Core.dll"
            Dst = Join-Path $resolvedInstallDir "Microsoft.AI.Foundry.Local.Core.dll"
        },
        @{
            Src = Get-LatestFileFromLib -PackageDir $managedDir -FileName "Microsoft.ML.OnnxRuntimeGenAI.dll"
            Dst = Join-Path $resolvedInstallDir "Microsoft.ML.OnnxRuntimeGenAI.dll"
        },
        @{
            Src = Join-Path $foundryDir "runtimes\$rid\native\onnxruntime-genai.dll"
            Dst = Join-Path $resolvedInstallDir "onnxruntime-genai.dll"
        }
    )

    New-Item -Path $resolvedInstallDir -ItemType Directory -Force | Out-Null

    foreach ($item in $copyMap) {
        if (-not (Test-Path $item.Src)) {
            throw "Missing file: $($item.Src)"
        }
        Copy-Item $item.Src $item.Dst -Force
    }

    Write-Host "Runtime files copied to: $resolvedInstallDir"
}
finally {
    Pop-Location

    if (-not $KeepWorkingDir -and (Test-Path $runDir)) {
        Remove-Item $runDir -Recurse -Force
    }
}
