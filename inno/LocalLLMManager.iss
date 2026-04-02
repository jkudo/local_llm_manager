#define MyAppName "Local LLM Manager"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "jkudo"
#define MyAppExeName "LocalLLMManager.exe"
#ifndef MyPublishDir
  #define MyPublishDir "bin\\Release\\net10.0-windows10.0.26100\\win-x64\\publish"
#endif
#ifndef MyOutputDir
  #define MyOutputDir "installer_output"
#endif
#ifndef MyDotNetInstallerPath
  #define MyDotNetInstallerPath ""
#endif
#if MyDotNetInstallerPath == ""
  #error "MyDotNetInstallerPath is required. Pass /DMyDotNetInstallerPath=<path-to-dotnet-runtime-installer>."
#endif
#define MyDotNetInstallerFileName "dotnet-runtime-10-win-x64.exe"

[Setup]
AppId={{4B7982F3-926F-4E8A-8C8A-3A11D8B7EE7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Local LLM Manager
DefaultGroupName=Local LLM Manager
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=LocalLLMManager_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyPublishDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "Microsoft.AI.Foundry.Local*.dll,Microsoft.ML.OnnxRuntime*.dll,onnxruntime*.dll,dxcompiler.dll,dxil.dll"
Source: "{#MyDotNetInstallerPath}"; Flags: dontcopy; DestName: "{#MyDotNetInstallerFileName}"

[Icons]
Name: "{autoprograms}\\Local LLM Manager"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\Local LLM Manager"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Local LLM Manager}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DotNetInstallNeedsRestart: Boolean;

function HasDotNet10VersionPrefix(const VersionSubkeys: TArrayOfString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to GetArrayLength(VersionSubkeys) - 1 do
  begin
    if Pos('10.', VersionSubkeys[I]) = 1 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function HasDotNet10RuntimeInRegistry: Boolean;
var
  VersionSubkeys: TArrayOfString;
begin
  Result := False;

  if RegGetSubkeyNames(HKLM64, 'SOFTWARE\\dotnet\\Setup\\InstalledVersions\\x64\\sharedfx\\Microsoft.NETCore.App', VersionSubkeys) then
  begin
    if HasDotNet10VersionPrefix(VersionSubkeys) then
    begin
      Result := True;
      Exit;
    end;
  end;

  if RegGetSubkeyNames(HKLM, 'SOFTWARE\\dotnet\\Setup\\InstalledVersions\\x64\\sharedfx\\Microsoft.NETCore.App', VersionSubkeys) then
  begin
    if HasDotNet10VersionPrefix(VersionSubkeys) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function HasDotNet10RuntimeInFolder(const RuntimeRoot: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;

  if not DirExists(RuntimeRoot) then
    Exit;

  if FindFirst(AddBackslash(RuntimeRoot) + '10.*', FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        begin
          Result := True;
          Exit;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function HasDotNet10RuntimeViaCommand: Boolean;
var
  ResultCode: Integer;
  CommandLine: String;
begin
  CommandLine := '/c dotnet --list-runtimes 2>nul | findstr /C:"Microsoft.NETCore.App 10."';
  Result := Exec(ExpandConstant('{cmd}'), CommandLine, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function IsDotNet10RuntimeInstalled: Boolean;
begin
  Result := HasDotNet10RuntimeInRegistry;
  if Result then
    Exit;

  Result := HasDotNet10RuntimeInFolder(ExpandConstant('{commonpf}\\dotnet\\shared\\Microsoft.NETCore.App'));
  if Result then
    Exit;

  Result := HasDotNet10RuntimeInFolder(ExpandConstant('{commonpf32}\\dotnet\\shared\\Microsoft.NETCore.App'));
  if Result then
    Exit;

  Result := HasDotNet10RuntimeViaCommand;
end;

function InstallDotNetRuntime: Boolean;
var
  ResultCode: Integer;
  InstallerPath: string;
begin
  Result := True;
  DotNetInstallNeedsRestart := False;

  if IsDotNet10RuntimeInstalled then
  begin
    Exit;
  end;

  if MsgBox('.NET 10 Runtime is required to run Local LLM Manager.'#13#10#13#10'Install it now?', mbConfirmation, MB_YESNO) <> IDYES then
  begin
    MsgBox('Installation was canceled because .NET 10 Runtime is not installed.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  ExtractTemporaryFile('{#MyDotNetInstallerFileName}');
  InstallerPath := ExpandConstant('{tmp}\\{#MyDotNetInstallerFileName}');

  if not Exec(InstallerPath, '/install /quiet /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox('Failed to start .NET 10 Runtime installer.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if (ResultCode <> 0) and (ResultCode <> 3010) then
  begin
    MsgBox(Format('.NET 10 Runtime installer failed. Exit code: %d', [ResultCode]), mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if ResultCode = 3010 then
  begin
    DotNetInstallNeedsRestart := True;
  end;

  Result := IsDotNet10RuntimeInstalled;
  if not Result and DotNetInstallNeedsRestart then
  begin
    MsgBox('.NET 10 Runtime installation requested a restart. Setup will continue.', mbInformation, MB_OK);
    Result := True;
    Exit;
  end;

  if not Result then
  begin
    MsgBox('.NET 10 Runtime installation could not be verified. Setup will stop.', mbError, MB_OK);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  NeedsRestart := False;
  Result := '';

  if not InstallDotNetRuntime then
  begin
    Result := '.NET 10 Runtime installation is required to continue setup.';
    Exit;
  end;

  if DotNetInstallNeedsRestart then
    NeedsRestart := True;
end;
