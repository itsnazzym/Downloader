[Setup]
AppName=Modern Downloader
AppVersion={#AppVersion}
AppPublisher=Mizaruta
DefaultDirName={autopf}\ModernDownloader
DefaultGroupName=Modern Downloader
UninstallDisplayIcon={app}\modern_downloader.exe
OutputBaseFilename=ModernDownloader-Setup-{#AppVersion}
OutputDir=..\
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Modern Downloader"; Filename: "{app}\modern_downloader.exe"
Name: "{group}\Uninstall Modern Downloader"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Modern Downloader"; Filename: "{app}\modern_downloader.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\modern_downloader.exe"; Description: "Launch Modern Downloader"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\moderndownloader"; ValueType: string; ValueName: ""; ValueData: "URL:Modern Downloader Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\moderndownloader"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\moderndownloader\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\modern_downloader.exe,0"
Root: HKCU; Subkey: "Software\Classes\moderndownloader\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\modern_downloader.exe"" ""%1"""
