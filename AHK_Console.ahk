#Requires AutoHotkey v2.0+
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("ToolTip")
SetTitleMatchMode(2)
DetectHiddenWindows(true)
SendMode("Event")
SetMouseDelay(-1)
SetKeyDelay(10, 10)

global Recording := false
global Paused := false
global LogArr := []
global LastLogArr := []
global BoundHotkeys := Map()
global BindingsPaused := false
global DashGui := 0
global MacroList := 0
global SearchEdit := 0
global StatusText := 0
global FolderDrop := 0
global LoopEdit := 0
global SpeedEdit := 0
global DelayEdit := 0
global KbOnlyChk := 0
global StartupChk := 0
global CurrentMacroPath := ""
global CurrentMacroName := ""
global AppendMode := false
global AppendTarget := ""
global KeyboardOnly := false
global MacroDir := A_MyDocuments "\AutoHotkey"
global CurrentFolder := ""
global RunningPID := 0
global SettingsDir := A_AppData "\MacroManager"
global SettingsFile := SettingsDir "\macromanager.ini"
global RecoverFile := A_Temp "\macromgr_recover.tmp"
global LogLastTime := 0
global StartupShortcut := A_Startup "\MacroManager.lnk"
; Persisted playback prefs
global LoopValue := "1"
global SpeedValue := "100"
global DelayValue := "0"

MigrateOldSettings()
LoadSettings()
SetupTrayMenu()
CheckCrashRecovery()
SetTimer(MonitorPID, 1000)
OnExit(SaveOnExit)

F1:: OpenDashboard()
F3:: HandleF3()
F4:: HandleF4()

SetupTrayMenu() {
    A_IconTip := "Macro Manager (F1 to open)"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Dashboard", (*) => OpenDashboard())
    A_TrayMenu.Add("Pause Bindings", PauseBindingsToggle)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Open Dashboard"
}

PauseBindingsToggle(itemName, itemPos, menuObj) {
    global BindingsPaused, BoundHotkeys
    BindingsPaused := !BindingsPaused
    state := BindingsPaused ? "Off" : "On"
    for hk, _ in BoundHotkeys
        try Hotkey(hk, state)
    if (BindingsPaused)
        menuObj.Check(itemName)
    else
        menuObj.Uncheck(itemName)
}

CheckCrashRecovery() {
    global RecoverFile, MacroDir
    if !FileExist(RecoverFile)
        return
    if (MsgBox("A previous recording session may have crashed.`n`nRecover the in-progress macro?", "Crash Recovery", "YesNo Icon!") = "Yes") {
        if !DirExist(MacroDir)
            DirCreate(MacroDir)
        dest := FileSelect("S", MacroDir "\recovered.ahk", "Save recovered macro", "AHK (*.ahk)")
        if (dest != "") {
            if (!RegExMatch(dest, "i)\.ahk$"))
                dest .= ".ahk"
            try {
                if (FileExist(dest))
                    FileDelete(dest)
                FileCopy(RecoverFile, dest, 1)
            }
        }
    }
    try FileDelete(RecoverFile)
}

AutosaveRecording() {
    global Recording, LogArr, RecoverFile
    if (!Recording || LogArr.Length = 0)
        return
    s := "; Autosaved at " A_Now "`n"
    s .= "#Requires AutoHotkey v2.0+`n"
    s .= "SendMode(`"Event`")`n"
    s .= "SetMouseDelay(-1)`n"
    s .= "SetKeyDelay(10, 10)`n"
    s .= "CoordMode(`"Mouse`", `"Screen`")`n"
    s .= "SetTitleMatchMode(2)`n`n"
    For k, v in LogArr
        s .= v "`n"
    s .= "`nExitApp()`n"
    try {
        if (FileExist(RecoverFile))
            FileDelete(RecoverFile)
        FileAppend(s, RecoverFile, "UTF-8")
    }
}

MigrateOldSettings() {
    global SettingsDir, SettingsFile, MacroDir
    if (!DirExist(SettingsDir))
        try DirCreate(SettingsDir)
    oldFile := MacroDir "\.macromanager.ini"
    if (FileExist(oldFile) && !FileExist(SettingsFile)) {
        try FileMove(oldFile, SettingsFile)
    }
}

MonitorPID() {
    global RunningPID
    if (RunningPID && !ProcessExist(RunningPID)) {
        RunningPID := 0
        ShowTip()
        SetStatus("Playback finished.", "Green")
    }
}

HandleF3(*) {
    global Recording, Paused, RunningPID, LogLastTime
    if (Recording) {
        Paused := !Paused
        if (Paused) {
            SetHotkey(0)
            ShowTip("⏸ Paused  |  F3 resume  |  F2 stop")
        } else {
            LogLastTime := A_TickCount
            SetHotkey(1)
            ShowTip("● Recording  |  F2 stop  |  F3 pause  |  F4 undo")
        }
        return
    }
    if (RunningPID && ProcessExist(RunningPID)) {
        try ProcessClose(RunningPID)
        RunningPID := 0
        ShowTip()
        SetStatus("Macro stopped.", "Red")
    }
}

