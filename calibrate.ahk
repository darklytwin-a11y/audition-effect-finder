#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Calibrate — счётчик нажатий ↓ в Audition
; ============================================================
; Использование:
; 1. Запустить скрипт (двойной клик по calibrate.ahk)
; 2. В Audition открыть меню Effects Rack (клик по ▶)
; 3. Нажимать ↓ / ↑ и смотреть счётчик
; 4. F9 — сбросить в 0, F10 — выход
; ============================================================

global downCount := 0

myGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "CalibrateCounter")
myGui.BackColor := "101010"
myGui.SetFont("s22 c00FF88 Bold", "Consolas")
textCtrl := myGui.Add("Text", "w220 h70 Center", "↓ 0")
myGui.Show("x" . (A_ScreenWidth - 240) . " y60 w220 h70 NoActivate")

UpdateText() {
    global downCount
    textCtrl.Text := "↓ " . downCount
}

; Счётчик работает только когда активно окно Audition
#HotIf WinActive("ahk_exe Adobe Audition.exe")
~Down:: {
    global downCount
    downCount += 1
    UpdateText()
}
~Up:: {
    global downCount
    if (downCount > 0)
        downCount -= 1
    UpdateText()
}
#HotIf

; Сброс и выход — глобально
F9:: {
    global downCount
    downCount := 0
    UpdateText()
}
F10:: ExitApp
