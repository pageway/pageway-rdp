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

!define PRODUCT_NAME "Pageway RDP"
!define PRODUCT_PUBLISHER "Pageway"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define SETTINGS_KEY "Software\${PRODUCT_NAME}"

Name "${PRODUCT_NAME}"
OutFile "${OUTPUT_FILE}"
Icon "${ROOT_DIR}\assets\pageway-app.ico"
UninstallIcon "${ROOT_DIR}\assets\pageway-app.ico"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
RequestExecutionLevel admin
BrandingText "${PRODUCT_NAME} ${VERSION}"
VIProductVersion "${VERSION}.0"
VIFileVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} installer"
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
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!define MUI_DIRECTORYPAGE_TEXT_TOP "$(DirectoryText)"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom ConfigCreate ConfigLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_PAGE_CUSTOMFUNCTION_SHOW FinishShow
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_RESERVEFILE_LANGDLL

LangString WelcomeText ${LANG_ENGLISH} "Setup will install Pageway RDP on this computer.$\r$\n$\r$\nPageway RDP connects your browser to the existing Windows Remote Desktop on this PC.$\r$\n$\r$\nClick Next to continue."
LangString WelcomeText ${LANG_SIMPCHINESE} "将在计算机上安装 Pageway RDP。$\r$\n$\r$\nPageway RDP 通过浏览器连接本机已有的 Windows 远程桌面。$\r$\n$\r$\n单击“下一步”继续。"
LangString DirectoryText ${LANG_ENGLISH} "Choose where to install Pageway RDP, then click Next."
LangString DirectoryText ${LANG_SIMPCHINESE} "选择 Pageway RDP 的安装文件夹，然后单击“下一步”。"
LangString ConfigTitle ${LANG_ENGLISH} "Connection settings"
LangString ConfigTitle ${LANG_SIMPCHINESE} "连接设置"
LangString ConfigSubtitle ${LANG_ENGLISH} "Only the web port needs to be configured."
LangString ConfigSubtitle ${LANG_SIMPCHINESE} "只需设置网页端口。"
LangString PortLabel ${LANG_ENGLISH} "Web port (default: 7172)"
LangString PortLabel ${LANG_SIMPCHINESE} "网页端口（默认：7172）"
LangString PreparationHint ${LANG_ENGLISH} "Setup enables Windows Remote Desktop, allows Pageway RDP through Windows Firewall, and starts it when you sign in."
LangString PreparationHint ${LANG_SIMPCHINESE} "安装将启用本机远程桌面、允许 Pageway RDP 通过防火墙，并在登录 Windows 后自动启动。"
LangString InvalidPort ${LANG_ENGLISH} "Enter a port from 1 to 65535."
LangString InvalidPort ${LANG_SIMPCHINESE} "请输入 1 到 65535 之间的端口。"
LangString UnsupportedWindows ${LANG_ENGLISH} "Pageway RDP requires Windows 10 or later, or Windows Server 2016 or later."
LangString UnsupportedWindows ${LANG_SIMPCHINESE} "Pageway RDP 需要 Windows 10 或更高版本，或 Windows Server 2016 或更高版本。"
LangString MissingRdpHost ${LANG_ENGLISH} "This Windows edition does not include the Remote Desktop host component. Use Windows Pro, Enterprise, Education, or Server. Pageway RDP does not install Windows components."
LangString MissingRdpHost ${LANG_SIMPCHINESE} "当前 Windows 版本没有远程桌面宿主组件。请使用专业版、企业版、教育版或服务器版。Pageway RDP 不会安装 Windows 组件。"
LangString SystemConfigFailed ${LANG_ENGLISH} "Windows Remote Desktop or firewall setup was not completed, so other devices may not be able to connect. Check the installation log and run the installer again."
LangString SystemConfigFailed ${LANG_SIMPCHINESE} "Windows 远程桌面或防火墙配置未完成，其他设备可能无法连接。请检查安装日志后重新运行安装程序。"
LangString TaskFailed ${LANG_ENGLISH} "Pageway RDP could not be started automatically. Check the installation log and run the installer again."
LangString TaskFailed ${LANG_SIMPCHINESE} "Pageway RDP 无法自动启动。请检查安装日志，并重新运行安装程序。"
LangString FinishText ${LANG_ENGLISH} "Pageway RDP is installed and starts when you sign in to Windows.$\r$\n$\r$\nOn another device on the same network, open one of these addresses in a browser:"
LangString FinishText ${LANG_SIMPCHINESE} "Pageway RDP 已安装，登录 Windows 后会自动启动。$\r$\n$\r$\n在同一网络的另一台设备上，用浏览器打开以下任一地址："
LangString FinishHint ${LANG_ENGLISH} "If this PC's IP address changes, use the new address with port $Port."
LangString FinishHint ${LANG_SIMPCHINESE} "这台电脑的 IP 地址变化后，请改用新地址加端口 $Port。"
LangString NoAddress ${LANG_ENGLISH} "No network address was found. Use this PC's IP address with port $Port."
LangString NoAddress ${LANG_SIMPCHINESE} "未检测到网络地址。请使用这台电脑的 IP 地址加端口 $Port。"
LangString RemoveData ${LANG_ENGLISH} "Also delete Pageway RDP settings and logs?"
LangString RemoveData ${LANG_SIMPCHINESE} "是否同时删除 Pageway RDP 的配置和日志？"