HandleF4(*) {
    global Recording, Paused, LogArr
    if (!Recording || Paused)
        return
    if (LogArr.Length = 0) {
        ShowTip("Nothing to undo  |  F4 undo")
        SetTimer(RestoreRecordingTip, -1500)
        return
    }
    LogArr.Pop()
    ; Also pop a trailing Sleep if it remains orphaned
    if (LogArr.Length > 0 && InStr(LogArr[LogArr.Length], "Sleep("))
        LogArr.Pop()
    ShowTip("Undid last entry (" LogArr.Length " remaining)")
    SetTimer(RestoreRecordingTip, -1500)
}

RestoreRecordingTip() {
    global Recording, Paused
    if (Recording && !Paused)
        ShowTip("● Recording  |  F2 stop  |  F3 pause  |  F4 undo")
}

OpenDashboard() {
    global DashGui, MacroList, SearchEdit, StatusText, FolderDrop
    global LoopEdit, SpeedEdit, DelayEdit, KbOnlyChk, StartupChk
    global KeyboardOnly, LoopValue, SpeedValue, DelayValue

    if (IsObject(DashGui))
        try DashGui.Destroy()

    DashGui := Gui("+AlwaysOnTop", "Macro Manager")
    DashGui.SetFont("s10")
    DashGui.OnEvent("Escape", (*) => DashGui.Hide())

    DashGui.Add("Text", "xm", "Folder:")
    FolderDrop := DashGui.Add("DropDownList", "x+5 yp-3 w200 vFolderDrop")
    FolderDrop.OnEvent("Change", FolderChanged)
    DashGui.Add("Button", "x+5 yp-1 w90", "+ New Folder").OnEvent("Click", NewFolderFlow)

    DashGui.Add("Text", "xm y+10", "Macros:")
    SearchEdit := DashGui.Add("Edit", "x+10 yp-3 w200 vSearchEdit")
    SearchEdit.OnEvent("Change", (*) => RefreshMacroList())

    MacroList := DashGui.Add("ListBox", "xm w400 h180 vMacroList")
    MacroList.OnEvent("DoubleClick", (*) => PlaySelected())
    MacroList.OnEvent("ContextMenu", ShowListContextMenu)

    ; Row: record/play
    DashGui.Add("Button", "xm w95", "⏺ Record").OnEvent("Click", StartRecordFlow)
    DashGui.Add("Button", "x+5 w95", "➕ Append").OnEvent("Click", AppendFlow)
    DashGui.Add("Button", "x+5 w95", "▶ Play").OnEvent("Click", PlaySelected)
    DashGui.Add("Button", "x+5 w95", "⏹ Stop (F3)").OnEvent("Click", StopPlayback)

    ; Row: file ops
    DashGui.Add("Button", "xm w76", "👁 Preview").OnEvent("Click", PreviewSelected)
    DashGui.Add("Button", "x+5 w76", "✏ Edit").OnEvent("Click", EditSelected)
    DashGui.Add("Button", "x+5 w76", "✎ Rename").OnEvent("Click", RenameSelected)
    DashGui.Add("Button", "x+5 w76", "⎘ Duplicate").OnEvent("Click", DuplicateSelected)
    DashGui.Add("Button", "x+5 w76", "🗑 Delete").OnEvent("Click", DeleteSelected)

    ; Row: bindings, import/export, debug
    DashGui.Add("Button", "xm w76", "🔑 Bind").OnEvent("Click", BindHotkeyFlow)
    DashGui.Add("Button", "x+5 w76", "⌫ Unbind").OnEvent("Click", RemoveBinding)
    DashGui.Add("Button", "x+5 w76", "📥 Import").OnEvent("Click", ImportMacro)
    DashGui.Add("Button", "x+5 w76", "📤 Export").OnEvent("Click", ExportMacro)
    DashGui.Add("Button", "x+5 w76", "📋 Last").OnEvent("Click", ShowLastCapture)

    ; Row: playback options
    DashGui.Add("Text", "xm", "Loop (0=∞):")
    LoopEdit := DashGui.Add("Edit", "x+5 yp-3 w40 Number", LoopValue)
    LoopEdit.OnEvent("Change", LoopChanged)
    DashGui.Add("Text", "x+10 yp+3", "Speed %:")
    SpeedEdit := DashGui.Add("Edit", "x+5 yp-3 w40 Number", SpeedValue)
    SpeedEdit.OnEvent("Change", SpeedChanged)
    DashGui.Add("Text", "x+10 yp+3", "Start Delay (s):")
    DelayEdit := DashGui.Add("Edit", "x+5 yp-3 w40 Number", DelayValue)
    DelayEdit.OnEvent("Change", DelayChanged)

    ; Row: checkboxes (kb-only + startup on one row)
    KbOnlyChk := DashGui.Add("Checkbox", "xm", "Keyboard only mode")
    KbOnlyChk.Value := KeyboardOnly ? 1 : 0
    KbOnlyChk.OnEvent("Click", (*) => SetKbOnly())

    StartupChk := DashGui.Add("Checkbox", "x+25 yp", "Run on Windows startup")
    StartupChk.Value := FileExist(StartupShortcut) ? 1 : 0
    StartupChk.OnEvent("Click", (*) => ToggleStartup())

    StatusText := DashGui.Add("Text", "xm w400", "")

    RefreshFolders()
    RefreshMacroList()
    ShowCountInStatus()
    DashGui.Show()
}

