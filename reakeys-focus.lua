local title = "ReaKeys"

if not reaper.JS_Window_Find then
    reaper.ShowMessageBox(
        "js_ReaScriptAPI extension required for focus action.",
        "ReaKeys",
        0
    )
    return
end

local hwnd = reaper.JS_Window_Find(title, true)

if hwnd then
    reaper.JS_Window_SetForeground(hwnd)
    reaper.JS_Window_SetFocus(hwnd)
end
