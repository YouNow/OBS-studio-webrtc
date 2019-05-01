; CPack install script designed for a nmake build

;--------------------------------
; You must define these values

  !define VERSION "1.0.0"
  !define PATCH  "0"
  !define INST_DIR "C:/dev/OBS-studio-webrtc/build/_CPack_Packages/win32/NSIS/younow-obs-studio"

;--------------------------------
;Variables

  Var MUI_TEMP
  Var STARTMENU_FOLDER
  Var SV_ALLUSERS
  Var START_MENU
  Var DO_NOT_ADD_TO_PATH
  Var ADD_TO_PATH_ALL_USERS
  Var ADD_TO_PATH_CURRENT_USER
  Var INSTALL_DESKTOP
  Var IS_DEFAULT_INSTALLDIR
;--------------------------------
;Include Modern UI

  !include "MUI.nsh"

  ;Default installation folder
  InstallDir "$PROGRAMFILES\OBS Studio (32bit)"

;--------------------------------
;General

  ;Name and file
  Name "OBS Studio (32bit)"
  OutFile "C:/dev/OBS-studio-webrtc/build/_CPack_Packages/win32/NSIS/younow-obs-studio.exe"

  ;Set compression
  SetCompressor lzma

  ;Require administrator access
  RequestExecutionLevel admin



  !include Sections.nsh

;--- Component support macros: ---
; The code for the add/remove functionality is from:
;   http://nsis.sourceforge.net/Add/Remove_Functionality
; It has been modified slightly and extended to provide
; inter-component dependencies.
Var AR_SecFlags
Var AR_RegFlags


; Loads the "selected" flag for the section named SecName into the
; variable VarName.
!macro LoadSectionSelectedIntoVar SecName VarName
 SectionGetFlags ${${SecName}} $${VarName}
 IntOp $${VarName} $${VarName} & ${SF_SELECTED}  ;Turn off all other bits
!macroend

; Loads the value of a variable... can we get around this?
!macro LoadVar VarName
  IntOp $R0 0 + $${VarName}
!macroend

; Sets the value of a variable
!macro StoreVar VarName IntValue
  IntOp $${VarName} 0 + ${IntValue}
!macroend

!macro InitSection SecName
  ;  This macro reads component installed flag from the registry and
  ;changes checked state of the section on the components page.
  ;Input: section index constant name specified in Section command.

  ClearErrors
  ;Reading component status from registry
  ReadRegDWORD $AR_RegFlags HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32\Components\${SecName}" "Installed"
  IfErrors "default_${SecName}"
    ;Status will stay default if registry value not found
    ;(component was never installed)
  IntOp $AR_RegFlags $AR_RegFlags & ${SF_SELECTED} ;Turn off all other bits
  SectionGetFlags ${${SecName}} $AR_SecFlags  ;Reading default section flags
  IntOp $AR_SecFlags $AR_SecFlags & 0xFFFE  ;Turn lowest (enabled) bit off
  IntOp $AR_SecFlags $AR_RegFlags | $AR_SecFlags      ;Change lowest bit

  ; Note whether this component was installed before
  !insertmacro StoreVar ${SecName}_was_installed $AR_RegFlags
  IntOp $R0 $AR_RegFlags & $AR_RegFlags

  ;Writing modified flags
  SectionSetFlags ${${SecName}} $AR_SecFlags

 "default_${SecName}:"
 !insertmacro LoadSectionSelectedIntoVar ${SecName} ${SecName}_selected
!macroend

!macro FinishSection SecName
  ;  This macro reads section flag set by user and removes the section
  ;if it is not selected.
  ;Then it writes component installed flag to registry
  ;Input: section index constant name specified in Section command.

  SectionGetFlags ${${SecName}} $AR_SecFlags  ;Reading section flags
  ;Checking lowest bit:
  IntOp $AR_SecFlags $AR_SecFlags & ${SF_SELECTED}
  IntCmp $AR_SecFlags 1 "leave_${SecName}"
    ;Section is not selected:
    ;Calling Section uninstall macro and writing zero installed flag
    !insertmacro "Remove_${${SecName}}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32\Components\${SecName}" \
  "Installed" 0
    Goto "exit_${SecName}"

 "leave_${SecName}:"
    ;Section is selected:
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32\Components\${SecName}" \
  "Installed" 1

 "exit_${SecName}:"
!macroend

!macro RemoveSection_CPack SecName
  ;  This macro is used to call section's Remove_... macro
  ;from the uninstaller.
  ;Input: section index constant name specified in Section command.

  !insertmacro "Remove_${${SecName}}"
!macroend

; Determine whether the selection of SecName changed
!macro MaybeSelectionChanged SecName
  !insertmacro LoadVar ${SecName}_selected
  SectionGetFlags ${${SecName}} $R1
  IntOp $R1 $R1 & ${SF_SELECTED} ;Turn off all other bits

  ; See if the status has changed:
  IntCmp $R0 $R1 "${SecName}_unchanged"
  !insertmacro LoadSectionSelectedIntoVar ${SecName} ${SecName}_selected

  IntCmp $R1 ${SF_SELECTED} "${SecName}_was_selected"
  !insertmacro "Deselect_required_by_${SecName}"
  goto "${SecName}_unchanged"

  "${SecName}_was_selected:"
  !insertmacro "Select_${SecName}_depends"

  "${SecName}_unchanged:"
!macroend
;--- End of Add/Remove macros ---

;--------------------------------
;Interface Settings

  !define MUI_HEADERIMAGE
  !define MUI_ABORTWARNING

;----------------------------------------
; based upon a script of "Written by KiCHiK 2003-01-18 05:57:02"
;----------------------------------------
!verbose 3
!include "WinMessages.NSH"
!verbose 4
;====================================================
; get_NT_environment
;     Returns: the selected environment
;     Output : head of the stack
;====================================================
!macro select_NT_profile UN
Function ${UN}select_NT_profile
   StrCmp $ADD_TO_PATH_ALL_USERS "1" 0 environment_single
      DetailPrint "Selected environment for all users"
      Push "all"
      Return
   environment_single:
      DetailPrint "Selected environment for current user only."
      Push "current"
      Return
FunctionEnd
!macroend
!insertmacro select_NT_profile ""
!insertmacro select_NT_profile "un."
;----------------------------------------------------
!define NT_current_env 'HKCU "Environment"'
!define NT_all_env     'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'

!ifndef WriteEnvStr_RegKey
  !ifdef ALL_USERS
    !define WriteEnvStr_RegKey \
       'HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"'
  !else
    !define WriteEnvStr_RegKey 'HKCU "Environment"'
  !endif
!endif

; AddToPath - Adds the given dir to the search path.
;        Input - head of the stack
;        Note - Win9x systems requires reboot

