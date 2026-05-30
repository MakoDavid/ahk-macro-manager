# AHK Macro Manager — User Guide

## Setup

1. Install **AutoHotkey v2.0+** from [autohotkey.com](https://www.autohotkey.com/).
2. Double-click `AHK_Console.ahk`. It runs silently — no window opens until you press F1.
3. Look for the AutoHotkey green-H icon in your system tray. Right-click for **Open Dashboard / Pause Bindings / Exit**.

To have it launch automatically at login, open the dashboard and tick **Run on Windows startup**.

---

## Global hotkeys (always active)

| Key | What it does |
|---|---|
| **F1** | Open the dashboard |
| **F2** | Stop recording and save |
| **F3** | Pause/resume *if recording* — Stop *if playing back* |
| **F4** | Undo the last recorded action (during recording) |

These four keys are reserved — anything you press on F1–F4 while recording will not be captured.

---

## Recording a macro

1. Press **F1** → dashboard opens.
2. *(Optional)* pick a folder from the **Folder:** dropdown, or click **+ New Folder** to create one (e.g. "GZW", "General").
3. Click **⏺ Record**. Enter a name (no `.ahk` extension needed) → press Enter.
4. The dashboard minimizes and a red "● Recording" tooltip appears in the top-left of the screen.
5. Do whatever you want recorded — mouse moves, clicks, keystrokes.
6. While recording:
   - **F3** pauses (tooltip becomes "⏸ Paused"). F3 again resumes.
   - **F4** undoes the last entry. Press repeatedly to undo multiple.
   - **F2** stops and saves.

If something crashes mid-recording, the next time you start the script it'll offer to recover the in-progress macro.

### Keyboard-only mode

Tick **Keyboard only mode** before recording if you want to skip all mouse capture (useful for chat macros, hotstrings, etc.). The setting persists across sessions.

### Append to an existing macro

Select a macro in the list → click **➕ Append** → confirm. New actions get inserted before the macro's final `ExitApp()`, leaving the existing content intact.

---

## Playing a macro

**Three ways to play:**
- Select a macro and click **▶ Play**
- **Double-click** the macro in the list
- Press a hotkey you bound to it (see Bindings below)

**Playback options** (above the checkboxes):
- **Loop (0=∞):** how many times to repeat. `0` = forever, until you stop it.
- **Speed %:** `100` = normal. `200` = twice as fast. `50` = half speed. Scales all `Sleep()` calls.
- **Start Delay (s):** waits N seconds before doing anything — gives you time to focus the right window.

These three values are remembered between sessions.

**To stop playback:** press **F3**, or open the dashboard and click **⏹ Stop**. Playback also shows a red "▶ Playing" tooltip while it's running.

---

## Hotkey bindings

Bind any macro to a global hotkey so you can fire it without opening the dashboard.

1. Select a macro → click **🔑 Bind**.
2. Enter a hotkey using AHK syntax:
   - `^!m` = Ctrl+Alt+M
   - `+F5` = Shift+F5
   - `F6` = just F6
   - Symbols: `^` Ctrl, `!` Alt, `+` Shift, `#` Win
3. The list now shows the binding next to the name, like `mymacro.ahk  [^!m]`.

Bindings survive script restarts (saved to `%APPDATA%\MacroManager\macromanager.ini`).

**To remove a binding:** select the macro → **⌫ Unbind**.

**To pause all bindings temporarily** (without removing them): right-click the tray icon → **Pause Bindings**. Click again to resume.

---

## Organizing macros

| Button | Purpose |
|---|---|
| **✎ Rename** | Renames the file (bindings update automatically) |
| **⎘ Duplicate** | Copies the macro, prompts for a new name |
| **🗑 Delete** | Removes from disk after confirmation |
| **✏ Edit** | Opens the `.ahk` file in Notepad for manual tweaking |
| **👁 Preview** | Shows the macro source with line numbers, monospace, read-only |
| **📋 Last** | Shows the most recent capture from this session |

### Folders

- Dropdown at the top filters the list to one folder at a time.
- **(Root)** shows macros that aren't inside any subfolder.
- **+ New Folder** creates a new subfolder under `Documents\AutoHotkey\`.
- Right-click any macro → **➜ Move to Folder...** to relocate it (bindings follow).

### Search

The text box next to "Macros:" filters the list live as you type. Case-insensitive substring match. Clearing it shows everything again. Switching folders auto-clears it.

### Right-click menu

Right-click any macro for a quick menu: Play, Preview, Rename, Duplicate, Move, Bind, Unbind, Delete — same as the buttons.

---

## Sharing macros

- **📤 Export** writes the macro to any path you pick. The export is self-contained: includes the AHK header and `ExitApp()` so the recipient can double-click and run it (they need AHK v2 installed).
- **📥 Import** copies an external `.ahk` file into the current folder.

---

## Status & info

- The gray line at the bottom shows macro count and active bindings when you open the dashboard.
- Action results (saved, deleted, errors) appear in red/green and auto-clear after 4 seconds.

### Closing the dashboard

- **Esc** or the **X** button hides the window. The script keeps running.
- Press **F1** again to bring it back, or use the tray icon.
- To fully quit the script, right-click the tray icon → **Exit**.

---

## File locations

| Path | What |
|---|---|
| `Documents\AutoHotkey\` | Your macros (and any subfolders you create) |
| `Documents\AutoHotkey\<folder>\` | Macros organized into folders |
| `%APPDATA%\MacroManager\macromanager.ini` | Settings + hotkey bindings |
| `%TEMP%\macromgr_recover.tmp` | Crash-recovery autosave (only present mid-recording) |

---

## Common gotchas

- **Recorded macro doesn't replay correctly in a game.** Some games block synthetic input or use raw input. There's no software fix from this side — that's the game's anti-cheat.
- **Mouse coords are screen-absolute.** If you record clicks at specific window positions and later move/resize the window, the clicks land on the wrong spots. Record with the window in a consistent position.
- **Modifier keys recorded mid-press.** If you start recording while holding Shift, the `Up` event gets logged but no matching `Down`. Press all modifiers fresh after recording starts.
- **Hotkey didn't bind ("Invalid hotkey").** Most often a typo — `^F5` not `Ctrl+F5`. Use AHK syntax: `^` `!` `+` `#`.
- **"Already recording" message but nothing's recording.** Press F2 once to clear state, then try again.
- **Playback ignores Speed % under 100.** Make sure you typed a number. The field accepts only digits.

---

## Quick reference card

```
F1 .................. open dashboard
F2 .................. stop recording (save)
F3 .................. pause/resume recording | stop playback
F4 .................. undo last recorded action

Double-click ........ play selected macro
Right-click ......... context menu
Esc ................. hide dashboard

Tray right-click .... open / pause bindings / exit
```

The dashboard is the source of truth — every feature is reachable from a button or a right-click menu, and global hotkeys cover the four things you do most often while away from the dashboard.
