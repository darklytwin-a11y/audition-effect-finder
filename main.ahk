#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Audition Effect Finder
; v0.3 — MVP: поиск + клик по ▶ + навигация стрелками по меню
; ============================================================

; --- Пути ---
SCRIPT_DIR := A_ScriptDir
INI_FILE   := SCRIPT_DIR . "\plugins.ini"

; --- Тайминги (мс). Если Audition не успевает — увеличить. ---
DELAY_AFTER_CLICK_MENU := 600   ; после клика по ▶ до появления меню
DELAY_ARROW            := 80    ; между нажатиями ↓
DELAY_TO_SUBMENU       := 250   ; между → и следующим ↓
DELAY_BEFORE_ENTER     := 150   ; перед финальным Enter

; ============================================================
; Чтение plugins.ini
; ============================================================
LoadPlugins() {
    global INI_FILE
    result := Map()
    if !FileExist(INI_FILE)
        return result

    sections := Map()
    currentSection := ""
    currentData := Map()

    Loop Read INI_FILE {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue

        ; новая секция [Name]
        if (SubStr(line, 1, 1) = "[") {
            if (currentSection != "" && currentData.Has("path"))
                sections[currentSection] := currentData.Clone()
            currentSection := SubStr(line, 2, StrLen(line) - 2)
            currentData := Map()
            continue
        }

        ; key = value
        eq := InStr(line, "=")
        if (eq > 0 && currentSection != "") {
            key := Trim(SubStr(line, 1, eq - 1))
            val := Trim(SubStr(line, eq + 1))
            currentData[key] := val
        }
    }
    if (currentSection != "" && currentData.Has("path"))
        sections[currentSection] := currentData.Clone()

    return sections
}

ParsePath(pathStr) {
    parts := []
    Loop Parse pathStr, ">" {
        p := Trim(A_LoopField)
        if (p != "")
            parts.Push(p)
    }
    return parts
}

ParseDowns(downsStr) {
    nums := []
    Loop Parse downsStr, "," {
        n := Trim(A_LoopField)
        if (n != "")
            nums.Push(Integer(n))
    }
    return nums
}

; ============================================================
; Главное окно поиска
; ============================================================
^!/::ToggleSearch()

ToggleSearch() {
    global INI_FILE
    if WinExist("EffectFinder") {
        WinClose("EffectFinder")
        return
    }

    plugins := LoadPlugins()
    if (plugins.Count = 0) {
        MsgBox "Файл plugins.ini не найден или пуст.`n`nОжидаемый путь:`n" . INI_FILE, "Effect Finder", "Icon!"
        return
    }

    win := Gui("+AlwaysOnTop +ToolWindow +Border", "EffectFinder")
    win.BackColor := "1e1e1e"
    win.SetFont("s11 cE0E0E0", "Segoe UI")
    win.MarginX := 12
    win.MarginY := 12

    win.Add("Text", "w380 cB0B0B0", "Плагин (Enter — применить, Esc — отмена):")
    edit := win.Add("Edit", "w380 vQuery Background2d2d2d cFFFFFF")
    list := win.Add("ListBox", "w380 h220 vSelected Background2d2d2d cFFFFFF")
    win.Add("Text", "w380 c808080", "↑↓ — навигация · Enter — выбор · Esc — закрыть")

    edit.OnEvent("Change", (*) => PopulateList(list, edit.Value, plugins))

    HotIfWinActive("EffectFinder")
    Hotkey("Enter",  (*) => ApplySelection(list, win, plugins), "On")
    Hotkey("Escape", (*) => win.Destroy(), "On")
    Hotkey("Down",   (*) => MoveSelection(list, 1), "On")
    Hotkey("Up",     (*) => MoveSelection(list, -1), "On")
    HotIfWinActive()

    list.OnEvent("DoubleClick", (*) => ApplySelection(list, win, plugins))

    PopulateList(list, "", plugins)
    win.Show("w404 h340")
    edit.Focus()
}

PopulateList(listCtrl, query, plugins) {
    listCtrl.Delete()
    q := StrLower(query)
    for name, data in plugins {
        searchable := StrLower(name)
        if data.Has("aliases")
            searchable .= " " . StrLower(data["aliases"])
        if (q = "" || InStr(searchable, q))
            listCtrl.Add([name])
    }
    if (listCtrl.GetCount() > 0)
        listCtrl.Choose(1)
}

MoveSelection(listCtrl, delta) {
    n := listCtrl.GetCount()
    if (n = 0)
        return
    idx := listCtrl.Value
    if (idx = 0)
        idx := 1
    idx += delta
    if (idx < 1)
        idx := 1
    if (idx > n)
        idx := n
    listCtrl.Choose(idx)
}

ApplySelection(listCtrl, win, plugins) {
    if (listCtrl.GetCount() = 0)
        return
    name := listCtrl.Text
    if (name = "" || !plugins.Has(name))
        return
    data := plugins[name]
    win.Destroy()
    InsertEffect(name, data)
}

; ============================================================
; Вставка эффекта
; ============================================================
InsertEffect(name, data) {
    global DELAY_AFTER_CLICK_MENU, DELAY_ARROW, DELAY_TO_SUBMENU, DELAY_BEFORE_ENTER

    if !data.Has("path") {
        MsgBox "В plugins.ini для [" . name . "] не задан параметр path.", "Effect Finder", "Icon!"
        return
    }

    parts := ParsePath(data["path"])

    if !data.Has("downs") {
        MsgBox "Для [" . name . "] не задан параметр downs.`n`n"
             . "Он указывает, сколько раз нажать ↓ на каждом уровне меню.`n"
             . "Пример: downs = 13, 4, 4, 0`n`n"
             . "Подробности — в README.md", "Effect Finder", "Icon!"
        return
    }

    downs := ParseDowns(data["downs"])
    if (downs.Length != parts.Length) {
        MsgBox "У [" . name . "] длины path и downs не совпадают." . "`n"
             . "path:  " . data["path"] . "  (" . parts.Length . " уровней)`n"
             . "downs: " . data["downs"] . "  (" . downs.Length . " чисел)", "Effect Finder", "Icon!"
        return
    }

    ; Запоминаем позицию курсора (где наведён на ▶)
    MouseGetPos(&x, &y)

    ; Активируем Audition
    if WinExist("ahk_exe Audition.exe") {
        WinActivate()
        Sleep 250
    } else {
        MsgBox "Adobe Audition не запущен.", "Effect Finder", "Icon!"
        return
    }

    ; Возвращаем курсор и кликаем
    MouseMove(x, y, 0)
    Sleep 100
    Click()
    Sleep DELAY_AFTER_CLICK_MENU

    ; Навигация по меню
    Loop parts.Length {
        i := A_Index
        downCount := downs[i]

        Loop downCount {
            Send("{Down}")
            Sleep DELAY_ARROW
        }

        if (i < parts.Length) {
            Send("{Right}")
            Sleep DELAY_TO_SUBMENU
        }
    }

    Sleep DELAY_BEFORE_ENTER
    Send("{Enter}")
}
