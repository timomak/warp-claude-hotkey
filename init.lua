-- Warp hotkeys that split the current pane (Cmd+D = Warp's native split,
-- inherits the focused pane's cwd) and run `claude` in the new pane.
--   Cmd+Shift+D — open Claude.
--   Cmd+Shift+A — open Claude, then submit /address-code-review-comments ultrathink.
-- Routed through AppleScript/System Events because hs.eventtap.keyStroke
-- is affected by the user's still-held Shift from the hotkey — System
-- Events keystroke is not. Scoped to Warp by the app watcher below.
--
-- Usage (as a Lua module):
--   _G.warpClaude = require("warp-claude-hotkey")
-- The _G. prefix keeps the returned table alive so its hs.application.watcher
-- is not garbage-collected after require returns.

local M = {}

-- Seconds to wait after submitting `claude` before typing follow-up input.
-- Claude's TUI needs a moment to boot before it will accept keystrokes.
local CLAUDE_BOOT_DELAY = 3.0

local function runWarpClaude(followUp)
    local warp = hs.application.get("Warp")
    if not warp then
        print("[warpClaudeHotkey] Warp is not running")
        return
    end
    warp:activate()

    local extra = ""
    if followUp then
        extra = string.format(
            '\n                delay %s\n                keystroke "%s"\n                key code 36',
            CLAUDE_BOOT_DELAY,
            followUp
        )
    end

    local script = string.format([[
        tell application "System Events"
            tell process "Warp"
                keystroke "d" using command down
                delay 0.5
                keystroke "claude"
                key code 36%s
            end tell
        end tell
    ]], extra)

    local ok, _, raw = hs.osascript.applescript(script)
    if not ok then
        print("[warpClaudeHotkey] AppleScript failed:", hs.inspect(raw))
    else
        print("[warpClaudeHotkey] ok")
    end
end

local function makeHotkey(mods, key, followUp)
    return hs.hotkey.new(mods, key, function()
        -- Don't synthesize keystrokes until the user has released the physical
        -- Cmd and Shift keys; otherwise their modifier state leaks into the
        -- synthesized events and causes "random" behavior (uppercase typing,
        -- Cmd+key shortcuts firing, etc.).
        hs.timer.waitUntil(
            function()
                local kbMods = hs.eventtap.checkKeyboardModifiers()
                return not (kbMods.shift or kbMods.cmd)
            end,
            function() runWarpClaude(followUp) end,
            0.02
        )
    end)
end

M.hotkeys = {
    makeHotkey({ "cmd", "shift" }, "d"),
    makeHotkey({ "cmd", "shift" }, "a", "/address-code-review-comments ultrathink"),
}

local function setHotkeys(enabled)
    for _, hk in ipairs(M.hotkeys) do
        if enabled then hk:enable() else hk:disable() end
    end
end

M.watcher = hs.application.watcher.new(function(name, event, _)
    if name == "Warp" then
        if event == hs.application.watcher.activated then
            setHotkeys(true)
        elseif event == hs.application.watcher.deactivated then
            setHotkeys(false)
        end
    end
end)
M.watcher:start()

-- Enable immediately if Warp is already the frontmost app on load.
local front = hs.application.frontmostApplication()
if front and front:name() == "Warp" then
    setHotkeys(true)
end

return M