Function AddToPath
  Exch $0
  Push $1
  Push $2
  Push $3

  # don't add if the path doesn't exist
  IfFileExists "$0\*.*" "" AddToPath_done

  ReadEnvStr $1 PATH
  ; if the path is too long for a NSIS variable NSIS will return a 0
  ; length string.  If we find that, then warn and skip any path
  ; modification as it will trash the existing path.
  StrLen $2 $1
  IntCmp $2 0 CheckPathLength_ShowPathWarning CheckPathLength_Done CheckPathLength_Done
    CheckPathLength_ShowPathWarning:
    Messagebox MB_OK|MB_ICONEXCLAMATION "Warning! PATH too long installer unable to modify PATH!"
    Goto AddToPath_done
  CheckPathLength_Done:
  Push "$1;"
  Push "$0;"
  Call StrStr
  Pop $2
  StrCmp $2 "" "" AddToPath_done
  Push "$1;"
  Push "$0\;"
  Call StrStr
  Pop $2
  StrCmp $2 "" "" AddToPath_done
  GetFullPathName /SHORT $3 $0
  Push "$1;"
  Push "$3;"
  Call StrStr
  Pop $2
  StrCmp $2 "" "" AddToPath_done
  Push "$1;"
  Push "$3\;"
  Call StrStr
  Pop $2
  StrCmp $2 "" "" AddToPath_done

  Call IsNT
  Pop $1
  StrCmp $1 1 AddToPath_NT
    ; Not on NT
    StrCpy $1 $WINDIR 2
    FileOpen $1 "$1\autoexec.bat" a
    FileSeek $1 -1 END
    FileReadByte $1 $2
    IntCmp $2 26 0 +2 +2 # DOS EOF
      FileSeek $1 -1 END # write over EOF
    FileWrite $1 "$\r$\nSET PATH=%PATH%;$3$\r$\n"
    FileClose $1
    SetRebootFlag true
    Goto AddToPath_done

  AddToPath_NT:
    StrCmp $ADD_TO_PATH_ALL_USERS "1" ReadAllKey
      ReadRegStr $1 ${NT_current_env} "PATH"
      Goto DoTrim
    ReadAllKey:
      ReadRegStr $1 ${NT_all_env} "PATH"
    DoTrim:
    StrCmp $1 "" AddToPath_NTdoIt
      Push $1
      Call Trim
      Pop $1
      StrCpy $0 "$1;$0"
    AddToPath_NTdoIt:
      StrCmp $ADD_TO_PATH_ALL_USERS "1" WriteAllKey
        WriteRegExpandStr ${NT_current_env} "PATH" $0
        Goto DoSend
      WriteAllKey:
        WriteRegExpandStr ${NT_all_env} "PATH" $0
      DoSend:
      SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

  AddToPath_done:
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd


; RemoveFromPath - Remove a given dir from the path
;     Input: head of the stack

Function un.RemoveFromPath
  Exch $0
  Push $1
  Push $2
  Push $3
  Push $4
  Push $5
  Push $6

  IntFmt $6 "%c" 26 # DOS EOF

  Call un.IsNT
  Pop $1
  StrCmp $1 1 unRemoveFromPath_NT
    ; Not on NT
    StrCpy $1 $WINDIR 2
    FileOpen $1 "$1\autoexec.bat" r
    GetTempFileName $4
    FileOpen $2 $4 w
    GetFullPathName /SHORT $0 $0
    StrCpy $0 "SET PATH=%PATH%;$0"
    Goto unRemoveFromPath_dosLoop

    unRemoveFromPath_dosLoop:
      FileRead $1 $3
      StrCpy $5 $3 1 -1 # read last char
      StrCmp $5 $6 0 +2 # if DOS EOF
        StrCpy $3 $3 -1 # remove DOS EOF so we can compare
      StrCmp $3 "$0$\r$\n" unRemoveFromPath_dosLoopRemoveLine
      StrCmp $3 "$0$\n" unRemoveFromPath_dosLoopRemoveLine
      StrCmp $3 "$0" unRemoveFromPath_dosLoopRemoveLine
      StrCmp $3 "" unRemoveFromPath_dosLoopEnd
      FileWrite $2 $3
      Goto unRemoveFromPath_dosLoop
      unRemoveFromPath_dosLoopRemoveLine:
        SetRebootFlag true
        Goto unRemoveFromPath_dosLoop

    unRemoveFromPath_dosLoopEnd:
      FileClose $2
      FileClose $1
      StrCpy $1 $WINDIR 2
      Delete "$1\autoexec.bat"
      CopyFiles /SILENT $4 "$1\autoexec.bat"
      Delete $4
      Goto unRemoveFromPath_done

  unRemoveFromPath_NT:
    StrCmp $ADD_TO_PATH_ALL_USERS "1" unReadAllKey
      ReadRegStr $1 ${NT_current_env} "PATH"
      Goto unDoTrim
    unReadAllKey:
      ReadRegStr $1 ${NT_all_env} "PATH"
    unDoTrim:
    StrCpy $5 $1 1 -1 # copy last char
    StrCmp $5 ";" +2 # if last char != ;
      StrCpy $1 "$1;" # append ;
    Push $1
    Push "$0;"
    Call un.StrStr ; Find `$0;` in $1
    Pop $2 ; pos of our dir
    StrCmp $2 "" unRemoveFromPath_done
      ; else, it is in path
      # $0 - path to add
      # $1 - path var
      StrLen $3 "$0;"
      StrLen $4 $2
      StrCpy $5 $1 -$4 # $5 is now the part before the path to remove
      StrCpy $6 $2 "" $3 # $6 is now the part after the path to remove
      StrCpy $3 $5$6

      StrCpy $5 $3 1 -1 # copy last char
      StrCmp $5 ";" 0 +2 # if last char == ;
        StrCpy $3 $3 -1 # remove last char

      StrCmp $ADD_TO_PATH_ALL_USERS "1" unWriteAllKey
        WriteRegExpandStr ${NT_current_env} "PATH" $3
        Goto unDoSend
      unWriteAllKey:
        WriteRegExpandStr ${NT_all_env} "PATH" $3
      unDoSend:
      SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

  unRemoveFromPath_done:
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Uninstall sutff
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

###########################################
#            Utility Functions            #
###########################################

;====================================================
; IsNT - Returns 1 if the current system is NT, 0
;        otherwise.
;     Output: head of the stack
;====================================================
; IsNT
; no input
; output, top of the stack = 1 if NT or 0 if not
;
; Usage:
;   Call IsNT
;   Pop $R0
;  ($R0 at this point is 1 or 0)

!macro IsNT un
Function ${un}IsNT
  Push $0
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion
  StrCmp $0 "" 0 IsNT_yes
  ; we are not NT.
  Pop $0
  Push 0
  Return

  IsNT_yes:
    ; NT!!!
    Pop $0
    Push 1
FunctionEnd
!macroend
!insertmacro IsNT ""
!insertmacro IsNT "un."

; StrStr
; input, top of stack = string to search for
;        top of stack-1 = string to search in
; output, top of stack (replaces with the portion of the string remaining)
; modifies no other variables.
;
; Usage:
;   Push "this is a long ass string"
;   Push "ass"
;   Call StrStr
;   Pop $R0
;  ($R0 at this point is "ass string")

!macro StrStr un
Function ${un}StrStr
Exch $R1 ; st=haystack,old$R1, $R1=needle
  Exch    ; st=old$R1,haystack
  Exch $R2 ; st=old$R1,old$R2, $R2=haystack
  Push $R3
  Push $R4
  Push $R5
  StrLen $R3 $R1
  StrCpy $R4 0
  ; $R1=needle
  ; $R2=haystack
  ; $R3=len(needle)
  ; $R4=cnt
  ; $R5=tmp
  loop:
    StrCpy $R5 $R2 $R3 $R4
    StrCmp $R5 $R1 done
    StrCmp $R5 "" done
    IntOp $R4 $R4 + 1
    Goto loop