ShowCountInStatus() {
    global StatusText, BoundHotkeys
    if !IsObject(StatusText)
        return
    boundCount := 0
    for hk, _ in BoundHotkeys
        boundCount++
    count := GetMacroCount()
    info := count " macro" (count = 1 ? "" : "s") " in folder"
    if (boundCount > 0)
        info .= "  ·  " boundCount " hotkey binding" (boundCount = 1 ? "" : "s") " active"
    try {
        StatusText.SetFont("c808080")
        StatusText.Text := info
    }
}

GetMacroCount() {
    dir := GetCurrentDir()
    count := 0
    if DirExist(dir) {
        Loop Files, dir "\*.ahk"
            count++
    }
    return count
}

LoopChanged(ctrl, *) {
    global LoopValue
    LoopValue := ctrl.Value
}

SpeedChanged(ctrl, *) {
    global SpeedValue
    SpeedValue := ctrl.Value
}

DelayChanged(ctrl, *) {
    global DelayValue
    DelayValue := ctrl.Value
}

ShowListContextMenu(ctrl, item, isRightClick, x, y) {
    if (item > 0)
        ctrl.Choose(item)
    if (ctrl.Text = "")
        return
    m := Menu()
    m.Add("▶ Play", (*) => PlaySelected())
    m.Add("👁 Preview", (*) => PreviewSelected())
    m.Add()
    m.Add("✎ Rename", (*) => RenameSelected())
    m.Add("⎘ Duplicate", (*) => DuplicateSelected())
    m.Add("➜ Move to Folder...", (*) => MoveSelected())
    m.Add()
    m.Add("🔑 Bind Hotkey", (*) => BindHotkeyFlow())
    m.Add("⌫ Remove Binding", (*) => RemoveBinding())
    m.Add()
    m.Add("🗑 Delete", (*) => DeleteSelected())
    m.Show()
}

