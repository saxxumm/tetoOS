-- tetoOS for Hyprland 0.55+ (hyprland.lua).
--
-- The installer copies this to ~/.config/hypr/tetoos.lua with the path to the
-- shell filled in, and adds one line to hyprland.lua:
--
--     pcall(require, "tetoos")
--
-- pcall keeps a missing or broken file from stopping the rest of your config.
-- Only shell keys are bound here; windows, workspaces and your own keys stay
-- yours. Rebind anything below that clashes with them.

local tetoos = "@TETOOS@"

local function ipc(fn)
  return hl.dsp.exec_cmd(tetoos .. " ipc " .. fn)
end

hl.on("hyprland.start", function()
  hl.exec_cmd(tetoos .. " start")
  hl.exec_cmd(tetoos .. " idle")
  -- clipboard history for the launcher's "clip" mode
  hl.exec_cmd("sh -c 'command -v cliphist >/dev/null && exec wl-paste --watch cliphist store'")
end)

-- the phone
hl.bind("SUPER + D", ipc("launcher"), { description = "tetoOS: launcher" })
hl.bind("SUPER + N", ipc("control"), { description = "tetoOS: control centre" })
hl.bind("SUPER + slash", ipc("settings"), { description = "tetoOS: settings" })
hl.bind("SUPER + SHIFT + B", ipc("wallpapers"), { description = "tetoOS: wallpapers" })
hl.bind("SUPER + SHIFT + V", ipc("clipboard"), { description = "tetoOS: clipboard" })
hl.bind("SUPER + SHIFT + E", ipc("power"), { description = "tetoOS: power menu" })
hl.bind("SUPER + ALT + S", ipc("settingsPage general"), { description = "tetoOS: look" })

-- the desktop
hl.bind("SUPER + SHIFT + D", ipc("edit"), { description = "tetoOS: edit desktop" })
hl.bind("SUPER + SHIFT + period", ipc("toggleMode"), { description = "tetoOS: light / dark" })
hl.bind("SUPER + ALT + Y", ipc("karaoke"), { description = "tetoOS: Teto karaoke" })
hl.bind("SUPER + L", ipc("lock"), { description = "tetoOS: lock" })

-- keys on the keyboard itself: the shell shows the change
hl.bind("XF86AudioRaiseVolume", ipc("volumeUp"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", ipc("volumeDown"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", ipc("mute"), { locked = true })
hl.bind("XF86AudioMicMute", ipc("micMute"), { locked = true })
hl.bind("XF86MonBrightnessUp", ipc("brightnessUp"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", ipc("brightnessDown"), { repeating = true, locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