Var Dialog
Var PortInput
Var Port
Var ConfigDir
Var RemoveData
Var Addresses
Var SystemFailed

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
  StrCpy $ConfigDir "$LOCALAPPDATA\${PRODUCT_NAME}"
  SetShellVarContext all
  StrCpy $Port "7172"
  ReadRegStr $0 HKLM "${SETTINGS_KEY}" "InstallLocation"
  ${If} $0 != ""
    StrCpy $INSTDIR $0
  ${EndIf}
  ReadRegStr $0 HKLM "${SETTINGS_KEY}" "Port"
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

Function FinishShow
  ShowWindow $mui.FinishPage.Text ${SW_HIDE}
  ${NSD_CreateLabel} 120u 45u 195u 44u "$(FinishText)"
  Pop $0
  SetCtlColors $0 "" "${MUI_BGCOLOR}"
  ${If} $Addresses == ""
    StrCpy $Addresses "$(NoAddress)"
  ${EndIf}
  nsDialogs::CreateControl EDIT ${DEFAULT_STYLES}|${WS_TABSTOP}|${ES_MULTILINE}|${ES_AUTOVSCROLL}|${ES_READONLY} ${WS_EX_CLIENTEDGE} 120u 92u 195u 52u $Addresses
  Pop $0
  SetCtlColors $0 "" "FFFFFF"
  ${NSD_CreateLabel} 120u 150u 195u 24u "$(FinishHint)"
  Pop $0
  SetCtlColors $0 "" "${MUI_BGCOLOR}"
FunctionEnd

