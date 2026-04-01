@echo off
REM ============================================
REM Build script for LocalLLMManager installer
REM ============================================
REM Prerequisites:
REM   - .NET 10 SDK
REM   - Inno Setup 6 (https://jrsoftware.org/isdl.php)
REM
REM Usage:
REM   build-installer.bat
REM ============================================

echo === Step 1: Publish application ===
dotnet publish -r win-x64 -c Release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: dotnet publish failed.
    exit /b 1
)

echo.
echo === Step 2: Build installer ===
where iscc >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    REM Try default install location
    if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
        "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" installer.iss
    ) else (
        echo ERROR: Inno Setup Compiler (ISCC.exe) not found.
        echo Install Inno Setup 6 from https://jrsoftware.org/isdl.php
        exit /b 1
    )
) else (
    iscc installer.iss
)

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Installer build failed.
    exit /b 1
)

echo.
echo === Done ===
echo Installer: installer_output\LocalChat_Setup_1.0.0.exe
