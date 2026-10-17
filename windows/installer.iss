[Setup]
AppName=QuietRead
AppVersion=1.0.0
DefaultDirName={pf}\Text To Voice
OutputDir=build/windows/installer
OutputBaseFilename=QuietRead-Setup
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "Tạo biểu tượng trên desktop"; GroupDescription: "Bổ sung:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Text To Voice"; Filename: "{app}\text_to_voice.exe"
Name: "{autodesktop}\Text To Voice"; Filename: "{app}\text_to_voice.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\text_to_voice.exe"; Description: "Khởi động Text To Voice"; Flags: nowait postinstall skipifsilent
