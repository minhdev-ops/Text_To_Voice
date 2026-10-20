[Setup]
AppName=QuietRead
AppVersion=1.0.0
DefaultDirName={pf}\QuietRead
OutputDir=..\build\windows\installer
OutputBaseFilename=QuietRead-Setup
SetupIconFile=runner\resources\app_icon.ico
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "Tạo biểu tượng trên desktop"; GroupDescription: "Bổ sung:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\QuietRead"; Filename: "{app}\text_to_voice.exe"
Name: "{autodesktop}\QuietRead"; Filename: "{app}\text_to_voice.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\text_to_voice.exe"; Description: "Khởi động QuietRead"; Flags: nowait postinstall skipifsilent