MoveSelected(*) {
    global MacroDir
    name := GetSelectedName()
    src := GetSelectedPath()
    if (src = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    folders := ["(Root)"]
    Loop Files, MacroDir "\*", "D" {
        if (SubStr(A_LoopFileName, 1, 1) = ".")
            continue
        folders.Push(A_LoopFileName)
    }
    if (folders.Length < 2) {
        SetStatus("No other folders exist - create one first.", "Red")
        return
    }
    pg := Gui("+AlwaysOnTop +OwnDialogs", "Move to Folder")
    pg.SetFont("s10")
    pg.Add("Text",, "Move '" name "' to:")
    dd := pg.Add("DropDownList", "w200", folders)
    dd.Choose(1)
    pg.Add("Button", "Default w80", "Move").OnEvent("Click", (*) => DoMove(pg, dd, src, name))
    pg.Add("Button", "x+10 w80", "Cancel").OnEvent("Click", (*) => pg.Destroy())
    pg.Show()
}

DoMove(pg, dd, src, name) {
    global MacroDir
    chosen := dd.Text
    dest := (chosen = "(Root)") ? MacroDir : MacroDir "\" chosen
    target := dest "\" name
    if (FileExist(target)) {
        SetStatus("File already exists in target folder.", "Red")
        pg.Destroy()
        return
    }
    try {
        FileMove(src, target)
        UpdateBindingPath(src, target)
        SetStatus("Moved to " chosen, "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Move failed: " e.Message, "Red")
    }
    pg.Destroy()
}

SetKbOnly() {
    global KeyboardOnly, KbOnlyChk
    KeyboardOnly := KbOnlyChk.Value = 1
    SaveSettings()
}

ToggleStartup() {
    global StartupShortcut, StartupChk
    if (StartupChk.Value = 1) {
        try FileCreateShortcut(A_ScriptFullPath, StartupShortcut)
        SetStatus("Will run on startup.", "Green")
    } else {
        if FileExist(StartupShortcut)
            try FileDelete(StartupShortcut)
        SetStatus("Removed from startup.", "Green")
    }
}

FolderChanged(*) {
    global CurrentFolder, FolderDrop, SearchEdit
    sel := FolderDrop.Text
    CurrentFolder := (sel = "(Root)") ? "" : sel
    try SearchEdit.Value := ""
    RefreshMacroList()
    ShowCountInStatus()
}

NewFolderFlow(*) {
    global MacroDir
    IB := InputBox("New folder name:", "New Folder", "w280 h120")
    if (IB.Result = "Cancel" || IB.Value = "")
        return
    name := SanitizeName(IB.Value)
    if (name = "") {
        SetStatus("Invalid folder name.", "Red")
        return
    }
    path := MacroDir "\" name
    if DirExist(path) {
        SetStatus("Folder already exists.", "Red")
        return
    }
    DirCreate(path)
    RefreshFolders()
    SetStatus("Created folder: " name, "Green")
}

SanitizeName(s) {
    s := RegExReplace(s, "[\\/:*?`"<>|]", "")
    s := Trim(s)
    return s
}

GetCurrentDir() {
    global MacroDir, CurrentFolder
    return CurrentFolder = "" ? MacroDir : MacroDir "\" CurrentFolder
}

RefreshFolders() {
    global FolderDrop, MacroDir, CurrentFolder
    items := ["(Root)"]
    if DirExist(MacroDir) {
        Loop Files, MacroDir "\*", "D" {
            if (SubStr(A_LoopFileName, 1, 1) = ".")
                continue
            items.Push(A_LoopFileName)
        }
    }
    FolderDrop.Delete()
    FolderDrop.Add(items)
    sel := 1
    Loop items.Length {
        if (items[A_Index] = (CurrentFolder = "" ? "(Root)" : CurrentFolder)) {
            sel := A_Index
            break
        }
    }
    FolderDrop.Choose(sel)
}

RefreshMacroList() {
    global MacroList, BoundHotkeys, SearchEdit
    if !IsObject(MacroList)
        return
    MacroList.Delete()
    dir := GetCurrentDir()
    if !DirExist(dir)
        return
    filter := ""
    try filter := SearchEdit.Value
    Loop Files, dir "\*.ahk" {
        if (filter != "" && !InStr(A_LoopFileName, filter))
            continue
        bound := ""
        for hk, file in BoundHotkeys {
            if (file = A_LoopFileFullPath)
                bound := "  [" hk "]"
        }
        MacroList.Add([A_LoopFileName . bound])
    }
}

GetSelectedPath() {
    global MacroList
    sel := MacroList.Text
    if (sel = "")
        return ""
    sel := RegExReplace(sel, "\s*\[.*\]$")
    return GetCurrentDir() "\" sel
}

GetSelectedName() {
    global MacroList
    sel := MacroList.Text
    if (sel = "")
        return ""
    return RegExReplace(sel, "\s*\[.*\]$")
}

StartRecordFlow(*) {
    global Recording, CurrentMacroName, CurrentMacroPath, DashGui, AppendMode

    if (Recording) {
        SetStatus("Already recording. F2 stops, F3 pauses.", "Red")
        return
    }

    AppendMode := false
    IB := InputBox("Enter a name for this macro (no extension):", "New Macro", "w300 h120")
    if (IB.Result = "Cancel" || IB.Value = "")
        return

    name := SanitizeName(IB.Value)
    if (name = "") {
        SetStatus("Invalid macro name.", "Red")
        return
    }
    CurrentMacroName := name
    CurrentMacroPath := GetCurrentDir() "\" name ".ahk"

    if (FileExist(CurrentMacroPath)) {
        res := MsgBox("'" name ".ahk' already exists. Overwrite it?", "Confirm Overwrite", "YesNo Icon!")
        if (res != "Yes")
            return
    }

    dir := GetCurrentDir()
    if !DirExist(dir)
        DirCreate(dir)

    try DashGui.Minimize()
    Sleep(500)
    SetStatus("Recording... F2 stop, F3 pause, F4 undo.", "Red")
    RecordScreen()
}

AppendFlow(*) {
    global AppendMode, AppendTarget, CurrentMacroName, CurrentMacroPath, DashGui, Recording
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    if (Recording) {
        SetStatus("Already recording.", "Red")
        return
    }
    name := GetSelectedName()
    res := MsgBox("Append new recording to '" name "'?`n`nExisting content is preserved; new actions are inserted before the final ExitApp().", "Confirm Append", "YesNo Icon!")
    if (res != "Yes")
        return
    AppendMode := true
    AppendTarget := path
    CurrentMacroName := name
    CurrentMacroPath := path

    try DashGui.Minimize()
    Sleep(500)
    SetStatus("Appending... F2 stop, F3 pause, F4 undo.", "Red")
    RecordScreen()
}

StopAndSave(*) {
    global Recording, Paused, LogArr, LastLogArr, CurrentMacroPath, CurrentMacroName
    global DashGui, AppendMode, AppendTarget, RecoverFile

    if (!Recording)
        return

    Recording := false
    Paused := false
    SetHotkey(0)
    try Hotkey("F2", "Off")
    SetTimer(AutosaveRecording, 0)
    ShowTip()

    if (LogArr.Length = 0) {
        ReopenDashboard()
        SetStatus("Nothing recorded.", "Red")
        AppendMode := false
        try FileDelete(RecoverFile)
        return
    }

    if (AppendMode && FileExist(AppendTarget)) {
        existing := FileRead(AppendTarget)
        newCmds := ""
        For k, v in LogArr
            newCmds .= v "`n"
        if RegExMatch(existing, "ms)\R+ExitApp\(\)\s*$") {
            existing := RegExReplace(existing, "ms)(\R+)ExitApp\(\)\s*$", "`n" newCmds "`n$0")
        } else {
            existing .= "`n" newCmds "`nExitApp()`n"
        }
        try FileDelete(AppendTarget)
        FileAppend(existing, AppendTarget, "UTF-8")
        SetStatus("Appended to: " CurrentMacroName, "Green")
    } else {
        s := "#Requires AutoHotkey v2.0+`n"
        s .= "SendMode(`"Event`")`n"
        s .= "SetMouseDelay(-1)`n"
        s .= "SetKeyDelay(10, 10)`n"
        s .= "CoordMode(`"Mouse`", `"Screen`")`n"
        s .= "SetTitleMatchMode(2)`n`n"
        For k, v in LogArr
            s .= v "`n"
        s .= "`nExitApp()`n"
        s := RegExReplace(s, "\R", "`n")

        if (FileExist(CurrentMacroPath))
            FileDelete(CurrentMacroPath)
        FileAppend(s, CurrentMacroPath, "UTF-8")
        SetStatus("Saved: " CurrentMacroName ".ahk", "Green")
    }

    LastLogArr := LogArr.Clone()
    LogArr := []
    AppendMode := false
    try FileDelete(RecoverFile)
    ReopenDashboard()
    RefreshMacroList()
}