done:
  StrCpy $R1 $R2 "" $R4
  Pop $R5
  Pop $R4
  Pop $R3
  Pop $R2
  Exch $R1
FunctionEnd
!macroend
!insertmacro StrStr ""
!insertmacro StrStr "un."

Function Trim ; Added by Pelaca
	Exch $R1
	Push $R2
Loop:
	StrCpy $R2 "$R1" 1 -1
	StrCmp "$R2" " " RTrim
	StrCmp "$R2" "$\n" RTrim
	StrCmp "$R2" "$\r" RTrim
	StrCmp "$R2" ";" RTrim
	GoTo Done
RTrim:
	StrCpy $R1 "$R1" -1
	Goto Loop
Done:
	Pop $R2
	Exch $R1
FunctionEnd

Function ConditionalAddToRegisty
  Pop $0
  Pop $1
  StrCmp "$0" "" ConditionalAddToRegisty_EmptyString
    WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" \
    "$1" "$0"
    ;MessageBox MB_OK "Set Registry: '$1' to '$0'"
    DetailPrint "Set install registry entry: '$1' to '$0'"
  ConditionalAddToRegisty_EmptyString:
FunctionEnd

;--------------------------------

!ifdef CPACK_USES_DOWNLOAD
Function DownloadFile
    IfFileExists $INSTDIR\* +2
    CreateDirectory $INSTDIR
    Pop $0

    ; Skip if already downloaded
    IfFileExists $INSTDIR\$0 0 +2
    Return

    StrCpy $1 ""

  try_again:
    NSISdl::download "$1/$0" "$INSTDIR\$0"

    Pop $1
    StrCmp $1 "success" success
    StrCmp $1 "Cancelled" cancel
    MessageBox MB_OK "Download failed: $1"
  cancel:
    Return
  success:
FunctionEnd
!endif

;--------------------------------
; Installation types


;--------------------------------
; Component sections


;--------------------------------
; Define some macro setting for the gui







;--------------------------------
;Pages
  !insertmacro MUI_PAGE_WELCOME

  !insertmacro MUI_PAGE_LICENSE "C:/dev/OBS-studio-webrtc/UI/data/license/gplv2.txt"
  Page custom InstallOptionsPage
  !insertmacro MUI_PAGE_DIRECTORY

  ;Start Menu Folder Page Configuration
  !define MUI_STARTMENUPAGE_REGISTRY_ROOT "SHCTX"
  !define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\obsproject.com\OBSStudio32"
  !define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"
  !insertmacro MUI_PAGE_STARTMENU Application $STARTMENU_FOLDER

  

  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro MUI_PAGE_FINISH

  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English" ;first language is the default language
  !insertmacro MUI_LANGUAGE "Albanian"
  !insertmacro MUI_LANGUAGE "Arabic"
  !insertmacro MUI_LANGUAGE "Basque"
  !insertmacro MUI_LANGUAGE "Belarusian"
  !insertmacro MUI_LANGUAGE "Bosnian"
  !insertmacro MUI_LANGUAGE "Breton"
  !insertmacro MUI_LANGUAGE "Bulgarian"
  !insertmacro MUI_LANGUAGE "Croatian"
  !insertmacro MUI_LANGUAGE "Czech"
  !insertmacro MUI_LANGUAGE "Danish"
  !insertmacro MUI_LANGUAGE "Dutch"
  !insertmacro MUI_LANGUAGE "Estonian"
  !insertmacro MUI_LANGUAGE "Farsi"
  !insertmacro MUI_LANGUAGE "Finnish"
  !insertmacro MUI_LANGUAGE "French"
  !insertmacro MUI_LANGUAGE "German"
  !insertmacro MUI_LANGUAGE "Greek"
  !insertmacro MUI_LANGUAGE "Hebrew"
  !insertmacro MUI_LANGUAGE "Hungarian"
  !insertmacro MUI_LANGUAGE "Icelandic"
  !insertmacro MUI_LANGUAGE "Indonesian"
  !insertmacro MUI_LANGUAGE "Irish"
  !insertmacro MUI_LANGUAGE "Italian"
  !insertmacro MUI_LANGUAGE "Japanese"
  !insertmacro MUI_LANGUAGE "Korean"
  !insertmacro MUI_LANGUAGE "Kurdish"
  !insertmacro MUI_LANGUAGE "Latvian"
  !insertmacro MUI_LANGUAGE "Lithuanian"
  !insertmacro MUI_LANGUAGE "Luxembourgish"
  !insertmacro MUI_LANGUAGE "Macedonian"
  !insertmacro MUI_LANGUAGE "Malay"
  !insertmacro MUI_LANGUAGE "Mongolian"
  !insertmacro MUI_LANGUAGE "Norwegian"
  !insertmacro MUI_LANGUAGE "Polish"
  !insertmacro MUI_LANGUAGE "Portuguese"
  !insertmacro MUI_LANGUAGE "PortugueseBR"
  !insertmacro MUI_LANGUAGE "Romanian"
  !insertmacro MUI_LANGUAGE "Russian"
  !insertmacro MUI_LANGUAGE "Serbian"
  !insertmacro MUI_LANGUAGE "SerbianLatin"
  !insertmacro MUI_LANGUAGE "SimpChinese"
  !insertmacro MUI_LANGUAGE "Slovak"
  !insertmacro MUI_LANGUAGE "Slovenian"
  !insertmacro MUI_LANGUAGE "Spanish"
  !insertmacro MUI_LANGUAGE "Swedish"
  !insertmacro MUI_LANGUAGE "Thai"
  !insertmacro MUI_LANGUAGE "TradChinese"
  !insertmacro MUI_LANGUAGE "Turkish"
  !insertmacro MUI_LANGUAGE "Ukrainian"
  !insertmacro MUI_LANGUAGE "Welsh"


;--------------------------------
;Reserve Files

  ;These files should be inserted before other files in the data block
  ;Keep these lines before any File command
  ;Only for solid compression (by default, solid compression is enabled for BZIP2 and LZMA)

  ReserveFile "NSIS.InstallOptions.ini"
  !insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

;--------------------------------
;Installer Sections

