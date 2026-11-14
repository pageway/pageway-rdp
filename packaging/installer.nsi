Unicode true
SetCompressor /SOLID lzma
ManifestDPIAware true

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "WinVer.nsh"
!include "x64.nsh"

!ifndef VERSION
  !error "VERSION is required"
!endif
!ifndef MODE
  !error "MODE is required"
!endif
!ifndef ARCH
  !error "ARCH is required"
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required"
!endif
!ifndef GATEWAY_EXE
  !error "GATEWAY_EXE is required"
!endif
!ifndef WEB_DIR
  !error "WEB_DIR is required"
!endif
!ifndef ROOT_DIR
  !error "ROOT_DIR is required"
!endif
!ifndef BUILD_ASSETS
  !error "BUILD_ASSETS is required"
!endif

!define PRODUCT_NAME "Pageway"
!define PRODUCT_PUBLISHER "Pageway"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Pageway"
!define SETTINGS_KEY "Software\Pageway"

!if "${MODE}" == "machine"
  !define REG_ROOT HKLM
  !define EXECUTION_LEVEL admin
  !define SHELL_CONTEXT all
  !define DEFAULT_INSTALL_DIR "$PROGRAMFILES64\Pageway"
!else if "${MODE}" == "user"
  !define REG_ROOT HKCU
  !define EXECUTION_LEVEL user
  !define SHELL_CONTEXT current
  !define DEFAULT_INSTALL_DIR "$LOCALAPPDATA\Programs\Pageway"
!else
  !error "MODE must be machine or user"
!endif

Name "${PRODUCT_NAME}"
OutFile "${OUTPUT_FILE}"
Icon "${ROOT_DIR}\assets\pageway-app.ico"
UninstallIcon "${ROOT_DIR}\assets\pageway-app.ico"
InstallDir "${DEFAULT_INSTALL_DIR}"
RequestExecutionLevel ${EXECUTION_LEVEL}
BrandingText "${PRODUCT_NAME} ${VERSION}"
VIProductVersion "${VERSION}.0"
VIFileVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "Pageway installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "MIT"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"

!define MUI_ICON "${ROOT_DIR}\assets\pageway-app.ico"
!define MUI_UNICON "${ROOT_DIR}\assets\pageway-app.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEFINISHPAGE_BITMAP "${BUILD_ASSETS}\welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${BUILD_ASSETS}\header.bmp"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_FINISHPAGE_RUN "$INSTDIR\pageway-gateway.exe"
!define MUI_FINISHPAGE_RUN_FUNCTION OpenLogin
!define MUI_FINISHPAGE_RUN_TEXT "$(FinishRun)"
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!define MUI_DIRECTORYPAGE_TEXT_TOP "$(DirectoryText)"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom ConfigCreate ConfigLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_RESERVEFILE_LANGDLL