; Safely restore the dashboard whether or not it still exists (it may have been closed mid-recording)
ReopenDashboard() {
    global DashGui
    if (IsObject(DashGui)) {
        try {
            DashGui.Show()
            return
        }
    }
    OpenDashboard()
}

PlaySelected(*) {
    global DashGui, LoopEdit, SpeedEdit, DelayEdit
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    if (!FileExist(path)) {
        SetStatus("File not found.", "Red")
        return
    }

    loopCount := Integer(LoopEdit.Value || "1")
    speed := Integer(SpeedEdit.Value || "100")
    if (speed < 1)
        speed := 100
    startDelay := Integer(DelayEdit.Value || "0")

    try DashGui.Minimize()
    Sleep(300)
    RunMacro(path, loopCount, speed, startDelay)
}

StopPlayback(*) {
    global RunningPID
    if (RunningPID && ProcessExist(RunningPID)) {
        try ProcessClose(RunningPID)
        RunningPID := 0
        ShowTip()
        SetStatus("Macro stopped.", "Red")
    } else {
        RunningPID := 0
        ShowTip()
        SetStatus("No macro running.", "Red")
    }
}

RunMacro(path, loopCount := 1, speed := 100, startDelay := 0) {
    global RunningPID
    if (!FileExist(path))
        return

    content := FileRead(path)
    body := RegExReplace(content, "im)^\s*#Requires.*$", "")
    body := RegExReplace(body, "im)^\s*SendMode\(.*\)\s*$", "")
    body := RegExReplace(body, "im)^\s*SetMouseDelay\(.*\)\s*$", "")
    body := RegExReplace(body, "im)^\s*SetKeyDelay\(.*\)\s*$", "")
    body := RegExReplace(body, "im)^\s*CoordMode\(.*\)\s*$", "")
    body := RegExReplace(body, "im)^\s*SetTitleMatchMode\(.*\)\s*$", "")
    body := RegExReplace(body, "im)^\s*ExitApp\(\)\s*$", "")

    if (speed != 100)
        body := RegExReplace(body, "Sleep\((\d+)\)", "Sleep(Round($1 * 100 / " speed "))")

    wrapper := "#Requires AutoHotkey v2.0+`n"
    wrapper .= "#SingleInstance Off`n"
    wrapper .= "SendMode(`"Event`")`n"
    wrapper .= "SetMouseDelay(-1)`n"
    wrapper .= "SetKeyDelay(10, 10)`n"
    wrapper .= "CoordMode(`"Mouse`", `"Screen`")`n"
    wrapper .= "SetTitleMatchMode(2)`n`n"

    if (startDelay > 0)
        wrapper .= "Sleep(" (startDelay * 1000) ")`n"

    if (loopCount = 0)
        wrapper .= "Loop {`n" body "`n}`n"
    else if (loopCount > 1)
        wrapper .= "Loop " loopCount " {`n" body "`n}`n"
    else
        wrapper .= body "`n"

    wrapper .= "`nExitApp()`n"

    tmpPath := A_Temp "\_macroplay_" A_TickCount ".ahk"
    FileAppend(wrapper, tmpPath, "UTF-8")

    pid := 0
    Run(A_AhkPath " `"" tmpPath "`"", , , &pid)
    RunningPID := pid
    ; Clean up temp file after playback process has had time to start
    SetTimer(() => (FileExist(tmpPath) ? FileDelete(tmpPath) : 0), -10000)
    SetStatus("Playing... (F3 or Stop to halt)", "Green")
    ShowTip("▶ Playing  |  F3 stop")
}

PreviewSelected(*) {
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    content := FileRead(path)
    ; Add line numbers
    numbered := ""
    lineNo := 0
    Loop Parse, content, "`n", "`r" {
        lineNo++
        numbered .= Format("{:4}  {}`n", lineNo, A_LoopField)
    }
    pg := Gui("+AlwaysOnTop +Resize", "Preview: " GetSelectedName())
    pg.SetFont("s9", "Consolas")
    pg.Add("Edit", "w700 h500 ReadOnly +HScroll -Wrap", numbered)
    pg.Add("Button", "Default w80 xm", "Close").OnEvent("Click", (*) => pg.Destroy())
    pg.OnEvent("Escape", (*) => pg.Destroy())
    pg.Show()
}