Section "-Core installation"
  ;Use the entire tree produced by the INSTALL target.  Keep the
  ;list of directories here in sync with the RMDir commands below.
  SetOutPath "$INSTDIR"
  
  File /r "${INST_DIR}\*.*"

  ;Store installation folder
  WriteRegStr SHCTX "Software\obsproject.com\OBSStudio32" "" $INSTDIR

  ;Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  Push "DisplayName"
  Push "OBS Studio (32bit)"
  Call ConditionalAddToRegisty
  Push "DisplayVersion"
  Push "1.0.0"
  Call ConditionalAddToRegisty
  Push "Publisher"
  Push "obsproject.com"
  Call ConditionalAddToRegisty
  Push "UninstallString"
  Push "$INSTDIR\Uninstall.exe"
  Call ConditionalAddToRegisty
  Push "NoRepair"
  Push "1"
  Call ConditionalAddToRegisty

  !ifdef CPACK_NSIS_ADD_REMOVE
  ;Create add/remove functionality
  Push "ModifyPath"
  Push "$INSTDIR\AddRemove.exe"
  Call ConditionalAddToRegisty
  !else
  Push "NoModify"
  Push "1"
  Call ConditionalAddToRegisty
  !endif

  ; Optional registration
  Push "DisplayIcon"
  Push "$INSTDIR\"
  Call ConditionalAddToRegisty
  Push "HelpLink"
  Push ""
  Call ConditionalAddToRegisty
  Push "URLInfoAbout"
  Push ""
  Call ConditionalAddToRegisty
  Push "Contact"
  Push ""
  Call ConditionalAddToRegisty
  !insertmacro MUI_INSTALLOPTIONS_READ $INSTALL_DESKTOP "NSIS.InstallOptions.ini" "Field 5" "State"
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application

  ;Create shortcuts
  CreateDirectory "$SMPROGRAMS\$STARTMENU_FOLDER"
  SetOutPath "$INSTDIR\bin\32bit"
  CreateShortCut "$SMPROGRAMS\$STARTMENU_FOLDER\OBS Studio.lnk" "$INSTDIR\bin\32bit\obs32.exe"
  StrCmp "$INSTALL_DESKTOP" "1" 0 +2
    CreateShortCut "$DESKTOP\OBS Studio.lnk" "$INSTDIR\bin\32bit\obs32.exe"


  CreateShortCut "$SMPROGRAMS\$STARTMENU_FOLDER\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

  ;Read a value from an InstallOptions INI file
  !insertmacro MUI_INSTALLOPTIONS_READ $DO_NOT_ADD_TO_PATH "NSIS.InstallOptions.ini" "Field 2" "State"
  !insertmacro MUI_INSTALLOPTIONS_READ $ADD_TO_PATH_ALL_USERS "NSIS.InstallOptions.ini" "Field 3" "State"
  !insertmacro MUI_INSTALLOPTIONS_READ $ADD_TO_PATH_CURRENT_USER "NSIS.InstallOptions.ini" "Field 4" "State"

  ; Write special uninstall registry entries
  Push "StartMenu"
  Push "$STARTMENU_FOLDER"
  Call ConditionalAddToRegisty
  Push "DoNotAddToPath"
  Push "$DO_NOT_ADD_TO_PATH"
  Call ConditionalAddToRegisty
  Push "AddToPathAllUsers"
  Push "$ADD_TO_PATH_ALL_USERS"
  Call ConditionalAddToRegisty
  Push "AddToPathCurrentUser"
  Push "$ADD_TO_PATH_CURRENT_USER"
  Call ConditionalAddToRegisty
  Push "InstallToDesktop"
  Push "$INSTALL_DESKTOP"
  Call ConditionalAddToRegisty

  !insertmacro MUI_STARTMENU_WRITE_END



SectionEnd

Section "-Add to path"
  Push $INSTDIR\bin
  StrCmp "" "ON" 0 doNotAddToPath
  StrCmp $DO_NOT_ADD_TO_PATH "1" doNotAddToPath 0
    Call AddToPath
  doNotAddToPath:
SectionEnd

;--------------------------------
; Create custom pages
Function InstallOptionsPage
  !insertmacro MUI_HEADER_TEXT "Install Options" "Choose options for installing OBS Studio (32bit)"
  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "NSIS.InstallOptions.ini"

FunctionEnd

;--------------------------------
; determine admin versus local install
Function un.onInit

  ClearErrors
  UserInfo::GetName
  IfErrors noLM
  Pop $0
  UserInfo::GetAccountType
  Pop $1
  StrCmp $1 "Admin" 0 +3
    SetShellVarContext all
    ;MessageBox MB_OK 'User "$0" is in the Admin group'
    Goto done
  StrCmp $1 "Power" 0 +3
    SetShellVarContext all
    ;MessageBox MB_OK 'User "$0" is in the Power Users group'
    Goto done

  noLM:
    ;Get installation folder from registry if available

  done:

FunctionEnd

;--- Add/Remove callback functions: ---
!macro SectionList MacroName
  ;This macro used to perform operation on multiple sections.
  ;List all of your components in following manner here.

!macroend

Section -FinishComponents
  ;Removes unselected components and writes component status to registry
  !insertmacro SectionList "FinishSection"

!ifdef CPACK_NSIS_ADD_REMOVE
  ; Get the name of the installer executable
  System::Call 'kernel32::GetModuleFileNameA(i 0, t .R0, i 1024) i r1'
  StrCpy $R3 $R0

  ; Strip off the last 13 characters, to see if we have AddRemove.exe
  StrLen $R1 $R0
  IntOp $R1 $R0 - 13
  StrCpy $R2 $R0 13 $R1
  StrCmp $R2 "AddRemove.exe" addremove_installed

  ; We're not running AddRemove.exe, so install it
  CopyFiles $R3 $INSTDIR\AddRemove.exe

  addremove_installed:
!endif
SectionEnd
;--- End of Add/Remove callback functions ---

;--------------------------------
; Component dependencies
Function .onSelChange
  !insertmacro SectionList MaybeSelectionChanged
FunctionEnd

;--------------------------------
;Uninstaller Section

