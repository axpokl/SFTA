﻿
;  Copyright
; 	Copyright 2018 Danysys. <danysys.com>
;  Copyright
; 
;  Information
; 	Author(s)......: Danyfirex & Dany3j
; 	Description....: Set Windows 8/10 File Type Association
; 	Version........: 1.1.0
;  Information
;
;  Resources & Credits
;  https://bbs.pediy.com/thread-213954.htm
;  Resources & Credits


EnableExplicit


Global g_Debug=#False

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Registry Management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#CHAR_SIZE = SizeOf(Character)
#KEY_WOW64_64KEY = $0100
#KEY_WOW64_32KEY = $0200

Procedure.s ExpandString(iString.s)
  ; Expands environment variables in string
  Protected r.s, size.i
  
  size = ExpandEnvironmentStrings_(iString, 0, 0)
  r = Space(size)
  ExpandEnvironmentStrings_(iString, @r, size)
  ProcedureReturn r
EndProcedure

Procedure.i RegRoot(iKey.s)
  ; Returns the root integer value
  ; HKCR, CKCC, HKLM, HKU, HKCC
  Protected pos.i, temp.s, r.i
  
  pos = FindString(iKey, "\")
  If Not pos
    ProcedureReturn
  EndIf
  temp = LCase(Left(iKey, pos - 1))
  Select temp
    Case "hkcr", "hkey_classes_root"
      r = #HKEY_CLASSES_ROOT
    Case "hkcu", "hkey_current_user"
      r = #HKEY_CURRENT_USER
    Case "hklm", "hkey_local_machine"
      r = #HKEY_LOCAL_MACHINE
    Case "hku", "hkey_users"
      r = #HKEY_USERS
    Case "hkcc", "hkey_current_config"
      r = #HKEY_CURRENT_CONFIG
    Default
      ProcedureReturn r
  EndSelect
  ProcedureReturn r
EndProcedure

Procedure.s RegSub(iKey.s)
  ; Returns sub key
  Protected r.s, pos.i
  
  pos = FindString(iKey, "\")
  If Not pos
    ProcedureReturn
  EndIf
  r = Mid(iKey, pos + 1)
  ProcedureReturn r
EndProcedure

Procedure RegWrite(iKey.s, iName.s, iValue.s, iType.i, iForceBit = 0)
  ; Sets registry item to value
  ; iForceBit: 32 or 64 returns 32 or 64 bit registry on a 64 bit system
  Protected h.i, rootKey.i, subKey.s, v.i, datSize.i, *dat, hex.s, oct.i, i.i
  Protected *src, c.c, pos.i
  
  rootKey = RegRoot(iKey)
  subKey = RegSub(iKey)
  If iForceBit = 32
    iForceBit = #KEY_WOW64_32KEY
  ElseIf iForceBit = 64
    iForceBit = #KEY_WOW64_64KEY
  EndIf
  If RegCreateKeyEx_(rootKey, subKey, 0, 0, 0, #KEY_WRITE | iForceBit, 0, @h, 0) = #ERROR_SUCCESS
    ;If RegOpenKeyEx_(rootKey, subKey, 0, #KEY_WRITE | iForceBit, @h) = #ERROR_SUCCESS
    Select iType
      Case #REG_SZ, #REG_EXPAND_SZ
        RegSetValueEx_(h, iName, 0, iType, @iValue, StringByteLength(iValue))
      Case #REG_DWORD
        v = Val(iValue)
        RegSetValueEx_(h, iName, 0, iType, @v, 4)
      Case #REG_QWORD
        v = Val(iValue)
        RegSetValueEx_(h, iName, 0, iType, @v, 8)        
      Case #REG_BINARY
        datSize = Len(iValue) / 2
        *dat = AllocateMemory(datSize)
        For i = 0 To datSize - 1
          hex = "$" + Mid(iValue, (i * 2) + 1, 2)
          oct = Val(hex)
          PokeB(*dat + i, oct)
        Next
        RegSetValueEx_(h, iName, 0, iType, *dat, datSize)
        FreeMemory(*dat)
      Case #REG_MULTI_SZ
        datSize = StringByteLength(iValue) + #CHAR_SIZE
        *dat = AllocateMemory(datSize)
        *src = @iValue
        For i = 0 To (datSize - #CHAR_SIZE) Step #CHAR_SIZE
          c = PeekC(*src + i)
          If c <> #LF
            If c = #CR
              PokeC(*dat + pos, 0)
            Else
              PokeC(*dat + pos, c)  
            EndIf
            pos + #CHAR_SIZE
          EndIf 
        Next
        PokeC(*dat + pos, 0)
        RegSetValueEx_(h, iName, 0, iType, *dat, pos)
        FreeMemory(*dat)
    EndSelect
    RegCloseKey_(h)
  EndIf
EndProcedure

Procedure.s RegRead(iKey.s, iValue.s, iForceBit = 0)
  ; Returns registry value
  Protected h.i, rootKey.i, subkey.s, type.i, *dat, datSize.i
  Protected temp.s, pos.i, size.i, i.i, b.i, c.c, r.s = ""
  
  rootKey = RegRoot(iKey)
  subKey = RegSub(iKey)
  If iForceBit = 32
    iForceBit = #KEY_WOW64_32KEY
  ElseIf iForceBit = 64
    iForceBit = #KEY_WOW64_64KEY
  EndIf
  If RegOpenKeyEx_(rootKey, subKey, 0, #KEY_READ | iForceBit, @h) = #ERROR_SUCCESS
    If RegQueryValueEx_(h, iValue, 0, @type, 0, @datSize) = #ERROR_SUCCESS
      ;Debug datSize
      If datSize = 0
        ProcedureReturn r
      EndIf
      *dat = AllocateMemory(datSize)
      RegQueryValueEx_(h, iValue, 0, @type, *dat, @datSize)
      Select type
        Case #REG_SZ
          r = PeekS(*dat)
          ;Debug StringByteLength(r) + #CHAR_SIZE
        Case #REG_EXPAND_SZ
          r = PeekS(*dat)
          r = ExpandString(r)
        Case #REG_DWORD
          r = Str(PeekL(*dat))
        Case #REG_QWORD
          r = Str(PeekQ(*dat))
        Case #REG_BINARY
          For i = 0 To datSize - 1
            b = PeekB(*dat + i) & $FF ;make unsigned
            r + RSet(Hex(b), 2, "0")
          Next
        Case #REG_MULTI_SZ
          ;charLength = (datSize - #CHAR_SIZE) / #CHAR_SIZE
          pos = 0
          For i = 0 To (datSize - #CHAR_SIZE) Step #CHAR_SIZE
            c = PeekC(*dat + i)
            If c = 0
              If r <> ""
                r + #CRLF$
              EndIf
              temp = PeekS(*dat + pos, (i - pos))
              r + temp
              pos = i + #CHAR_SIZE
            EndIf
          Next          
      EndSelect
      FreeMemory(*dat)
    EndIf  
    RegCloseKey_(h)
  EndIf
  ProcedureReturn r
EndProcedure

;Original from jaPBe IncludesPack _ change for PB4 by ts-soft
Procedure Reg_SetValue(topKey, sKeyName.s, sValueName.s, vValue.s, lType, ComputerName.s = "")
  Protected lpData.s=Space(255)
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l, lpcbData, lValue.l, ergebnis.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    lpcbData = 255
    
    Select lType
      Case #REG_SZ
        GetHandle = RegSetValueEx_(hKey, sValueName, 0, #REG_SZ, @vValue, Len(vValue) + 1)
      Case #REG_DWORD
        lValue = Val(vValue)
        GetHandle = RegSetValueEx_(hKey, sValueName, 0, #REG_DWORD, @lValue, 4)
    EndSelect
    
    RegCloseKey_(hKey)
    ergebnis = 1
    ProcedureReturn ergebnis
  Else
    MessageRequester("Fehler", "Ein Fehler ist aufgetreten", 0)
    RegCloseKey_(hKey)
    ergebnis = 0
    ProcedureReturn ergebnis
  EndIf
EndProcedure

Procedure.s Reg_GetValue(topKey, sKeyName.s, sValueName.s, ComputerName.s = "")
  Protected lpData.s=Space(255), GetValue.s
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l, lpcbData.l, lType.l, lpType.l
  Protected lpDataDWORD.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    lpcbData = 255
    
    
    GetHandle = RegQueryValueEx_(hKey, sValueName, 0, @lType, @lpData, @lpcbData)
    
    If GetHandle = #ERROR_SUCCESS
      Select lType
        Case #REG_SZ
          GetHandle = RegQueryValueEx_(hKey, sValueName, 0, @lType, @lpData, @lpcbData)
          
          If GetHandle = 0
            GetValue = Left(lpData, lpcbData - 1)
          Else
            GetValue = ""
          EndIf
          
        Case #REG_DWORD
          GetHandle = RegQueryValueEx_(hKey, sValueName, 0, @lpType, @lpDataDWORD, @lpcbData)
          
          If GetHandle = 0
            GetValue = Str(lpDataDWORD)
          Else
            GetValue = "0"
          EndIf
          
      EndSelect
    EndIf
  EndIf
  RegCloseKey_(hKey)
  ProcedureReturn GetValue
EndProcedure

Procedure.s Reg_ListSubKey(topKey, sKeyName.s, Index, ComputerName.s = "")
  Protected lpName.s=Space(255), ListSubKey.s
  Protected lpftLastWriteTime.FILETIME
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l
  Protected lpcbName.l = 255
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    
    GetHandle = RegEnumKeyEx_(hKey, Index, @lpName, @lpcbName, 0, 0, 0, @lpftLastWriteTime)
    
    If GetHandle = #ERROR_SUCCESS
      ListSubKey.s = Left(lpName, lpcbName)
    Else
      ListSubKey.s = ""
    EndIf
  EndIf
  RegCloseKey_(hKey)
  ProcedureReturn ListSubKey
EndProcedure

Procedure Reg_DeleteValue(topKey, sKeyName.s, sValueName.s, ComputerName.s = "")
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l, DeleteValue.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    GetHandle = RegDeleteValue_(hKey, @sValueName)
    If GetHandle = #ERROR_SUCCESS
      DeleteValue = #True
    Else
      DeleteValue = #False
    EndIf
  EndIf
  RegCloseKey_(hKey)
  ProcedureReturn DeleteValue
EndProcedure

Procedure Reg_CreateKey(topKey, sKeyName.s, ComputerName.s = "")
  Protected lpSecurityAttributes.SECURITY_ATTRIBUTES
  Protected GetHandle.l, hNewKey.l, lReturnCode.l, lhRemoteRegistry.l, CreateKey.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegCreateKeyEx_(topKey, sKeyName, 0, 0, #REG_OPTION_NON_VOLATILE, #KEY_ALL_ACCESS, @lpSecurityAttributes, @hNewKey, @GetHandle)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegCreateKeyEx_(lhRemoteRegistry, sKeyName, 0, 0, #REG_OPTION_NON_VOLATILE, #KEY_ALL_ACCESS, @lpSecurityAttributes, @hNewKey, @GetHandle)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    GetHandle = RegCloseKey_(hNewKey)
    CreateKey = #True
  Else
    CreateKey = #False
  EndIf
  ProcedureReturn CreateKey
EndProcedure

Procedure Reg_DeleteKey(topKey, sKeyName.s, ComputerName.s = "")
  Protected GetHandle.l, lReturnCode.l, lhRemoteRegistry.l, DeleteKey.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegDeleteKey_(topKey, @sKeyName)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegDeleteKey_(lhRemoteRegistry, @sKeyName)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    DeleteKey = #True
  Else
    DeleteKey = #False
  EndIf
  ProcedureReturn DeleteKey
EndProcedure

Procedure.s Reg_ListSubValue(topKey, sKeyName.s, Index, ComputerName.s = "")
  Protected lpName.s=Space(255), ListSubValue.s
  Protected lpftLastWriteTime.FILETIME
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l
  Protected lpcbName.l = 255
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    
    GetHandle = RegEnumValue_(hKey, Index, @lpName, @lpcbName, 0, 0, 0, 0)
    
    If GetHandle = #ERROR_SUCCESS
      ListSubValue = Left(lpName, lpcbName)
    Else
      ListSubValue = ""
    EndIf
    RegCloseKey_(hKey)
  EndIf
  ProcedureReturn ListSubValue
EndProcedure

Procedure Reg_KeyExists(topKey, sKeyName.s, ComputerName.s = "")
  Protected GetHandle.l, hKey.l, lReturnCode.l, lhRemoteRegistry.l, KeyExists.l
  
  If Left(sKeyName, 1) = "\"
    sKeyName = Right(sKeyName, Len(sKeyName) - 1)
  EndIf
  
  If ComputerName = ""
    GetHandle = RegOpenKeyEx_(topKey, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  Else
    lReturnCode = RegConnectRegistry_(ComputerName, topKey, @lhRemoteRegistry)
    GetHandle = RegOpenKeyEx_(lhRemoteRegistry, sKeyName, 0, #KEY_ALL_ACCESS, @hKey)
  EndIf
  
  If GetHandle = #ERROR_SUCCESS
    KeyExists = #True
  Else
    KeyExists = #False
  EndIf
  ProcedureReturn KeyExists
EndProcedure

Procedure Reg_DeleteKeyWithAllSub(topKey, sKeyName.s, ComputerName.s = "")
  Protected i.l
  Protected a$, b$
  Repeat
    b$ = a$
    a$ = Reg_ListSubKey(topKey,sKeyName,0,"")
    If a$ <> ""
      Reg_DeleteKeyWithAllSub(topKey,sKeyName+"\"+a$,"")
    EndIf
  Until a$ = b$
  Reg_DeleteKey(topKey, sKeyName, ComputerName)
EndProcedure

Procedure Reg_CreateKeyValue(topKey, sKeyName.s, sValueName.s, vValue.s, lType, ComputerName.s = "")
  Reg_CreateKey(topKey,sKeyName,ComputerName)
  ProcedureReturn Reg_SetValue(topKey,sKeyName,sValueName,vValue,lType,ComputerName)
EndProcedure

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Registry Management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interface ApllicationAssociationRegistration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Enumeration  ASSOCIATIONLEVEL 
  #AL_MACHINE
  #AL_EFFECTIVE
  #AL_USER
EndEnumeration

Enumeration ASSOCIATIONTYPE
  #AT_FILEEXTENSION
  #AT_URLPROTOCOL
  #AT_STARTMENUCLIENT
  #AT_MIMETYPE
EndEnumeration

;Interface Information
DataSection 
  CLSID_ApplicationAssociationRegistration:
  Data.i $591209c7
  Data.w $767b
  Data.w $42b2
  Data.b $9f,$ba,$44,$ee,$46,$15,$f2,$c7
  IID_IApplicationAssociationRegistrationInternalW10_1709:
  Data.i $14EBCC88
  Data.w $2831
  Data.w $4FC8
  Data.b $A5,$DF,$9F,$36,$A8,$1D,$B1,$2C
  IID_IApplicationAssociationRegistrationInternalW10_1511: ;Thanks to Mehdi
  Data.i $229D59E2
  Data.w $F94A
  Data.w $402E
  Data.b $9A,$9F,$3B,$84,$A1,$AC,$ED,$77
  IID_IApplicationAssociationRegistrationInternalW8_1_63:
  Data.i $C7225171
  Data.w $B9A7
  Data.w $4CF7
  Data.b $86,$1F,$85,$AB,$7B,$A3,$C5,$B2
EndDataSection

Interface IApplicationAssociationRegistrationInternal Extends IUnknown
  ClearUserAssociations()
  SetProgIdAsDefault(*pszAppRegistryName,*pszExtension,atQueryType.i)
  SetAppAsDefault()
  SetAppAsDefaultAll()
  QueryAppIsDefault()
  QueryAppIsDefaultAll()
  QueryCurrentDefault(*pszQueryIn,atQueryType.i,alQueryLevel.i,*pszAssociation)
EndInterface

; ;Interfaca Methods
; Interface IApplicationAssociationRegistrationInternalW10_1709 Extends IUnknown
;   ClearUserAssociations()
;   SetProgIdAsDefault(*pszAppRegistryName,*pszExtension,atQueryType.i)
;   SetAppAsDefault()
;   SetAppAsDefaultAll()
;   QueryAppIsDefault()
;   QueryAppIsDefaultAll()
;   QueryCurrentDefault(*pszQueryIn,atQueryType.i,alQueryLevel.i,*pszAssociation)
; EndInterface
; 
; ;Interfaca Methods
; Interface IApplicationAssociationRegistrationInternalW8_1_63 Extends IUnknown
;   ClearUserAssociations()
;   SetProgIdAsDefault(*pszAppRegistryName,*pszExtension,atQueryType.i)
;   SetAppAsDefault()
;   SetAppAsDefaultAll()
;   QueryAppIsDefault()
;   QueryAppIsDefaultAll()
;   QueryCurrentDefault(*pszQueryIn,atQueryType.i,alQueryLevel.i,*pszAssociation)
; EndInterface
; 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Interface ApllicationAssociationRegistration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Debug Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Procedure EnableDisableDebug()
  Protected iNumberOfParameters.i = CountProgramParameters()
  Protected i
  g_Debug=#False
  For i=0 To iNumberOfParameters.i-1
    If  ProgramParameter(i)="-d" Or ProgramParameter(i)="--debug"
      g_Debug=#True
      Break
    EndIf  
  Next
EndProcedure

Procedure DebugPrint(Message.s)
  If  g_Debug 
    PrintN(FormatDate("[%yyyy.%mm.%dd %hh:%ii:%ss] ", Date()) + Message.s)
  EndIf
EndProcedure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Debug Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;OS Information Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Procedure.s GetWindowsOS()
  Protected WindowsOs.s=""
  DebugPrint("OSVersion = " + Str(OSVersion()))
  Select OSVersion()
    Case #PB_OS_Windows_XP
      WindowsOs.s="Windows XP"
    Case  #PB_OS_Windows_Server_2003
      WindowsOs.s="Windows Server 2003"
    Case #PB_OS_Windows_Vista
      WindowsOs.s="Windows Vista"
    Case #PB_OS_Windows_Server_2008
      WindowsOs.s="Windows Server 2008"
    Case #PB_OS_Windows_7
      WindowsOs.s="Windows 7"
    Case #PB_OS_Windows_Server_2008_R2
      WindowsOs.s="Windows Server 2008 R2"
    Case #PB_OS_Windows_8
      WindowsOs.s="Windows 8"
    Case #PB_OS_Windows_Server_2012
      WindowsOs.s="Windows Server 2012"
    Case #PB_OS_Windows_8_1
      WindowsOs.s="Windows 8 1"
    Case #PB_OS_Windows_Server_2012_R2
      WindowsOs.s="Windows Server 2012 R2"
    Case #PB_OS_Windows_10
      WindowsOs.s="Windows 10"
    Default
      WindowsOs.s="Unkown"
  EndSelect
  ProcedureReturn WindowsOs.s
EndProcedure

Procedure.s GetWindowsReleaseID()
  ProcedureReturn RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "ReleaseId")
EndProcedure

Procedure.s GetWindowsProductName()
  ProcedureReturn RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "ProductName")
EndProcedure

Procedure.s GetWindowsBuild()
  ProcedureReturn RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentBuild")
EndProcedure

Procedure.i IsWindows8_1()
  ProcedureReturn Bool(OSVersion()=#PB_OS_Windows_8_1)
EndProcedure

Procedure.i IsWindows10()
  ProcedureReturn Bool(OSVersion()=#PB_OS_Windows_10)
EndProcedure


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;OS Information Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Utils Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Procedure.s QuoteString(String.s)
  ProcedureReturn Chr(34) + String.s + Chr(34)
EndProcedure

Procedure.i FileExist(FilePath.s)
  Protected Result.q = FileSize(FilePath.s)
  Protected Extension.s = GetExtensionPart(FilePath.s)
  ProcedureReturn Bool(Result.q>0 And Extension.s="exe")
EndProcedure

Procedure.s CreateApplicationID(FilePath.s)
  Protected ApplicationID.s=""
  If  Not  FileExist(FilePath.s) 
    DebugPrint("ERROR Unable to find " + QuoteString(FilePath.s))
    PrintN("Error File not Found " + QuoteString(FilePath.s))
    ProcedureReturn  ApplicationID.s
  EndIf
  Protected ApplicationName.s=GetFilePart(FilePath.s,#PB_FileSystem_NoExtension)
  ApplicationID.s="SFTA." + ApplicationName.s + ".Application"
  ProcedureReturn  ApplicationID.s
EndProcedure

Procedure.i RunWait(FilePath.s,Parameter.s="",CurrentDir.s="",Flag.i=#PB_Program_Open | #PB_Program_Wait)
  Protected Program=RunProgram(FilePath.s,Parameter.s,CurrentDir.s,Flag.i)
  Protected ExitCode=ProgramExitCode(Program)
  ProcedureReturn ExitCode
EndProcedure

Procedure.i RunCmdCommand(Parameter.s="",CurrentDir.s="")
  Protected CmdPath.s= GetEnvironmentVariable("ComSpec")
  Protected ExitCode=RunWait(CmdPath.s,Parameter.s,CurrentDir.s,#PB_Program_Open | #PB_Program_Wait|#PB_Program_Hide)
  ProcedureReturn ExitCode
EndProcedure


Procedure.i IsAdmin()
  ProcedureReturn IsUserAdmin_()
EndProcedure

Procedure.i IsValidParameter(Parameter.s,ValidParameters.s)
  Define.i isValid,k
  isValid=0
  For k = 1 To CountString(ValidParameters.s, "|")+1
    If  StringField(ValidParameters.s, k, "|")=Parameter.s
      isValid=1
    EndIf
  Next
  ProcedureReturn isValid
EndProcedure

Procedure CheckValidOS()
  If   OSVersion()=#PB_OS_Windows_10  Or  OSVersion()=#PB_OS_Windows_8_1
    ;Its OK
  Else
    PrintN("Error. It is not a Windows 8/10 OS")
    End 2
  EndIf
EndProcedure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Utils Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SFTA Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Procedure PrintHelp()
  PrintN("##################################")
  PrintN("##   __                         ##")
  PrintN("##   |  \  _   _      _     _   ##")
  PrintN("##   |__/ (_| | ) \/ _) \/ _)   ##")
  PrintN("##                /     /       ##")
  PrintN("##     © 2019 Danysys.com       ##")
  PrintN("##        SFTA v.1.1.0          ##")
  PrintN("##################################")
  PrintN("")
  PrintN("OPTIONS:")
  PrintN("")
  PrintN("-h, --help        Show Help")
  ;PrintN("-l, --list        Show All Application Program Id")
  PrintN("-g, --get         Show Default Application Program Id for an Extension")
  PrintN("      Parameters: [.Extension]")
  PrintN("-r, --reg         Register Application Program Id for an Extension and Set File Type Association")
  PrintN("      Parameters: [ApplicationFullPath] [.Extension] [ProgramId-Optional]")
  PrintN("-u, --unreg       Unregister Application Program Id")
  PrintN("      Parameters: [ApplicationFullPath|Program Id]")
  PrintN("-d, --debug       Show Debug Information")
  PrintN("")
  PrintN("Usage:")
  PrintN("")
  PrintN("   Get Current Application Program Id")
  PrintN(~"   SFTA.exe --get \".txt\"")
  PrintN("")
  PrintN("   Set File Type Association")
  PrintN(~"   SFTA.exe \"My.Program.Id\" \".txt\"")
  PrintN("")
  PrintN("   Register Application + Set File Type Association")
  PrintN(~"   SFTA.exe --reg \"C:\\SumatraPDF.exe\" \".PDF\"")
  PrintN(~"   SFTA.exe --reg \"C:\\SumatraPDF.exe\" \".PDF\" \"CustomProgramId\"")
  PrintN("")
  PrintN("   Unregister Application")
  PrintN(~"   SFTA.exe --unreg \"C:\\SumatraPDF.exe\"")
  PrintN(~"   SFTA.exe --unreg \"CustomProgramId\"")
  PrintN("")
  
  
EndProcedure

Procedure ShowWindowsInformation()
  PrintN("Windows Version: " + GetWindowsOS())
  PrintN("Windows ReleaseId: " + GetWindowsReleaseID())
  PrintN("Windows Build: " + GetWindowsBuild())
  PrintN("Windows ProductName: " + GetWindowsProductName())
EndProcedure


Procedure ListProgramIDs()
  PrintN("ListProgramIDs")
EndProcedure

Procedure GetFTA(Extension.s)
  Define result.l=-1
  CoInitialize_(#Null)
  Protected oARI.IApplicationAssociationRegistrationInternal 
  
  If  IsWindows8_1() 
    DebugPrint("Is Windows 8.1")
    result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW8_1_63,@oARI) 
    If  result= #S_OK 
      DebugPrint("Created Interface W8_1_63")
    EndIf 
  EndIf
  
  If  IsWindows10() 
    DebugPrint("Is Windows 10")
    result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW10_1709,@oARI) 
    If  result= #S_OK 
      DebugPrint("Created Interface W10_1709")
    EndIf 
    
    If  result<> #S_OK 
      result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW10_1511,@oARI) 
      If  result= #S_OK 
        DebugPrint("Created Interface W10_1511")
      EndIf 
    EndIf 
  EndIf 
  
  If result = #S_OK
    DebugPrint("OK AssociationRegistration Instance")
    Define *pAssociatedApp  = AllocateMemory(1024) 
    result=oARI\QueryCurrentDefault(@Extension.s,#AT_FILEEXTENSION,#AL_EFFECTIVE,@*pAssociatedApp)
    DebugPrint("AssociationRegistration Get Return = " + Str(result))
    Define AssociatedApp.s=PeekS(*pAssociatedApp)
    If  AssociatedApp=""
      AssociatedApp="Extension Has Not Associated Application"
    EndIf 
    PrintN(AssociatedApp)
    CoUninitialize_()
    End 0
  EndIf 
  DebugPrint("FAIL AssociationRegistration Instance")
  PrintN("Error. Unable To Query Associated Application")
  End 1
EndProcedure


Procedure SetFTA(ProgramId.s,Extension.s)
  Define result.l
  CoInitialize_(#Null)
  Protected oARI.IApplicationAssociationRegistrationInternal 
  
   If  IsWindows8_1() 
    DebugPrint("Is Windows 8.1")
    result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW8_1_63,@oARI) 
    If  result= #S_OK 
      DebugPrint("Created Interface W8_1_63")
    EndIf 
  EndIf
  
  If  IsWindows10() 
    DebugPrint("Is Windows 10")
    result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW10_1709,@oARI) 
    If  result= #S_OK 
      DebugPrint("Created Interface W10_1709")
    EndIf 
    
    If  result<> #S_OK 
      result=CoCreateInstance_(?CLSID_ApplicationAssociationRegistration,#Null,#CLSCTX_INPROC_SERVER,?IID_IApplicationAssociationRegistrationInternalW10_1511,@oARI) 
      If  result= #S_OK 
        DebugPrint("Created Interface W10_1511")
      EndIf 
    EndIf 
  EndIf 
  
  
  If result = #S_OK
    DebugPrint("OK AssociationRegistration Instance")
    result=oARI\SetProgIdAsDefault(@ProgramId.s,@Extension.s,#AT_FILEEXTENSION)
    DebugPrint("AssociationRegistration Set Return = " + Str(result))
  Else
    DebugPrint("FAIL AssociationRegistration Instance")
  EndIf
  
  CoUninitialize_()
EndProcedure

Procedure RegisterApplicationID(FilePath.s,FileExt.s,CustomProgramId.s)
  If  Not  IsAdmin() 
    DebugPrint("Is Not Admin")
    PrintN("Need Admin Right To Run This Command")
    End 1
  EndIf
  DebugPrint("Is Admin")
  Protected ApplicationID.s=""
  If  CustomProgramId.s<>""
    ApplicationID.s=CustomProgramId.s
  Else
    ApplicationID.s=CreateApplicationID(FilePath.s)
  EndIf 
  If  ApplicationID.s="" : End 1 : EndIf
  DebugPrint("Application Program Id = " + QuoteString(ApplicationID.s))
  Protected Parameter.s=" /c ASSOC "+FileExt.s+"=" + ApplicationID.s
  Debug Parameter.s
  Protected ExitCode=RunCmdCommand(Parameter.s)
  Debug  ExitCode
  DebugPrint("ASSOC Return = " + Str(ExitCode))
  If  ExitCode<>0 : End 1 : EndIf 
  Parameter.s=" /c FTYPE "+ApplicationID.s+"="+QuoteString(FilePath.s) + " " + QuoteString("%1")
  Debug Parameter.s
  ExitCode=RunCmdCommand(Parameter.s)
  DebugPrint("FTYPE Return = " + Str(ExitCode))
  Debug  ExitCode
  If  ExitCode<>0 : End 1 : EndIf 
  SetFTA(ApplicationID.s,FileExt.s)
EndProcedure

Procedure UnRegisterApplicationID(FilePath_ApplicationID.s)
  If  Not  IsAdmin() 
    DebugPrint("Is Not Admin")
    PrintN("Need Admin Right To Run This Command")
    End 1
  EndIf
  Protected ApplicationID.s=""
  If  Not FileExist(FilePath_ApplicationID.s) 
    ApplicationID.s=FilePath_ApplicationID.s
  Else
    ApplicationID.s=CreateApplicationID(FilePath_ApplicationID.s)
  EndIf 
  
  Protected RegistryKey.s=ApplicationID.s
  Protected Ret=Reg_KeyExists(#HKEY_CLASSES_ROOT,RegistryKey.s)
  If  Ret 
    Reg_DeleteKeyWithAllSub(#HKEY_CLASSES_ROOT,RegistryKey.s)
    Ret=Reg_KeyExists(#HKEY_CLASSES_ROOT,RegistryKey.s)
    If  Ret=#True
      DebugPrint("Key No Deleted = " + "HKEY_CLASSES_ROOT\" + RegistryKey.s)
    Else
      DebugPrint("Key Deleted = " + "HKEY_CLASSES_ROOT\" + RegistryKey.s)
    EndIf 
  Else
    DebugPrint("Key Not Found = " + "HKEY_CLASSES_ROOT\" + RegistryKey.s)
  EndIf
  
  ;DebugPrint("Unregister Program Id = " + ApplicationID.s)
  ;Protected Parameter.s=" /c FTYPE "+ApplicationID.s+"="
  ;Debug Parameter.s
  ;Protected ExitCode=RunCmdCommand(Parameter.s)
  ;Debug  ExitCode
  ;DebugPrint("FTYPE Return = " + Str(ExitCode))
  ;If  ExitCode<>0 : End 1 : EndIf
  
EndProcedure


Procedure Start()
  Protected iNumberOfParameters.i = CountProgramParameters()
  
  
  If (iNumberOfParameters=0 Or iNumberOfParameters>5);validate number of parameters
    PrintHelp()
    End 1 
  EndIf 
  
  If  iNumberOfParameters=1
    If Not IsValidParameter(ProgramParameter(0),"-h|--help|-g|-get")
      PrintN("Invalid Parameter")
      PrintHelp() 
      End 1
    EndIf
  EndIf 
  
  
  
  If (ProgramParameter(0)="-h" Or ProgramParameter(0)="--help") ;validate -h parameter
    PrintHelp()
    End 1 
  EndIf
  
  
  EnableDisableDebug() ;Enable Or Disable Debug Mode
  If  g_Debug 
    ShowWindowsInformation()
  EndIf
  
  ;   If  iNumberOfParameters=1 And (ProgramParameter(0)="-l" Or ProgramParameter(0)="--list") ;validate -l parameter
  ;     ListProgramIDs()
  ;     End 0
  ;   EndIf
  
  If  (ProgramParameter(0)="-g" Or ProgramParameter(0)="--get") ;validate -g parameter
    GetFTA(ProgramParameter(1))
    End 0
  EndIf
  
  If  (ProgramParameter(0)="-u" Or ProgramParameter(0)="--unreg") ;validate -u parameter
    UnRegisterApplicationID(ProgramParameter(1))
    End 0
  EndIf
  
  
  If iNumberOfParameters>=3 And (ProgramParameter(0)="-r" Or ProgramParameter(0)="--reg") ;validate -r parameter
    Define CustomProgramId.s=""
    If iNumberOfParameters>=4 And ProgramParameter(3)<>"-d" And ProgramParameter(3)<>"--debug"
      CustomProgramId.s=ProgramParameter(3)
    EndIf
    RegisterApplicationID(ProgramParameter(1),ProgramParameter(2),CustomProgramId.s)
    End 0
  EndIf
  
  
  If  iNumberOfParameters>=2 And iNumberOfParameters<=3
    ;SetFTA
    Define ProgramId.s,Extension.s
    ProgramId=ProgramParameter(0)
    Extension=ProgramParameter(1)
    SetFTA(ProgramId,Extension)
    End 0
  EndIf 
  
  ;no enough parameters 
  PrintN("Invalid Parameter")
  End 1 
  
EndProcedure

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SFTA Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Test Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Procedure TestCase()
  If OpenConsole()
    PrintN("Running From IDE...")
    ShowWindowsInformation()
    PrintHelp()
    Input()
    CloseConsole() 
  EndIf
EndProcedure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Test Funcions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Start App Test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CompilerIf #PB_Compiler_Debugger
  TestCase()
  End 
CompilerEndIf


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Start App
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
If OpenConsole()
  CheckValidOS()
  Start()
EndIf

; IDE Options = PureBasic 5.62 (Windows - x86)
; ExecutableFormat = Console
; CursorPosition = 750
; FirstLine = 652
; Folding = -------
; EnableXP
; UseIcon = Icon.ico
; Executable = ..\Compiled\SFTA.exe
; EnableExeConstant
; IncludeVersionInfo
; VersionField0 = 1.1.0
; VersionField1 = 1.1.0
; VersionField2 = Danysys
; VersionField3 = SFTA
; VersionField4 = 1.1.0
; VersionField5 = 1.1.0
; VersionField6 = Set Windows 8/10 File Type Association
; VersionField7 = SFTA
; VersionField8 = SFTA
; VersionField9 = © 2018 Danysys
; VersionField10 = © 2018 Danysys