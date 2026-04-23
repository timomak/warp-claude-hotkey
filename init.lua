-- Warp: Cmd+Shift+D splits the current pane (Cmd+D = Warp's native split,
-- inherits the focused pane's cwd) and runs `claude` in the new pane.
-- Routed through AppleScript/System Events because hs.eventtap.keyStroke
-- is affected by the user's still-held Shift from the hotkey — System
-- Events keystroke is not. Scoped to Warp by the app watcher below.
--
-- Usage (as a Lua module):
--   _G.warpClaude = require("warp-claude-hotkey")
-- The _G. prefix keeps the returned table alive so its hs.application.watcher
-- is not garbage-collected after require returns.

local M = {}

local function runWarpClaude()
    local warp = hs.application.get("Warp")
    if not warp then
        print("[warpClaudeHotkey] Warp is not running")
        return
    end
    warp:activate()

    local ok, _, raw = hs.osascript.applescript([[
        tell application "System Events"
            tell process "Warp"
                keystroke "d" using command down
                delay 0.5
                keystroke "claude"
                key code 36
            end tell
        end tell
    ]])
    if not ok then
        print("[warpClaudeHotkey] AppleScript failed:", hs.inspect(raw))
    else
        print("[warpClaudeHotkey] ok")
    end
end

M.hotkey = hs.hotkey.new({ "cmd", "shift" }, "d", function()
    -- Don't synthesize keystrokes until the user has released the physical
    -- Cmd and Shift keys; otherwise their modifier state leaks into the
    -- synthesized events and causes "random" behavior (uppercase typing,
    -- Cmd+key shortcuts firing, etc.).
    hs.timer.waitUntil(
        function()
            local mods = hs.eventtap.checkKeyboardModifiers()
            return not (mods.shift or mods.cmd)
        end,
        runWarpClaude,
        0.02
    )
end)

M.watcher = hs.application.watcher.new(function(name, event, _)
    if name == "Warp" then
        if event == hs.application.watcher.activated then
            M.hotkey:enable()
        elseif event == hs.application.watcher.deactivated then
            M.hotkey:disable()
        end
    end
end)
M.watcher:start()

-- Enable immediately if Warp is already the frontmost app on load.
local front = hs.application.frontmostApplication()
if front and front:name() == "Warp" then
    M.hotkey:enable()
end

return M