Section "Uninstall"
  ReadRegStr $START_MENU SHCTX \
   "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "StartMenu"
  ;MessageBox MB_OK "Start menu is in: $START_MENU"
  ReadRegStr $DO_NOT_ADD_TO_PATH SHCTX \
    "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "DoNotAddToPath"
  ReadRegStr $ADD_TO_PATH_ALL_USERS SHCTX \
    "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "AddToPathAllUsers"
  ReadRegStr $ADD_TO_PATH_CURRENT_USER SHCTX \
    "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "AddToPathCurrentUser"
  ;MessageBox MB_OK "Add to path: $DO_NOT_ADD_TO_PATH all users: $ADD_TO_PATH_ALL_USERS"
  ReadRegStr $INSTALL_DESKTOP SHCTX \
    "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "InstallToDesktop"
  ;MessageBox MB_OK "Install to desktop: $INSTALL_DESKTOP "



  ;Remove files we installed.
  ;Keep the list of directories here in sync with the File commands above.
  Delete "$INSTDIR\bin"
  Delete "$INSTDIR\bin\32bit"
  Delete "$INSTDIR\bin\32bit\avcodec-57.dll"
  Delete "$INSTDIR\bin\32bit\avdevice-57.dll"
  Delete "$INSTDIR\bin\32bit\avfilter-6.dll"
  Delete "$INSTDIR\bin\32bit\avformat-57.dll"
  Delete "$INSTDIR\bin\32bit\avutil-55.dll"
  Delete "$INSTDIR\bin\32bit\libcrypto-1_1.dll"
  Delete "$INSTDIR\bin\32bit\libcrypto.lib"
  Delete "$INSTDIR\bin\32bit\libcurl.dll"
  Delete "$INSTDIR\bin\32bit\libEGL.dll"
  Delete "$INSTDIR\bin\32bit\libGLESv2.dll"
  Delete "$INSTDIR\bin\32bit\libobs-d3d11.dll"
  Delete "$INSTDIR\bin\32bit\libobs-opengl.dll"
  Delete "$INSTDIR\bin\32bit\libogg-0.dll"
  Delete "$INSTDIR\bin\32bit\libopus-0.dll"
  Delete "$INSTDIR\bin\32bit\libssl-1_1.dll"
  Delete "$INSTDIR\bin\32bit\libssl.lib"
  Delete "$INSTDIR\bin\32bit\libvorbis-0.dll"
  Delete "$INSTDIR\bin\32bit\libvorbisenc-2.dll"
  Delete "$INSTDIR\bin\32bit\libvorbisfile-3.dll"
  Delete "$INSTDIR\bin\32bit\libvpx-1.dll"
  Delete "$INSTDIR\bin\32bit\libx264-148.dll"
  Delete "$INSTDIR\bin\32bit\lua51.dll"
  Delete "$INSTDIR\bin\32bit\obs-frontend-api.dll"
  Delete "$INSTDIR\bin\32bit\obs-scripting.dll"
  Delete "$INSTDIR\bin\32bit\obs.dll"
  Delete "$INSTDIR\bin\32bit\obs.lib"
  Delete "$INSTDIR\bin\32bit\obs32.exe"
  Delete "$INSTDIR\bin\32bit\obsglad.dll"
  Delete "$INSTDIR\bin\32bit\platforms"
  Delete "$INSTDIR\bin\32bit\platforms\qwindows.dll"
  Delete "$INSTDIR\bin\32bit\Qt5Core.dll"
  Delete "$INSTDIR\bin\32bit\Qt5Gui.dll"
  Delete "$INSTDIR\bin\32bit\Qt5Widgets.dll"
  Delete "$INSTDIR\bin\32bit\styles"
  Delete "$INSTDIR\bin\32bit\styles\qwindowsvistastyle.dll"
  Delete "$INSTDIR\bin\32bit\swresample-2.dll"
  Delete "$INSTDIR\bin\32bit\swscale-4.dll"
  Delete "$INSTDIR\bin\32bit\w32-pthreads.dll"
  Delete "$INSTDIR\bin\32bit\w32-pthreads.lib"
  Delete "$INSTDIR\bin\32bit\webrtc.lib"
  Delete "$INSTDIR\bin\32bit\zlib.dll"
  Delete "$INSTDIR\cmake"
  Delete "$INSTDIR\cmake\LibObs"
  Delete "$INSTDIR\cmake\LibObs\LibObsConfig.cmake"
  Delete "$INSTDIR\cmake\LibObs\LibObsConfigVersion.cmake"
  Delete "$INSTDIR\cmake\LibObs\LibObsTarget-release.cmake"
  Delete "$INSTDIR\cmake\LibObs\LibObsTarget.cmake"
  Delete "$INSTDIR\cmake\w32-pthreads"
  Delete "$INSTDIR\cmake\w32-pthreads\w32-pthreadsConfig.cmake"
  Delete "$INSTDIR\cmake\w32-pthreads\w32-pthreadsConfigVersion.cmake"
  Delete "$INSTDIR\cmake\w32-pthreads\w32-pthreadsTarget-release.cmake"
  Delete "$INSTDIR\cmake\w32-pthreads\w32-pthreadsTarget.cmake"
  Delete "$INSTDIR\data"
  Delete "$INSTDIR\data\libobs"
  Delete "$INSTDIR\data\libobs\bicubic_scale.effect"
  Delete "$INSTDIR\data\libobs\bilinear_lowres_scale.effect"
  Delete "$INSTDIR\data\libobs\default.effect"
  Delete "$INSTDIR\data\libobs\default_rect.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_base.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_blend.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_blend_2x.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_discard.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_discard_2x.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_linear.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_linear_2x.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_yadif.effect"
  Delete "$INSTDIR\data\libobs\deinterlace_yadif_2x.effect"
  Delete "$INSTDIR\data\libobs\format_conversion.effect"
  Delete "$INSTDIR\data\libobs\lanczos_scale.effect"
  Delete "$INSTDIR\data\libobs\opaque.effect"
  Delete "$INSTDIR\data\libobs\premultiplied_alpha.effect"
  Delete "$INSTDIR\data\libobs\solid.effect"
  Delete "$INSTDIR\data\obs-plugins"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ms-MY.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\ta-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\enc-amf-test32.exe"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\enc-amf\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ka-GE.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\lt-LT.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ms-MY.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source\dial.png"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source\hour.png"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source\minute.png"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source\second.png"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source.lua"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\countdown.lua"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\instant-replay.lua"
  Delete "$INSTDIR\data\obs-plugins\frontend-tools\scripts\url-text.py"
  Delete "$INSTDIR\data\obs-plugins\image-source"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ms-MY.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\image-source\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\ffmpeg-mux32.exe"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\blend_add_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\blend_mul_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\blend_sub_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\chroma_key_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\color_correction_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\color_grade_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\color_key_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\crop_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ka-GE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs\black_and_white.png"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs\original.png"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs\posterize.png"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs\red_isolated.png"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\LUTs\teal_lows_orange_highs.png"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\mask_alpha_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\mask_color_filter.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-filters\sharpness.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\ur-PK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-outputs\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-qsv11\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-text\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\fade_to_color_transition.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\fade_transition.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\barndoor-botleft.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\barndoor-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\barndoor-topleft.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\barndoor-v.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\blinds-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\box-botleft.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\box-botright.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\box-topleft.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\box-topright.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\burst.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\checkerboard-small.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\circles.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\clock.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\cloud.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\curtain.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\fan.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\fractal.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\iris.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\linear-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\linear-topleft.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\linear-topright.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\linear-v.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\parallel-zigzag-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\parallel-zigzag-v.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\sinus9.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\spiral.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\square.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\squares.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\stripes.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\strips-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\strips-v.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\watercolor.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\wipes.json"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\zigzag-h.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes\zigzag-v.png"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipe_transition.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\premultiplied.inc"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\slide_transition.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-transitions\swipe_transition.effect"
  Delete "$INSTDIR\data\obs-plugins\obs-vst"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-vst\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ka-GE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\ur-PK.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\obs-x264\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\ur-PK.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\package.json"
  Delete "$INSTDIR\data\obs-plugins\rtmp-services\services.json"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ms-MY.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\text-freetype2\text_default.effect"
  Delete "$INSTDIR\data\obs-plugins\win-capture"
  Delete "$INSTDIR\data\obs-plugins\win-capture\get-graphics-offsets32.exe"
  Delete "$INSTDIR\data\obs-plugins\win-capture\graphics-hook32.dll"
  Delete "$INSTDIR\data\obs-plugins\win-capture\inject-helper32.exe"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-capture\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-decklink\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-dshow\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\hi-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ta-IN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\ur-PK.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-plugins\win-wasapi\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-scripting"
  Delete "$INSTDIR\data\obs-scripting\32bit"
  Delete "$INSTDIR\data\obs-scripting\32bit\obslua.dll"
  Delete "$INSTDIR\data\obs-studio"
  Delete "$INSTDIR\data\obs-studio\license"
  Delete "$INSTDIR\data\obs-studio\license\gplv2.txt"
  Delete "$INSTDIR\data\obs-studio\locale"
  Delete "$INSTDIR\data\obs-studio\locale\af-ZA.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ar-SA.ini"
  Delete "$INSTDIR\data\obs-studio\locale\bg-BG.ini"
  Delete "$INSTDIR\data\obs-studio\locale\bn-BD.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ca-ES.ini"
  Delete "$INSTDIR\data\obs-studio\locale\cs-CZ.ini"
  Delete "$INSTDIR\data\obs-studio\locale\da-DK.ini"
  Delete "$INSTDIR\data\obs-studio\locale\de-DE.ini"
  Delete "$INSTDIR\data\obs-studio\locale\el-GR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\en-US.ini"
  Delete "$INSTDIR\data\obs-studio\locale\es-ES.ini"
  Delete "$INSTDIR\data\obs-studio\locale\et-EE.ini"
  Delete "$INSTDIR\data\obs-studio\locale\eu-ES.ini"
  Delete "$INSTDIR\data\obs-studio\locale\fi-FI.ini"
  Delete "$INSTDIR\data\obs-studio\locale\fr-FR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\gl-ES.ini"
  Delete "$INSTDIR\data\obs-studio\locale\he-IL.ini"
  Delete "$INSTDIR\data\obs-studio\locale\hr-HR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\hu-HU.ini"
  Delete "$INSTDIR\data\obs-studio\locale\it-IT.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ja-JP.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ka-GE.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ko-KR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\lt-LT.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ms-MY.ini"
  Delete "$INSTDIR\data\obs-studio\locale\nb-NO.ini"
  Delete "$INSTDIR\data\obs-studio\locale\nl-NL.ini"
  Delete "$INSTDIR\data\obs-studio\locale\nn-NO.ini"
  Delete "$INSTDIR\data\obs-studio\locale\pl-PL.ini"
  Delete "$INSTDIR\data\obs-studio\locale\pt-BR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\pt-PT.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ro-RO.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ru-RU.ini"
  Delete "$INSTDIR\data\obs-studio\locale\sk-SK.ini"
  Delete "$INSTDIR\data\obs-studio\locale\sl-SI.ini"
  Delete "$INSTDIR\data\obs-studio\locale\sr-CS.ini"
  Delete "$INSTDIR\data\obs-studio\locale\sr-SP.ini"
  Delete "$INSTDIR\data\obs-studio\locale\sv-SE.ini"
  Delete "$INSTDIR\data\obs-studio\locale\ta-IN.ini"
  Delete "$INSTDIR\data\obs-studio\locale\th-TH.ini"
  Delete "$INSTDIR\data\obs-studio\locale\tr-TR.ini"
  Delete "$INSTDIR\data\obs-studio\locale\uk-UA.ini"
  Delete "$INSTDIR\data\obs-studio\locale\vi-VN.ini"
  Delete "$INSTDIR\data\obs-studio\locale\zh-CN.ini"
  Delete "$INSTDIR\data\obs-studio\locale\zh-TW.ini"
  Delete "$INSTDIR\data\obs-studio\locale.ini"
  Delete "$INSTDIR\data\obs-studio\themes"
  Delete "$INSTDIR\data\obs-studio\themes\Acri"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\bot_hook.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\bot_hook2.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_checked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_checked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_checked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_unchecked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_unchecked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\checkbox_unchecked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\cogwheel.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\down_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\minus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\mute.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\plus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_checked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_checked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_checked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_unchecked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_unchecked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\radio_unchecked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\sizegrip.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\top_hook.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\unmute.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\updown.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri\up_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Acri.qss"
  Delete "$INSTDIR\data\obs-studio\themes\Dark"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\cogwheel.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\down_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\minus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\mute.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\plus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\refresh.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\unmute.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\updown.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark\up_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Dark.qss"
  Delete "$INSTDIR\data\obs-studio\themes\Default.qss"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_checked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_checked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_checked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_unchecked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_unchecked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\checkbox_unchecked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\down_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\down_arrow_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\left_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\left_arrow_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_checked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_checked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_checked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_unchecked.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_unchecked_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\radio_unchecked_focus.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\right_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\right_arrow_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\sizegrip.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\up_arrow.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni\up_arrow_disabled.png"
  Delete "$INSTDIR\data\obs-studio\themes\Rachni.qss"
  Delete "$INSTDIR\include"
  Delete "$INSTDIR\include\audio-monitoring"
  Delete "$INSTDIR\include\audio-monitoring\win32"
  Delete "$INSTDIR\include\audio-monitoring\win32\wasapi-output.h"
  Delete "$INSTDIR\include\callback"
  Delete "$INSTDIR\include\callback\calldata.h"
  Delete "$INSTDIR\include\callback\decl.h"
  Delete "$INSTDIR\include\callback\proc.h"
  Delete "$INSTDIR\include\callback\signal.h"
  Delete "$INSTDIR\include\graphics"
  Delete "$INSTDIR\include\graphics\axisang.h"
  Delete "$INSTDIR\include\graphics\bounds.h"
  Delete "$INSTDIR\include\graphics\device-exports.h"
  Delete "$INSTDIR\include\graphics\effect-parser.h"
  Delete "$INSTDIR\include\graphics\effect.h"
  Delete "$INSTDIR\include\graphics\graphics-internal.h"
  Delete "$INSTDIR\include\graphics\graphics.h"
  Delete "$INSTDIR\include\graphics\image-file.h"
  Delete "$INSTDIR\include\graphics\input.h"
  Delete "$INSTDIR\include\graphics\libnsgif"
  Delete "$INSTDIR\include\graphics\libnsgif\libnsgif.h"
  Delete "$INSTDIR\include\graphics\math-defs.h"
  Delete "$INSTDIR\include\graphics\math-extra.h"
  Delete "$INSTDIR\include\graphics\matrix3.h"
  Delete "$INSTDIR\include\graphics\matrix4.h"
  Delete "$INSTDIR\include\graphics\plane.h"
  Delete "$INSTDIR\include\graphics\quat.h"
  Delete "$INSTDIR\include\graphics\shader-parser.h"
  Delete "$INSTDIR\include\graphics\vec2.h"
  Delete "$INSTDIR\include\graphics\vec3.h"
  Delete "$INSTDIR\include\graphics\vec4.h"
  Delete "$INSTDIR\include\media-io"
  Delete "$INSTDIR\include\media-io\audio-io.h"
  Delete "$INSTDIR\include\media-io\audio-math.h"
  Delete "$INSTDIR\include\media-io\audio-resampler.h"
  Delete "$INSTDIR\include\media-io\format-conversion.h"
  Delete "$INSTDIR\include\media-io\frame-rate.h"
  Delete "$INSTDIR\include\media-io\media-io-defs.h"
  Delete "$INSTDIR\include\media-io\media-remux.h"
  Delete "$INSTDIR\include\media-io\video-frame.h"
  Delete "$INSTDIR\include\media-io\video-io.h"
  Delete "$INSTDIR\include\media-io\video-scaler.h"
  Delete "$INSTDIR\include\obs-audio-controls.h"
  Delete "$INSTDIR\include\obs-avc.h"
  Delete "$INSTDIR\include\obs-config.h"
  Delete "$INSTDIR\include\obs-data.h"
  Delete "$INSTDIR\include\obs-defs.h"
  Delete "$INSTDIR\include\obs-encoder.h"
  Delete "$INSTDIR\include\obs-ffmpeg-compat.h"
  Delete "$INSTDIR\include\obs-hotkey.h"
  Delete "$INSTDIR\include\obs-hotkeys.h"
  Delete "$INSTDIR\include\obs-interaction.h"
  Delete "$INSTDIR\include\obs-internal.h"
  Delete "$INSTDIR\include\obs-module.h"
  Delete "$INSTDIR\include\obs-output.h"
  Delete "$INSTDIR\include\obs-properties.h"
  Delete "$INSTDIR\include\obs-scene.h"
  Delete "$INSTDIR\include\obs-service.h"
  Delete "$INSTDIR\include\obs-source.h"
  Delete "$INSTDIR\include\obs-ui.h"
  Delete "$INSTDIR\include\obs.h"
  Delete "$INSTDIR\include\obs.hpp"
  Delete "$INSTDIR\include\obsconfig.h"
  Delete "$INSTDIR\include\util"
  Delete "$INSTDIR\include\util\array-serializer.h"
  Delete "$INSTDIR\include\util\base.h"
  Delete "$INSTDIR\include\util\bmem.h"
  Delete "$INSTDIR\include\util\c99defs.h"
  Delete "$INSTDIR\include\util\cf-lexer.h"
  Delete "$INSTDIR\include\util\cf-parser.h"
  Delete "$INSTDIR\include\util\circlebuf.h"
  Delete "$INSTDIR\include\util\config-file.h"
  Delete "$INSTDIR\include\util\crc32.h"
  Delete "$INSTDIR\include\util\darray.h"
  Delete "$INSTDIR\include\util\dstr.h"
  Delete "$INSTDIR\include\util\file-serializer.h"
  Delete "$INSTDIR\include\util\lexer.h"
  Delete "$INSTDIR\include\util\pipe.h"
  Delete "$INSTDIR\include\util\platform.h"
  Delete "$INSTDIR\include\util\profiler.h"
  Delete "$INSTDIR\include\util\profiler.hpp"
  Delete "$INSTDIR\include\util\serializer.h"
  Delete "$INSTDIR\include\util\text-lookup.h"
  Delete "$INSTDIR\include\util\threading-windows.h"
  Delete "$INSTDIR\include\util\threading.h"
  Delete "$INSTDIR\include\util\utf8.h"
  Delete "$INSTDIR\include\util\util_uint128.h"
  Delete "$INSTDIR\include\util\vc"
  Delete "$INSTDIR\include\util\vc\vc_inttypes.h"
  Delete "$INSTDIR\include\util\vc\vc_stdbool.h"
  Delete "$INSTDIR\include\util\vc\vc_stdint.h"
  Delete "$INSTDIR\include\util\windows"
  Delete "$INSTDIR\include\util\windows\ComPtr.hpp"
  Delete "$INSTDIR\include\util\windows\CoTaskMemPtr.hpp"
  Delete "$INSTDIR\include\util\windows\HRError.hpp"
  Delete "$INSTDIR\include\util\windows\win-registry.h"
  Delete "$INSTDIR\include\util\windows\win-version.h"
  Delete "$INSTDIR\include\util\windows\WinHandle.hpp"
  Delete "$INSTDIR\obs-plugins"
  Delete "$INSTDIR\obs-plugins\32bit"
  Delete "$INSTDIR\obs-plugins\32bit\coreaudio-encoder.dll"
  Delete "$INSTDIR\obs-plugins\32bit\enc-amf.dll"
  Delete "$INSTDIR\obs-plugins\32bit\frontend-tools.dll"
  Delete "$INSTDIR\obs-plugins\32bit\image-source.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-ffmpeg.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-filters.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-outputs.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-qsv11.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-text.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-transitions.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-vst.dll"
  Delete "$INSTDIR\obs-plugins\32bit\obs-x264.dll"
  Delete "$INSTDIR\obs-plugins\32bit\rtmp-services.dll"
  Delete "$INSTDIR\obs-plugins\32bit\text-freetype2.dll"
  Delete "$INSTDIR\obs-plugins\32bit\websocketclient.dll"
  Delete "$INSTDIR\obs-plugins\32bit\win-capture.dll"
  Delete "$INSTDIR\obs-plugins\32bit\win-decklink.dll"
  Delete "$INSTDIR\obs-plugins\32bit\win-dshow.dll"
  Delete "$INSTDIR\obs-plugins\32bit\win-mf.dll"
  Delete "$INSTDIR\obs-plugins\32bit\win-wasapi.dll"

  RMDir "$INSTDIR\bin\32bit\platforms"
  RMDir "$INSTDIR\bin\32bit\styles"
  RMDir "$INSTDIR\bin\32bit"
  RMDir "$INSTDIR\bin"
  RMDir "$INSTDIR\cmake\LibObs"
  RMDir "$INSTDIR\cmake\w32-pthreads"
  RMDir "$INSTDIR\cmake"
  RMDir "$INSTDIR\data\libobs"
  RMDir "$INSTDIR\data\obs-plugins\coreaudio-encoder\locale"
  RMDir "$INSTDIR\data\obs-plugins\coreaudio-encoder"
  RMDir "$INSTDIR\data\obs-plugins\enc-amf\locale"
  RMDir "$INSTDIR\data\obs-plugins\enc-amf"
  RMDir "$INSTDIR\data\obs-plugins\frontend-tools\locale"
  RMDir "$INSTDIR\data\obs-plugins\frontend-tools\scripts\clock-source"
  RMDir "$INSTDIR\data\obs-plugins\frontend-tools\scripts"
  RMDir "$INSTDIR\data\obs-plugins\frontend-tools"
  RMDir "$INSTDIR\data\obs-plugins\image-source\locale"
  RMDir "$INSTDIR\data\obs-plugins\image-source"
  RMDir "$INSTDIR\data\obs-plugins\obs-ffmpeg\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-ffmpeg"
  RMDir "$INSTDIR\data\obs-plugins\obs-filters\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-filters\LUTs"
  RMDir "$INSTDIR\data\obs-plugins\obs-filters"
  RMDir "$INSTDIR\data\obs-plugins\obs-outputs\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-outputs"
  RMDir "$INSTDIR\data\obs-plugins\obs-qsv11\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-qsv11"
  RMDir "$INSTDIR\data\obs-plugins\obs-text\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-text"
  RMDir "$INSTDIR\data\obs-plugins\obs-transitions\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-transitions\luma_wipes"
  RMDir "$INSTDIR\data\obs-plugins\obs-transitions"
  RMDir "$INSTDIR\data\obs-plugins\obs-vst\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-vst"
  RMDir "$INSTDIR\data\obs-plugins\obs-x264\locale"
  RMDir "$INSTDIR\data\obs-plugins\obs-x264"
  RMDir "$INSTDIR\data\obs-plugins\rtmp-services\locale"
  RMDir "$INSTDIR\data\obs-plugins\rtmp-services"
  RMDir "$INSTDIR\data\obs-plugins\text-freetype2\locale"
  RMDir "$INSTDIR\data\obs-plugins\text-freetype2"
  RMDir "$INSTDIR\data\obs-plugins\win-capture\locale"
  RMDir "$INSTDIR\data\obs-plugins\win-capture"
  RMDir "$INSTDIR\data\obs-plugins\win-decklink\locale"
  RMDir "$INSTDIR\data\obs-plugins\win-decklink"
  RMDir "$INSTDIR\data\obs-plugins\win-dshow\locale"
  RMDir "$INSTDIR\data\obs-plugins\win-dshow"
  RMDir "$INSTDIR\data\obs-plugins\win-wasapi\locale"
  RMDir "$INSTDIR\data\obs-plugins\win-wasapi"
  RMDir "$INSTDIR\data\obs-plugins"
  RMDir "$INSTDIR\data\obs-scripting\32bit"
  RMDir "$INSTDIR\data\obs-scripting"
  RMDir "$INSTDIR\data\obs-studio\license"
  RMDir "$INSTDIR\data\obs-studio\locale"
  RMDir "$INSTDIR\data\obs-studio\themes\Acri"
  RMDir "$INSTDIR\data\obs-studio\themes\Dark"
  RMDir "$INSTDIR\data\obs-studio\themes\Rachni"
  RMDir "$INSTDIR\data\obs-studio\themes"
  RMDir "$INSTDIR\data\obs-studio"
  RMDir "$INSTDIR\data"
  RMDir "$INSTDIR\include\audio-monitoring\win32"
  RMDir "$INSTDIR\include\audio-monitoring"
  RMDir "$INSTDIR\include\callback"
  RMDir "$INSTDIR\include\graphics\libnsgif"
  RMDir "$INSTDIR\include\graphics"
  RMDir "$INSTDIR\include\media-io"
  RMDir "$INSTDIR\include\util\vc"
  RMDir "$INSTDIR\include\util\windows"
  RMDir "$INSTDIR\include\util"
  RMDir "$INSTDIR\include"
  RMDir "$INSTDIR\obs-plugins\32bit"
  RMDir "$INSTDIR\obs-plugins"