ShowLastCapture(*) {
    global LastLogArr
    if (LastLogArr.Length = 0) {
        SetStatus("No recent capture in this session.", "Red")
        return
    }
    content := "; Last capture - " LastLogArr.Length " entries`n`n"
    For i, line in LastLogArr {
        content .= Format("{:4}  {}`n", i, line)
    }
    pg := Gui("+AlwaysOnTop +Resize", "Last Capture (" LastLogArr.Length " entries)")
    pg.SetFont("s9", "Consolas")
    pg.Add("Edit", "w700 h500 ReadOnly +HScroll -Wrap", content)
    pg.Add("Button", "Default w80 xm", "Close").OnEvent("Click", (*) => pg.Destroy())
    pg.OnEvent("Escape", (*) => pg.Destroy())
    pg.Show()
}

RenameSelected(*) {
    name := GetSelectedName()
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    base := RegExReplace(name, "\.ahk$")
    IB := InputBox("New name (no extension):", "Rename Macro", "w300 h120", base)
    if (IB.Result = "Cancel" || IB.Value = "")
        return
    newName := SanitizeName(IB.Value)
    if (newName = "") {
        SetStatus("Invalid name.", "Red")
        return
    }
    newPath := GetCurrentDir() "\" newName ".ahk"
    if (FileExist(newPath)) {
        SetStatus("File already exists.", "Red")
        return
    }
    try {
        FileMove(path, newPath)
        UpdateBindingPath(path, newPath)
        SetStatus("Renamed to " newName ".ahk", "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Rename failed: " e.Message, "Red")
    }
}

DuplicateSelected(*) {
    name := GetSelectedName()
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    base := RegExReplace(name, "\.ahk$")
    IB := InputBox("Copy name (no extension):", "Duplicate Macro", "w300 h120", base "_copy")
    if (IB.Result = "Cancel" || IB.Value = "")
        return
    newName := SanitizeName(IB.Value)
    if (newName = "") {
        SetStatus("Invalid name.", "Red")
        return
    }
    newPath := GetCurrentDir() "\" newName ".ahk"
    if (FileExist(newPath)) {
        SetStatus("File already exists.", "Red")
        return
    }
    try {
        FileCopy(path, newPath)
        SetStatus("Duplicated as " newName ".ahk", "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Duplicate failed: " e.Message, "Red")
    }
}

DeleteSelected(*) {
    name := GetSelectedName()
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    res := MsgBox("Delete " name "? This cannot be undone.", "Confirm Delete", "YesNo Icon!")
    if (res != "Yes")
        return
    try {
        FileDelete(path)
        RemoveBindingByPath(path)
        SetStatus("Deleted: " name, "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Delete failed: " e.Message, "Red")
    }
}

ImportMacro(*) {
    src := FileSelect(1, , "Import macro", "AutoHotkey scripts (*.ahk)")
    if (src = "")
        return
    SplitPath(src, &fname)
    dest := GetCurrentDir() "\" fname
    if (FileExist(dest)) {
        res := MsgBox("Overwrite existing " fname "?", "Confirm", "YesNo")
        if (res != "Yes")
            return
        try FileDelete(dest)
    }
    try {
        dir := GetCurrentDir()
        if !DirExist(dir)
            DirCreate(dir)
        FileCopy(src, dest)
        SetStatus("Imported: " fname, "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Import failed: " e.Message, "Red")
    }
}

ExportMacro(*) {
    name := GetSelectedName()
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    dest := FileSelect("S", name, "Export macro", "AutoHotkey scripts (*.ahk)")
    if (dest = "")
        return
    if (!RegExMatch(dest, "i)\.ahk$"))
        dest .= ".ahk"
    try {
        content := FileRead(path)
        ; Ensure the exported file is self-contained: header + ExitApp
        if (!RegExMatch(content, "im)^\s*#Requires\s+AutoHotkey")) {
            header := "#Requires AutoHotkey v2.0+`n"
            header .= "SendMode(`"Event`")`n"
            header .= "SetMouseDelay(-1)`n"
            header .= "SetKeyDelay(10, 10)`n"
            header .= "CoordMode(`"Mouse`", `"Screen`")`n"
            header .= "SetTitleMatchMode(2)`n`n"
            content := header content
        }
        if (!RegExMatch(content, "im)^\s*ExitApp\(\)\s*$")) {
            content := RTrim(content, "`r`n") "`n`nExitApp()`n"
        }
        content := RegExReplace(content, "\R", "`n")
        if (FileExist(dest))
            FileDelete(dest)
        FileAppend(content, dest, "UTF-8")
        SetStatus("Exported to: " dest, "Green")
    } catch as e {
        SetStatus("Export failed: " e.Message, "Red")
    }
}

