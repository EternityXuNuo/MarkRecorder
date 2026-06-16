; 综测笺 Windows 安装包脚本（Inno Setup 6）
; 用法：
;   1. 先构建 release：在项目根目录执行  flutter build windows --release
;      产物在  build\windows\x64\runner\Release\  （含 mark_recoder.exe、各 DLL 与 data\）
;   2. 安装 Inno Setup 6（https://jrsoftware.org/isdl.php）
;   3. 编译本脚本：
;        - 双击本文件用 Inno Setup 打开，点 Build；或
;        - 命令行： "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\mark_recoder.iss
;   4. 安装包输出到  build\windows\installer\综测笺-<版本>-setup.exe

#define MyAppName "综测笺"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "EternityXuNuo"
#define MyAppExeName "mark_recoder.exe"
; 安装目录与开始菜单文件夹用的英文名（显示名仍为 MyAppName）
#define MyAppDirName "MarkRecorder"
; 相对本 .iss 文件所在目录（windows\installer\）的路径
#ifndef ReleaseDir
  #define ReleaseDir "C:\Users\wsx17\Downloads\Release"
#endif

[Setup]
; AppId 唯一标识本应用，升级时保持不变（换了它会被当成另一个软件并行安装）
AppId={{A8F3C2E1-5B7D-4E9A-9C12-3F6D8B0A1E47}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppDirName}
DefaultGroupName={#MyAppDirName}
; 允许普通用户安装到本人目录（无需管理员）；如需写入 Program Files 改为 admin
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
OutputDir=..\..\build\windows\installer
OutputBaseFilename=MarkRecorder-{#MyAppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
; Inno 自带英文；简体中文需另装 ChineseSimplified.isl（见文末说明）后取消下一行注释
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 打包整个 Release 目录（exe + 所有 DLL + data\ 资源），缺一不可
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