!ifdef CPACK_NSIS_ADD_REMOVE
  ;Remove the add/remove program
  Delete "$INSTDIR\AddRemove.exe"
!endif

  ;Remove the uninstaller itself.
  Delete "$INSTDIR\Uninstall.exe"
  DeleteRegKey SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32"

  ;Remove the installation directory if it is empty.
  RMDir "$INSTDIR"

  ; Remove the registry entries.
  DeleteRegKey SHCTX "Software\obsproject.com\OBSStudio32"

  ; Removes all optional components
  !insertmacro SectionList "RemoveSection_CPack"

  !insertmacro MUI_STARTMENU_GETFOLDER Application $MUI_TEMP

  Delete "$SMPROGRAMS\$MUI_TEMP\Uninstall.lnk"
  Delete "$SMPROGRAMS\$MUI_TEMP\OBS Studio.lnk"
  StrCmp "$INSTALL_DESKTOP" "1" 0 +2
    Delete "$DESKTOP\OBS Studio.lnk"



  ;Delete empty start menu parent directories
  StrCpy $MUI_TEMP "$SMPROGRAMS\$MUI_TEMP"

  startMenuDeleteLoop:
    ClearErrors
    RMDir $MUI_TEMP
    GetFullPathName $MUI_TEMP "$MUI_TEMP\.."

    IfErrors startMenuDeleteLoopDone

    StrCmp "$MUI_TEMP" "$SMPROGRAMS" startMenuDeleteLoopDone startMenuDeleteLoop
  startMenuDeleteLoopDone:

  ; If the user changed the shortcut, then untinstall may not work. This should
  ; try to fix it.
  StrCpy $MUI_TEMP "$START_MENU"
  Delete "$SMPROGRAMS\$MUI_TEMP\Uninstall.lnk"


  ;Delete empty start menu parent directories
  StrCpy $MUI_TEMP "$SMPROGRAMS\$MUI_TEMP"

  secondStartMenuDeleteLoop:
    ClearErrors
    RMDir $MUI_TEMP
    GetFullPathName $MUI_TEMP "$MUI_TEMP\.."

    IfErrors secondStartMenuDeleteLoopDone

    StrCmp "$MUI_TEMP" "$SMPROGRAMS" secondStartMenuDeleteLoopDone secondStartMenuDeleteLoop
  secondStartMenuDeleteLoopDone:

  DeleteRegKey /ifempty SHCTX "Software\obsproject.com\OBSStudio32"

  Push $INSTDIR\bin
  StrCmp $DO_NOT_ADD_TO_PATH_ "1" doNotRemoveFromPath 0
    Call un.RemoveFromPath
  doNotRemoveFromPath:
