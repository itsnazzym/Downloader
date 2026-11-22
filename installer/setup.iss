[Setup]
; Keep this ID equal to the original AppName: older installers relied on AppName as
; Inno Setup's default AppId, so changing it would create a second installation.
AppId=Modern Downloader
AppName=TapLoad
AppVersion={#AppVersion}
AppVerName=TapLoad {#AppVersion}
AppPublisher=itsnazzym
AppCopyright=Copyright (C) 2023-2026 itsnazzym
AppComments=Privacy-first media downloader for Windows.
AppPublisherURL=https://github.com/itsnazzym/Downloader
AppSupportURL=https://github.com/itsnazzym/Downloader/issues
AppUpdatesURL=https://github.com/itsnazzym/Downloader/releases
AppReadmeFile=https://github.com/itsnazzym/Downloader#readme
DefaultDirName={autopf}\ModernDownloader
UsePreviousAppDir=yes
DisableDirPage=auto
DefaultGroupName=TapLoad
DisableProgramGroupPage=yes
AlwaysShowDirOnReadyPage=yes
LicenseFile=..\LICENSE
UninstallDisplayName=TapLoad
UninstallDisplayIcon={app}\modern_downloader.exe
OutputBaseFilename=ModernDownloader-Setup-{#AppVersion}
OutputDir=..\release
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
ChangesAssociations=yes
; Restart Manager finds processes using these installation files and force closes
; them before replacing the executable or its loaded native libraries.
CloseApplications=force
CloseApplicationsFilter=modern_downloader.exe,*.dll,*.chm
RestartApplications=no
UpdateUninstallLogAppName=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
fr.ShortcutsGroup=Raccourcis supplémentaires :
en.ShortcutsGroup=Additional shortcuts:
fr.DesktopShortcutTask=Créer un raccourci sur le bureau
en.DesktopShortcutTask=Create a desktop shortcut
fr.StartupGroup=Démarrage de Windows :
en.StartupGroup=Windows startup:
fr.StartupTask=Lancer TapLoad au démarrage de Windows
en.StartupTask=Launch TapLoad when Windows starts
fr.LaunchApplication=Lancer TapLoad
en.LaunchApplication=Launch TapLoad

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "..\LICENSE"; DestDir: "{app}\Documentation"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}\Documentation"; Flags: ignoreversion
Source: "..\CHANGELOG.md"; DestDir: "{app}\Documentation"; Flags: ignoreversion

[InstallDelete]
; Raccourcis de l'ancien nom (Modern Downloader) remplacés par ceux de TapLoad
Type: files; Name: "{group}\Modern Downloader.lnk"
Type: files; Name: "{group}\Uninstall Modern Downloader.lnk"
Type: files; Name: "{autodesktop}\Modern Downloader.lnk"
Type: files; Name: "{autostartup}\Modern Downloader.lnk"

[Icons]
Name: "{group}\TapLoad"; Filename: "{app}\modern_downloader.exe"
Name: "{group}\Uninstall TapLoad"; Filename: "{uninstallexe}"
Name: "{autodesktop}\TapLoad"; Filename: "{app}\modern_downloader.exe"; Tasks: desktopicon
Name: "{autostartup}\TapLoad"; Filename: "{app}\modern_downloader.exe"; Tasks: startup

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcutTask}"; GroupDescription: "{cm:ShortcutsGroup}"
Name: "startup"; Description: "{cm:StartupTask}"; GroupDescription: "{cm:StartupGroup}"; Flags: unchecked

[Run]
Filename: "{app}\modern_downloader.exe"; Description: "{cm:LaunchApplication}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\moderndownloader"; ValueType: string; ValueName: ""; ValueData: "URL:TapLoad Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\moderndownloader"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\moderndownloader\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\modern_downloader.exe,0"
Root: HKCU; Subkey: "Software\Classes\moderndownloader\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\modern_downloader.exe"" ""%1"""
