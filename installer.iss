; Inno Setup Script for Local LLM Manager (Powered by Foundry Local SDK)
; https://jrsoftware.org/isinfo.php

#define MyAppName "Local LLM Manager"
#define MyAppVersion "1.0.0"
#define MyAppExeName "LocalLLMManager.exe"
#define MyAppPublisher "Local LLM Manager"

; .NET 10 download URL (framework-dependent)
#define DotNetDownloadUrl "https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x64.exe"
#define DotNetInstallerName "windowsdesktop-runtime-win-x64.exe"
#define DotNetVersion "10.0"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=LocalLLMManager_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=compiler:SetupClassicIcon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "bin\Release\net10.0-windows10.0.26100\win-x64\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

function IsDotNetInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('cmd', '/c dotnet --list-runtimes 2>nul | findstr /C:"Microsoft.NETCore.App {#DotNetVersion}"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax <> 0 then
    Log(Format('  %d of %d bytes done.', [Progress, ProgressMax]))
  else
    Log(Format('  %d bytes done.', [Progress]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), @OnDownloadProgress);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  if CurPageID = wpReady then
  begin
    if not IsDotNetInstalled() then
    begin
      if MsgBox('.NET {#DotNetVersion} Runtime is required.'#13#10'Download and install now?', mbConfirmation, MB_YESNO) = IDYES then
      begin
        DownloadPage.Clear;
        DownloadPage.Add('{#DotNetDownloadUrl}', '{#DotNetInstallerName}', '');
        DownloadPage.Show;
        try
          try
            DownloadPage.Download;
            if not Exec(ExpandConstant('{tmp}\{#DotNetInstallerName}'), '/install /quiet /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
            begin
              MsgBox('.NET Runtime installation failed. Please install manually from https://dotnet.microsoft.com/download', mbError, MB_OK);
              Result := False;
            end;
          except
            if DownloadPage.AbortedByUser then
              Log('Download aborted by user.')
            else
              SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
            Result := False;
          end;
        finally
          DownloadPage.Hide;
        end;
      end
      else
      begin
        MsgBox('.NET {#DotNetVersion} Runtime is required to run this application.', mbError, MB_OK);
        Result := False;
      end;
    end;
  end;
end;