SectionEnd

;--------------------------------
; determine admin versus local install
; Is install for "AllUsers" or "JustMe"?
; Default to "JustMe" - set to "AllUsers" if admin or on Win9x
; This function is used for the very first "custom page" of the installer.
; This custom page does not show up visibly, but it executes prior to the
; first visible page and sets up $INSTDIR properly...
; Choose different default installation folder based on SV_ALLUSERS...
; "Program Files" for AllUsers, "My Documents" for JustMe...

Function .onInit
  StrCmp "" "ON" 0 inst

  ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\OBSStudio32" "UninstallString"
  StrCmp $0 "" inst

  MessageBox MB_YESNOCANCEL|MB_ICONEXCLAMATION \
  "OBS Studio (32bit) is already installed. $\n$\nDo you want to uninstall the old version before installing the new one?" \
  /SD IDYES IDYES uninst IDNO inst
  Abort

;Run the uninstaller
uninst:
  ClearErrors
  StrLen $2 "\Uninstall.exe"
  StrCpy $3 $0 -$2 # remove "\Uninstall.exe" from UninstallString to get path
  ExecWait '"$0" /S _?=$3' ;Do not copy the uninstaller to a temp file

  IfErrors uninst_failed inst
uninst_failed:
  MessageBox MB_OK|MB_ICONSTOP "Uninstall failed."
  Abort