LangString WelcomeText ${LANG_ENGLISH} "Setup will install Pageway on this computer.$\r$\n$\r$\nPageway connects your browser to the existing Windows Remote Desktop on this PC.$\r$\n$\r$\nClick Next to continue."
LangString WelcomeText ${LANG_SIMPCHINESE} "将在计算机上安装 Pageway。$\r$\n$\r$\nPageway 通过浏览器连接本机已有的 Windows 远程桌面。$\r$\n$\r$\n单击“下一步”继续。"
LangString DirectoryText ${LANG_ENGLISH} "Choose where to install Pageway, then click Next."
LangString DirectoryText ${LANG_SIMPCHINESE} "选择 Pageway 的安装文件夹，然后单击“下一步”。"
LangString ConfigTitle ${LANG_ENGLISH} "Connection settings"
LangString ConfigTitle ${LANG_SIMPCHINESE} "连接设置"
LangString ConfigSubtitle ${LANG_ENGLISH} "Only the web port needs to be configured."
LangString ConfigSubtitle ${LANG_SIMPCHINESE} "只需设置网页端口。"
LangString PortLabel ${LANG_ENGLISH} "Web port (default: 7172)"
LangString PortLabel ${LANG_SIMPCHINESE} "网页端口（默认：7172）"
LangString PreparationHint ${LANG_ENGLISH} "Setup enables Windows Remote Desktop, allows Pageway through Windows Firewall, and starts Pageway when you sign in."
LangString PreparationHint ${LANG_SIMPCHINESE} "安装将启用本机远程桌面、允许 Pageway 通过防火墙，并在登录 Windows 后自动启动。"
LangString ElevationHint ${LANG_ENGLISH} "A per-user installation may request administrator approval once for the required system setup."
LangString ElevationHint ${LANG_SIMPCHINESE} "当前用户安装可能因必要的系统配置请求一次管理员授权。"
LangString InvalidPort ${LANG_ENGLISH} "Enter a port from 1 to 65535."
LangString InvalidPort ${LANG_SIMPCHINESE} "请输入 1 到 65535 之间的端口。"
LangString UnsupportedWindows ${LANG_ENGLISH} "Pageway requires Windows 10 or later, or Windows Server 2016 or later."
LangString UnsupportedWindows ${LANG_SIMPCHINESE} "Pageway 需要 Windows 10 或更高版本，或 Windows Server 2016 或更高版本。"
LangString MissingRdpHost ${LANG_ENGLISH} "This Windows edition does not include the Remote Desktop host component. Use Windows Pro, Enterprise, Education, or Server. Pageway does not install Windows components."
LangString MissingRdpHost ${LANG_SIMPCHINESE} "当前 Windows 版本没有远程桌面宿主组件。请使用专业版、企业版、教育版或服务器版。Pageway 不会安装 Windows 组件。"
LangString SystemConfigFailed ${LANG_ENGLISH} "Windows Remote Desktop or firewall setup was not completed. You can still use Pageway on this PC, or run the installer again as an administrator."
LangString SystemConfigFailed ${LANG_SIMPCHINESE} "Windows 远程桌面或防火墙配置未完成。你仍可在本机使用 Pageway，也可以以管理员身份重新运行安装程序。"
LangString TaskFailed ${LANG_ENGLISH} "Pageway could not be started automatically. Check the installation log and run the installer again."
LangString TaskFailed ${LANG_SIMPCHINESE} "Pageway 无法自动启动。请检查安装日志，并重新运行安装程序。"
LangString FinishRun ${LANG_ENGLISH} "Open Pageway"
LangString FinishRun ${LANG_SIMPCHINESE} "打开 Pageway"
LangString RemoveData ${LANG_ENGLISH} "Also delete Pageway settings and logs?"
LangString RemoveData ${LANG_SIMPCHINESE} "是否同时删除 Pageway 的配置和日志？"

Var Dialog
Var PortInput
Var Port
Var ConfigDir
Var RemoveData

Function .onInit
  !insertmacro MUI_LANGDLL_DISPLAY
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP|MB_OK "$(UnsupportedWindows)"
    Abort
  ${EndIf}
  SetRegView 64
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" "EditionID"
  StrCmp $0 "" missing_rdp_host
  StrCpy $1 $0 4
  StrCmp $1 "Core" missing_rdp_host
  ClearErrors
  ReadRegDWORD $0 HKLM "SYSTEM\CurrentControlSet\Services\TermService" "Start"
  IfErrors missing_rdp_host
  ClearErrors
  ReadRegDWORD $0 HKLM "SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections"
  IfErrors missing_rdp_host
  Goto rdp_host_present
  missing_rdp_host:
    MessageBox MB_ICONSTOP|MB_OK "$(MissingRdpHost)"
    Abort
  rdp_host_present:
  SetShellVarContext current
  StrCpy $ConfigDir "$LOCALAPPDATA\Pageway"
  SetShellVarContext ${SHELL_CONTEXT}
  StrCpy $Port "7172"
  ReadRegStr $0 ${REG_ROOT} "${SETTINGS_KEY}" "InstallLocation"
  ${If} $0 != ""
    StrCpy $INSTDIR $0
  ${EndIf}
  ReadRegStr $0 ${REG_ROOT} "${SETTINGS_KEY}" "Port"
  ${If} $0 != ""
    StrCpy $Port $0
  ${EndIf}
FunctionEnd

Function ConfigCreate
  !insertmacro MUI_HEADER_TEXT "$(ConfigTitle)" "$(ConfigSubtitle)"
  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 14u "$(PortLabel)"
  Pop $0
  ${NSD_CreateText} 0 18u 100% 14u $Port
  Pop $PortInput
  ${NSD_SetTextLimit} $PortInput 5

  ${NSD_CreateLabel} 0 46u 100% 42u "$(PreparationHint)"
  Pop $0
  ${NSD_CreateLabel} 0 96u 100% 30u "$(ElevationHint)"
  Pop $0

  nsDialogs::Show
FunctionEnd

Function ConfigLeave
  ${NSD_GetText} $PortInput $Port
  ${If} $Port < 1
  ${OrIf} $Port > 65535
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(InvalidPort)"
    Abort
  ${EndIf}
