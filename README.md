# Warp Claude Hotkey

Keystroke launchers for [Claude Code](https://claude.com/claude-code) inside [Warp](https://www.warp.dev/), powered by [Hammerspoon](https://www.hammerspoon.org/).

- **Cmd+Shift+D** — splits the current pane to the right (using Warp's native `Cmd+D`, which inherits the focused pane's `cwd`) and runs `claude` in it.
- **Cmd+Shift+A** — same as above, then waits for Claude to come up and submits `/address-code-review-comments ultrathink`.

No new windows. No cwd reset. No clicking.

## What it does

| Shortcut | Action |
|----------|--------|
| Cmd+Shift+D (in Warp) | Split pane right + run `claude` in the new pane |
| Cmd+Shift+A (in Warp) | Same as above, then submit `/address-code-review-comments ultrathink` |

## Why Hammerspoon?

Warp alone can't do this:

- **Launch configurations** always open a *new window*, not a split inside your current one, and they can't inherit your current `cwd`.
- **`~/.warp/keybindings.yaml`** only accepts a fixed action vocabulary — there's no action for "split pane and run command X." Unknown actions are silently ignored.
- The Warp URI scheme (`warp://launch/<name>`) has the same new-window limitation.

The only way to get "split current window, same cwd, run claude" is to simulate the keystrokes you'd press manually. Hammerspoon drives Warp the same way your fingers would, and its app watcher keeps the hotkey scoped to Warp so it doesn't shadow Cmd+Shift+D in other apps.

## Prerequisites

- macOS
- [Warp](https://www.warp.dev/) terminal
- [Claude Code](https://claude.com/claude-code) installed and available on your `PATH` as `claude`
- [Hammerspoon](https://www.hammerspoon.org/)

## Installation

### 1. Install Hammerspoon

```bash
brew install --cask hammerspoon
open -a Hammerspoon
```

Grant **Accessibility** permissions when prompted:
**System Settings → Privacy & Security → Accessibility → toggle Hammerspoon on**

Grant **Automation → System Events** access the first time the hotkey fires (or pre-approve under **System Settings → Privacy & Security → Automation → Hammerspoon → System Events**).

Enable launch at login:
**Hammerspoon menu bar icon → Preferences → Launch Hammerspoon at login**

### 2. Install the config

This file is a Lua module — load it via `require` from your main `~/.hammerspoon/init.lua`.

Clone the repo into `~/.hammerspoon/warp-claude-hotkey`:

```bash
git clone https://github.com/timomak/warp-claude-hotkey.git ~/.hammerspoon/warp-claude-hotkey
```

Then add this line to `~/.hammerspoon/init.lua` (create the file if it doesn't exist):

```lua
_G.warpClaude = require("warp-claude-hotkey")
```

The `_G.` prefix is **required**. It stores the returned module table as a global so its `hs.application.watcher` isn't garbage-collected after `require` returns — without it, the app-scoping silently stops working after a few minutes.

Then reload: **Hammerspoon menu bar icon → Reload Config**

### 3. (Optional) Free up Cmd+Shift+D in Warp

Warp binds `Cmd+Shift+D` to "split pane down" by default. The Hammerspoon hotkey intercepts the keypress before Warp sees it, so this isn't strictly necessary — but if Hammerspoon is ever disabled, you'll want the default split behavior off the key to avoid surprise splits.

Edit `~/.warp/keybindings.yaml`:

```yaml
---
"pane_group:add_down": ctrl-shift-cmd-D
```

## Suggested shell alias

```bash
alias claude="claude --dangerously-skip-permissions --remote-control --effort max"
```

Drop that in your `~/.zshrc` / `~/.bashrc`. When Cmd+Shift+D fires, the new Warp pane types `claude` — with this alias it'll launch with your preferred flags.

## Troubleshooting

**Cmd+Shift+D / Cmd+Shift+A does nothing.**
Open the Hammerspoon Console (menu bar → Console) and press the shortcut. You should see `[warpClaudeHotkey] ok` or an error line. If there's nothing, the hotkey didn't bind — check for a syntax error on reload, or confirm Warp is the frontmost app (the hotkey is app-scoped).

**Pane splits but `claude` doesn't type, or types into the old pane.**
The `delay 0.5` between split and typing isn't enough for your machine. Bump it up to `0.7` or `1.0` in `runWarpClaude()`.

**Cmd+Shift+A: the follow-up command is dropped or arrives mid-boot.**
`CLAUDE_BOOT_DELAY` (top of `init.lua`, default `3.0`) is how long it waits after submitting `claude` before typing the follow-up. Bump it up if Claude takes longer than that to accept input on your machine.

**Random uppercase letters or Cmd+key shortcuts firing instead of typing.**
Your physical Shift/Cmd is leaking into the synthesized keystrokes. The `hs.timer.waitUntil` guard should prevent this — confirm you're on the version of the script that includes it.

**"System Events" permission denied.**
System Settings → Privacy & Security → Automation → Hammerspoon → ensure "System Events" is checked.

## How it works

1. `hs.hotkey` binds Cmd+Shift+D and Cmd+Shift+A globally, but an `hs.application.watcher` only enables the bindings while Warp is frontmost.
2. When fired, the callback waits until your physical Cmd and Shift are released (`hs.eventtap.checkKeyboardModifiers`). This prevents your held modifiers from contaminating the synthesized keystrokes.
3. Once released, AppleScript's `System Events` sends `Cmd+D` to Warp (native split-right, inherits cwd), waits 0.5s for the new pane to take focus, types `claude`, and presses Return. For Cmd+Shift+A, it then waits `CLAUDE_BOOT_DELAY` seconds for Claude's TUI to be ready, types the follow-up slash command, and presses Return again.

AppleScript is used instead of `hs.eventtap.keyStroke` because the latter's synthesized events are affected by physical modifier state on some macOS versions, whereas `System Events` `keystroke` is not.

## Related

- [mx-mouse-fix](https://github.com/timomak/mx-mouse-fix) — sibling Hammerspoon config that remaps Logitech MX Master side buttons to switch macOS desktops and open Mission Control.

The two configs are independent and can live side-by-side in the same `~/.hammerspoon/init.lua` — no conflicts.

## License

MIT