Section "Install"
  SetRegView 64
  SetShellVarContext all
  StrCpy $SystemFailed 0
  nsExec::ExecToLog 'schtasks.exe /End /TN "${PRODUCT_NAME}"'
  nsExec::ExecToLog 'taskkill.exe /F /IM pageway-rdp.exe'
  SetOutPath $INSTDIR
  Delete "$INSTDIR\configure-system.ps1"
  File "/oname=pageway-rdp.exe" "${GATEWAY_EXE}"
  SetOutPath "$INSTDIR\web"
  File /r "${WEB_DIR}\*.*"

  SetDetailsPrint both
  CreateDirectory $ConfigDir
  ClearErrors
  FileOpen $0 "$ConfigDir\config.json" w
  ${If} ${Errors}
    StrCpy $SystemFailed 1
  ${Else}
    FileWrite $0 '{$\r$\n  "listen": "0.0.0.0:$Port",$\r$\n  "destination": "127.0.0.1:3389"$\r$\n}$\r$\n'
    FileClose $0
  ${EndIf}

  ClearErrors
  WriteRegDWORD HKLM "SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0
  ReadRegDWORD $0 HKLM "SYSTEM\CurrentControlSet\Services\TermService" "Start"
  ${If} $0 == 4
    WriteRegDWORD HKLM "SYSTEM\CurrentControlSet\Services\TermService" "Start" 3
  ${EndIf}
  ${If} ${Errors}
    StrCpy $SystemFailed 1
  ${EndIf}
  nsExec::ExecToLog 'sc.exe start TermService'
  Pop $0
  ${If} $0 != 0
  ${AndIf} $0 != 1056
    StrCpy $SystemFailed 1
  ${EndIf}

  nsExec::ExecToLog 'netsh.exe advfirewall firewall delete rule name="${PRODUCT_NAME}"'
  nsExec::ExecToLog 'netsh.exe advfirewall firewall add rule name="${PRODUCT_NAME}" dir=in action=allow program="$INSTDIR\pageway-rdp.exe" protocol=TCP profile=any enable=yes'
  Pop $0
  ${If} $0 != 0
    StrCpy $SystemFailed 1
  ${EndIf}

  ${If} $SystemFailed != 0
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(SystemConfigFailed)" /SD IDOK
  ${EndIf}

  WriteRegStr HKLM "${SETTINGS_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${SETTINGS_KEY}" "Port" "$Port"
  WriteRegDWORD HKLM "${SETTINGS_KEY}" "ConfiguredSystem" 1
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\pageway-rdp.exe"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1

  nsExec::ExecToStack 'schtasks.exe /Create /TN "${PRODUCT_NAME}" /SC ONLOGON /RL LIMITED /IT /F /TR "\"$INSTDIR\pageway-rdp.exe\" --config \"$ConfigDir\config.json\" --log \"$ConfigDir\gateway.log\""'
  Pop $0
  Pop $1
  DetailPrint $1
  ${If} $0 == 0
    nsExec::ExecToLog 'schtasks.exe /Run /TN "${PRODUCT_NAME}"'
  ${Else}
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(TaskFailed)" /SD IDOK
  ${EndIf}

  nsExec::ExecToStack '"$INSTDIR\pageway-rdp.exe" --print-urls $Port'
  Pop $0
  Pop $Addresses
  ${If} $0 != 0
    StrCpy $Addresses ""
  ${EndIf}
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
  SetRegView 64
  SetShellVarContext current
  StrCpy $ConfigDir "$LOCALAPPDATA\${PRODUCT_NAME}"
  SetShellVarContext all
FunctionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext all
  StrCpy $RemoveData 1
  ${IfNot} ${Silent}
    MessageBox MB_YESNO|MB_ICONQUESTION "$(RemoveData)" IDYES +2
    StrCpy $RemoveData 0
  ${EndIf}

  nsExec::ExecToLog 'schtasks.exe /End /TN "${PRODUCT_NAME}"'
  nsExec::ExecToLog 'taskkill.exe /F /IM pageway-rdp.exe'
  nsExec::ExecToLog 'schtasks.exe /Delete /TN "${PRODUCT_NAME}" /F'
  ReadRegDWORD $0 HKLM "${SETTINGS_KEY}" "ConfiguredSystem"
  ${If} $0 == 1
    nsExec::ExecToLog 'netsh.exe advfirewall firewall delete rule name="${PRODUCT_NAME}"'
  ${EndIf}

  DeleteRegKey HKLM "${UNINSTALL_KEY}"
  DeleteRegKey HKLM "${SETTINGS_KEY}"
  ${If} $RemoveData == 1
    RMDir /r $ConfigDir
  ${EndIf}
  SetOutPath $TEMP
  RMDir /r $INSTDIR
SectionEnd