FunctionEnd

Function OpenLogin
  ExecShell "open" "http://127.0.0.1:$Port/"
FunctionEnd

Section "Install"
  SetRegView 64
  SetShellVarContext ${SHELL_CONTEXT}
  nsExec::ExecToLog 'schtasks.exe /End /TN "Pageway"'
  IfFileExists "$INSTDIR\configure-system.ps1" 0 no_existing_install
  nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configure-system.ps1" -GatewayPath "$INSTDIR\pageway-gateway.exe" -StopGateway'
  no_existing_install:
  SetOutPath $INSTDIR
  File "/oname=pageway-gateway.exe" "${GATEWAY_EXE}"
  File "/oname=pageway-app.ico" "${ROOT_DIR}\assets\pageway-app.ico"
  File "/oname=configure-system.ps1" "${ROOT_DIR}\packaging\configure-system.ps1"
  SetOutPath "$INSTDIR\web"
  File /r "${WEB_DIR}\*.*"

  CreateDirectory $ConfigDir
  SetDetailsPrint both
  nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configure-system.ps1" -GatewayPath "$INSTDIR\pageway-gateway.exe" -ConfigPath "$ConfigDir\config.json" -Port $Port'
  Pop $0
  Pop $1
  DetailPrint $1
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(SystemConfigFailed)" /SD IDOK
  ${EndIf}

  WriteRegStr ${REG_ROOT} "${SETTINGS_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr ${REG_ROOT} "${SETTINGS_KEY}" "Port" "$Port"
  WriteRegDWORD ${REG_ROOT} "${SETTINGS_KEY}" "ConfiguredSystem" 1
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "DisplayName" "Pageway"
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\pageway-gateway.exe"
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr ${REG_ROOT} "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD ${REG_ROOT} "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD ${REG_ROOT} "${UNINSTALL_KEY}" "NoRepair" 1

  nsExec::ExecToStack 'schtasks.exe /Create /TN "Pageway" /SC ONLOGON /RL LIMITED /IT /F /TR "\"$INSTDIR\pageway-gateway.exe\" --config \"$ConfigDir\config.json\" --log \"$ConfigDir\gateway.log\""'
  Pop $0
  Pop $1
  DetailPrint $1
  ${If} $0 == 0
    nsExec::ExecToLog 'schtasks.exe /Run /TN "Pageway"'
  ${Else}
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(TaskFailed)" /SD IDOK
  ${EndIf}

  CreateDirectory "$SMPROGRAMS\Pageway"
  WriteINIStr "$SMPROGRAMS\Pageway\Pageway.url" "InternetShortcut" "URL" "http://127.0.0.1:$Port/"
  WriteINIStr "$SMPROGRAMS\Pageway\Pageway.url" "InternetShortcut" "IconFile" "$INSTDIR\pageway-app.ico"
  WriteINIStr "$SMPROGRAMS\Pageway\Pageway.url" "InternetShortcut" "IconIndex" "0"
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
  SetRegView 64
  SetShellVarContext current
  StrCpy $ConfigDir "$LOCALAPPDATA\Pageway"
  SetShellVarContext ${SHELL_CONTEXT}
FunctionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext ${SHELL_CONTEXT}
  StrCpy $RemoveData 1
  ${IfNot} ${Silent}
    MessageBox MB_YESNO|MB_ICONQUESTION "$(RemoveData)" IDYES +2
    StrCpy $RemoveData 0
  ${EndIf}

  nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configure-system.ps1" -GatewayPath "$INSTDIR\pageway-gateway.exe" -StopGateway'
  nsExec::ExecToLog 'schtasks.exe /End /TN "Pageway"'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "Pageway" /F'
  ReadRegDWORD $0 ${REG_ROOT} "${SETTINGS_KEY}" "ConfiguredSystem"
  ${If} $0 == 1
    nsExec::ExecToLog 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configure-system.ps1" -GatewayPath "$INSTDIR\pageway-gateway.exe" -Remove'
  ${EndIf}

  RMDir /r "$SMPROGRAMS\Pageway"
  DeleteRegKey ${REG_ROOT} "${UNINSTALL_KEY}"
  DeleteRegKey ${REG_ROOT} "${SETTINGS_KEY}"
  ${If} $RemoveData == 1
    RMDir /r $ConfigDir
  ${EndIf}
  SetOutPath $TEMP
  RMDir /r $INSTDIR
SectionEnd
