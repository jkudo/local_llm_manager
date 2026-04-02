param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Version = "1.0.0",
    [string]$DotNetRuntimeUrl = "https://aka.ms/dotnet/10/dotnet-runtime-win-x64.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

$projectFile = Join-Path $projectRoot "LocalLLMManager.csproj"
$launcherProjectFile = Join-Path $projectRoot "launcher\LocalLLMManager.Launcher.csproj"
$publishDir = Join-Path $projectRoot "bin\$Configuration\net10.0-windows10.0.26100\$Runtime\publish"
$innoScript = Join-Path $projectRoot "inno\LocalLLMManager.iss"
$outputDir = Join-Path $projectRoot "installer_output"
$prerequisitesDir = Join-Path $outputDir "prerequisites"
$dotNetInstallerPath = Join-Path $prerequisitesDir "dotnet-runtime-10-win-x64.exe"
$outputExe = Join-Path $outputDir "LocalLLMManager_Setup_$Version.exe"

function Find-IsccPath {
    $candidates = @(
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:LocalAppData "Programs\Inno Setup 6\ISCC.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $isccCmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($isccCmd) {
        return $isccCmd.Path
    }

    return $null
}

Write-Host "=== Step 1: Publish application ==="
dotnet publish $projectFile -c $Configuration -r $Runtime
if ($LASTEXITCODE -ne 0) {
    throw "Application publish failed with exit code: $LASTEXITCODE"
}

Write-Host "=== Step 1.1: Publish launcher ==="
dotnet publish $launcherProjectFile -c $Configuration -r $Runtime
if ($LASTEXITCODE -ne 0) {
    throw "Launcher publish failed with exit code: $LASTEXITCODE"
}

if (-not (Test-Path $publishDir)) {
    throw "Publish directory not found: $publishDir"
}

$launcherPublishDir = Join-Path $projectRoot "launcher\bin\$Configuration\net10.0-windows10.0.26100\$Runtime\publish"
if (-not (Test-Path $launcherPublishDir)) {
    throw "Launcher publish directory not found: $launcherPublishDir"
}

$mainExe = Join-Path $publishDir "LocalLLMManager.exe"
$appExe = Join-Path $publishDir "LocalLLMManager.App.exe"
if (-not (Test-Path $mainExe)) {
    throw "Main executable not found: $mainExe"
}

Move-Item -Path $mainExe -Destination $appExe -Force

$launcherExe = Join-Path $launcherPublishDir "LocalLLMManagerLauncher.exe"
$launcherDll = Join-Path $launcherPublishDir "LocalLLMManagerLauncher.dll"
$launcherDeps = Join-Path $launcherPublishDir "LocalLLMManagerLauncher.deps.json"
$launcherRuntimeConfig = Join-Path $launcherPublishDir "LocalLLMManagerLauncher.runtimeconfig.json"

foreach ($launcherFile in @($launcherExe, $launcherDll, $launcherDeps, $launcherRuntimeConfig)) {
    if (-not (Test-Path $launcherFile)) {
        throw "Launcher file not found: $launcherFile"
    }
}

Copy-Item -Path $launcherExe -Destination (Join-Path $publishDir "LocalLLMManager.exe") -Force
Copy-Item -Path $launcherDll -Destination $publishDir -Force
Copy-Item -Path $launcherDeps -Destination $publishDir -Force
Copy-Item -Path $launcherRuntimeConfig -Destination $publishDir -Force

if (-not (Test-Path $innoScript)) {
    throw "Inno script not found: $innoScript"
}

$isccExe = Find-IsccPath
if (-not $isccExe) {
    throw "ISCC.exe was not found. Install Inno Setup 6 first."
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
New-Item -ItemType Directory -Path $prerequisitesDir -Force | Out-Null

Write-Host "=== Step 2: Download .NET runtime installer ==="
Invoke-WebRequest -Uri $DotNetRuntimeUrl -OutFile $dotNetInstallerPath

if (-not (Test-Path $dotNetInstallerPath)) {
    throw ".NET runtime installer download failed: $dotNetInstallerPath"
}

Write-Host "=== Step 3: Build installer with Inno Setup ==="
& $isccExe "/DMyAppVersion=$Version" "/DMyPublishDir=$publishDir" "/DMyOutputDir=$outputDir" "/DMyDotNetInstallerPath=$dotNetInstallerPath" $innoScript

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compile failed with exit code: $LASTEXITCODE"
}

if (-not (Test-Path $outputExe)) {
    throw "Installer output not found: $outputExe"
}

Write-Host ""
Write-Host "=== Done ==="
Write-Host "Installer: $outputExe"