BindHotkeyFlow(*) {
    global BoundHotkeys
    name := GetSelectedName()
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }

    IB := InputBox("Enter hotkey to bind (e.g. ^!m or F5):`n`nCtrl=^   Alt=!   Shift=+", "Bind Hotkey", "w300 h150")
    if (IB.Result = "Cancel" || IB.Value = "")
        return

    hk := IB.Value

    try {
        Hotkey(hk, BindRunner(path), "On")
        BoundHotkeys[hk] := path
        SaveSettings()
        SetStatus("Bound " hk " → " name, "Green")
        RefreshMacroList()
    } catch as e {
        SetStatus("Invalid hotkey: " hk, "Red")
    }
}

BindRunner(path) {
    return (*) => RunMacro(path, 1, 100, 0)
}

RemoveBinding(*) {
    global BoundHotkeys
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    name := GetSelectedName()
    if RemoveBindingByPath(path) {
        SetStatus("Removed binding for " name, "Green")
        RefreshMacroList()
    } else {
        SetStatus("No binding found for " name, "Red")
    }
}

RemoveBindingByPath(path) {
    global BoundHotkeys
    found := false
    toRemove := []
    for hk, file in BoundHotkeys {
        if (file = path)
            toRemove.Push(hk)
    }
    for _, hk in toRemove {
        try Hotkey(hk, "Off")
        BoundHotkeys.Delete(hk)
        found := true
    }
    if found
        SaveSettings()
    return found
}

UpdateBindingPath(oldPath, newPath) {
    global BoundHotkeys
    changed := false
    for hk, file in BoundHotkeys {
        if (file = oldPath) {
            BoundHotkeys[hk] := newPath
            try Hotkey(hk, "Off")
            try Hotkey(hk, BindRunner(newPath), "On")
            changed := true
        }
    }
    if changed
        SaveSettings()
}