inst:
  ; Reads components status for registry
  !insertmacro SectionList "InitSection"

  ; check to see if /D has been used to change
  ; the install directory by comparing it to the
  ; install directory that is expected to be the
  ; default
  StrCpy $IS_DEFAULT_INSTALLDIR 0
  StrCmp "$INSTDIR" "$PROGRAMFILES\OBS Studio (32bit)" 0 +2
    StrCpy $IS_DEFAULT_INSTALLDIR 1

  StrCpy $SV_ALLUSERS "JustMe"
  ; if default install dir then change the default
  ; if it is installed for JustMe
  StrCmp "$IS_DEFAULT_INSTALLDIR" "1" 0 +2
    StrCpy $INSTDIR "$DOCUMENTS\OBS Studio (32bit)"

  ClearErrors
  UserInfo::GetName
  IfErrors noLM
  Pop $0
  UserInfo::GetAccountType
  Pop $1
  StrCmp $1 "Admin" 0 +4
    SetShellVarContext all
    ;MessageBox MB_OK 'User "$0" is in the Admin group'
    StrCpy $SV_ALLUSERS "AllUsers"
    Goto done
  StrCmp $1 "Power" 0 +4
    SetShellVarContext all
    ;MessageBox MB_OK 'User "$0" is in the Power Users group'
    StrCpy $SV_ALLUSERS "AllUsers"
    Goto done

  noLM:
    StrCpy $SV_ALLUSERS "AllUsers"
    ;Get installation folder from registry if available

  done:
  StrCmp $SV_ALLUSERS "AllUsers" 0 +3
    StrCmp "$IS_DEFAULT_INSTALLDIR" "1" 0 +2
      StrCpy $INSTDIR "$PROGRAMFILES\OBS Studio (32bit)"

  StrCmp "" "ON" 0 noOptionsPage
    !insertmacro MUI_INSTALLOPTIONS_EXTRACT "NSIS.InstallOptions.ini"

  noOptionsPage:
FunctionEnd
