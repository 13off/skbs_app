#ifndef BuildDir
  #define BuildDir "..\\..\\build\\windows\\x64\\runner\\Release"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "..\\..\\windows-output"
#endif

#define MyAppName "AppStroy"
#define MyAppExeName "AppStroy.exe"
#define MyPublisher "SKBS"
#define MyAppId "{{7F0CF35D-1B1B-4C9B-A6E0-42B83C706322}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyPublisher}
DefaultDirName={localappdata}\Programs\AppStroy
DefaultGroupName=AppStroy
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=AppStroy-Windows-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные ярлыки:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AppStroy"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\AppStroy"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить AppStroy"; Flags: nowait postinstall skipifsilent