EditSelected(*) {
    path := GetSelectedPath()
    if (path = "") {
        SetStatus("No macro selected.", "Red")
        return
    }
    Run("notepad.exe `"" path "`"")
}

SetStatus(msg, color := "Red") {
    global StatusText
    try {
        StatusText.SetFont("c" color)
        StatusText.Text := msg
        ; Auto-clear status after 4 seconds
        SetTimer(() => (IsObject(StatusText) ? StatusText.Text := "" : 0), -4000)
    }
}

LoadSettings() {
    global SettingsFile, KeyboardOnly, BoundHotkeys, LoopValue, SpeedValue, DelayValue, CurrentFolder
    if !FileExist(SettingsFile)
        return
    try KeyboardOnly := IniRead(SettingsFile, "UI", "KeyboardOnly", "0") = "1"
    try CurrentFolder := IniRead(SettingsFile, "UI", "LastFolder", "")
    try LoopValue := IniRead(SettingsFile, "Playback", "Loop", "1")
    try SpeedValue := IniRead(SettingsFile, "Playback", "Speed", "100")
    try DelayValue := IniRead(SettingsFile, "Playback", "Delay", "0")

    try {
        bindStr := IniRead(SettingsFile, "Bindings")
        Loop Parse, bindStr, "`n", "`r" {
            line := A_LoopField
            if (line = "")
                continue
            eq := InStr(line, "=")
            if (!eq)
                continue
            hk := SubStr(line, 1, eq - 1)
            path := SubStr(line, eq + 1)
            if (FileExist(path)) {
                try {
                    Hotkey(hk, BindRunner(path), "On")
                    BoundHotkeys[hk] := path
                }
            }
        }
    }
}

SaveSettings() {
    global SettingsFile, SettingsDir, KeyboardOnly, BoundHotkeys
    global LoopValue, SpeedValue, DelayValue, CurrentFolder
    if !DirExist(SettingsDir)
        try DirCreate(SettingsDir)
    try IniWrite(KeyboardOnly ? "1" : "0", SettingsFile, "UI", "KeyboardOnly")
    try IniWrite(CurrentFolder, SettingsFile, "UI", "LastFolder")
    try IniWrite(LoopValue, SettingsFile, "Playback", "Loop")
    try IniWrite(SpeedValue, SettingsFile, "Playback", "Speed")
    try IniWrite(DelayValue, SettingsFile, "Playback", "Delay")
    try IniDelete(SettingsFile, "Bindings")
    for hk, path in BoundHotkeys
        try IniWrite(path, SettingsFile, "Bindings", hk)
}

SaveOnExit(*) {
    SaveSettings()
}

; ===== Recording Engine =====

RecordScreen() {
    global LogArr, Recording, LogLastTime, Paused, RecoverFile
    LogArr := []
    Recording := true
    Paused := false
    LogLastTime := 0

    try FileDelete(RecoverFile)

    ShowTip("● Recording  |  F2 stop  |  F3 pause  |  F4 undo")
    SetHotkey(1)
    Hotkey("F2", StopAndSave, "On")
    SetTimer(AutosaveRecording, 10000)
}

ShowTip(s := "") {
    static TipGui := 0
    if (IsObject(TipGui))
        try TipGui.Destroy()
    if (s = "")
        return
    TipGui := Gui("+LastFound +AlwaysOnTop +ToolWindow -Caption +E0x08000020")
    WinSetTransColor("FFFFF0 180")
    TipGui.BackColor := "FFFFF0"
    TipGui.MarginX := 10
    TipGui.MarginY := 5
    TipGui.SetFont("q3 s16 bold cRed")
    TipGui.Add("Text",, s)
    TipGui.Show("NA y35")
}

SetHotkey(f := false) {
    global KeyboardOnly
    fOn := f ? "On" : "Off"
    Loop 254 {
        k := GetKeyName(vk := Format("vk{:X}", A_Index))
        ; Skip reserved hotkeys (F1-F4) and base modifier names
        if (k ~= "^(?i:|Control|Alt|Shift|F1|F2|F3|F4)$")
            continue
        if (KeyboardOnly && k ~= "^(?i:LButton|RButton|MButton|XButton1|XButton2)$")
            continue
        try Hotkey("~*" vk, LogKey, fOn)
    }
    For i, k in StrSplit("NumpadEnter|Home|End|PgUp|PgDn|Left|Right|Up|Down|Delete|Insert", "|") {
        sc := Format("sc{:03X}", GetKeySC(k))
        try Hotkey("~*" sc, LogKey, fOn)
    }
    if (f = "On" || f = 1 || f = true) {
        if (!KeyboardOnly)
            SetTimer(LogMouseMove, 1)
    } else {
        SetTimer(LogMouseMove, 0)
    }
}

LogMouseMove() {
    global Recording, Paused, LogArr, KeyboardOnly
    static LastX := -1, LastY := -1, LastT := 0
    if (!Recording || Paused || KeyboardOnly)
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&X, &Y)
    if (X = LastX && Y = LastY)
        return
    t := A_TickCount
    ; Decimate: skip pushes that are both close in space (<5 px) AND close in time (<25 ms)
    if (LastX >= 0 && Abs(X - LastX) + Abs(Y - LastY) < 5 && t - LastT < 25)
        return
    LastX := X
    LastY := Y
    LastT := t
    LogArr.Push("MouseMove(" X ", " Y ", 0)")
}

LogKey(HotkeyName) {
    global Paused
    if (Paused)
        return
    Critical()
    k := GetKeyName(vksc := SubStr(A_ThisHotkey, 3))
    k := StrReplace(k, "Control", "Ctrl"), r := SubStr(k, 2)
    if (r ~= "^(?i:Alt|Ctrl|Shift|Win)$")
        LogKey_Control(k)
    else if (k ~= "^(?i:LButton|RButton|MButton)$")
        LogKey_Mouse(k)
    else {
        k := StrLen(k) > 1 ? "{" k "}" : k ~= "\w" ? k : "{" vksc "}"
        Log(k, 1)
    }
}

LogKey_Control(key) {
    k := InStr(key, "Win") ? key : SubStr(key, 2)
    Log("{" k " Down}", 1)
    Critical("Off")
    KeyWait(key)
    Critical()
    Log("{" k " Up}", 1)
}

LogKey_Mouse(key) {
    global KeyboardOnly
    if (KeyboardOnly)
        return
    k := SubStr(key, 1, 1)

    CoordMode("Mouse", "Screen")
    MouseGetPos(&X, &Y)

    LogArr.Push("MouseMove(" X ", " Y ", 0)")
    LogArr.Push("MouseClick(`"" k "`", " X ", " Y ",,, `"D`")")

    t1 := A_TickCount
    Critical("Off")
    KeyWait(key)
    Critical()
    t2 := A_TickCount

    CoordMode("Mouse", "Screen")
    MouseGetPos(&X2, &Y2)

    if (Abs(X2 - X) + Abs(Y2 - Y) < 5 && t2 - t1 <= 200) {
        LogArr.Pop()
        LogArr.Push("MouseClick(`"" k "`", " X ", " Y ")")
    } else {
        LogArr.Push("MouseMove(" X2 ", " Y2 ", 0)")
        LogArr.Push("MouseClick(`"" k "`", " X2 ", " Y2 ",,, `"U`")")
    }
}

Log(str := "", Keyboard := false) {
    global LogArr, LogLastTime, Paused
    if (Paused)
        return
    t := A_TickCount
    Delay := (LogLastTime ? t - LogLastTime : 0)
    LogLastTime := t
    if (str = "")
        return
    i := LogArr.Length
    r := i = 0 ? "" : LogArr[i]
    if (Keyboard && InStr(r, "Send") && Delay < 1000) {
        LogArr[i] := SubStr(r, 1, -1) . str "`""
        return
    }
    if (Delay > 50)
        LogArr.Push("Sleep(50)")
    LogArr.Push(Keyboard ? "Send `"{Blind}" str "`"" : str)
}
