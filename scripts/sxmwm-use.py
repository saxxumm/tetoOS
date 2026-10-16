#!/usr/bin/env python3
"""Point sxmwm's session config at tetoOS, or put it back.

    sxmwm-use.py use <shell dir>
    sxmwm-use.py revert <shell dir>

`use` copies ~/.config/sxmwm/config.toml to config.toml.bak-tetoos-<time>,
then rewrites the angelOS lines: the autostart entry, the right click on the
canvas, and every key that called `qs -c angelos ipc call angelos …`. Nothing
else in the file changes. sxmwm reloads its config on its own when the file
is written. `revert` copies the newest backup back.
"""

import glob
import os
import re
import shutil
import sys
import time

CONFIG = os.environ.get("TETOOS_SXMWM_CONFIG", os.path.expanduser("~/.config/sxmwm/config.toml"))

# angelOS call -> tetoOS call
CALLS = {
    "launcher": "launcher",
    "deskMenuHere": "deskMenuHere",
    "lock": "lock",
    "idle": "lock",
    "sidebar": "control",
    "settings shortcuts": "settings",
    "session": "power",
    "clipboard": "clipboard",
    "settings appearance": "settingsPage general",
    "theme toggle": "toggleMode",
    "settings wallpaper": "wallpapers",
    "widgets": "edit",
    "volumeUp": "volumeUp",
    "volumeDown": "volumeDown",
    "mute": "mute",
    "micMute": "micMute",
    "brightness up": "brightnessUp",
    "brightness down": "brightnessDown",
    "lyrics": "karaoke",
}


def use(shell):
    src = open(CONFIG).read()
    if "tetoos" in src and "angelos ipc call" not in src:
        print("config already points at tetoos")
        return 0
    backup = f"{CONFIG}.bak-tetoos-{time.strftime('%Y%m%d-%H%M%S')}"
    shutil.copy2(CONFIG, backup)

    tetoos = os.path.join(shell, "bin", "tetoos").replace(os.path.expanduser("~"), "~")
    out = src

    # autostart: angelOS out, tetoOS and its idle watcher in
    out = re.sub(r'^(\s*)"~/\.config/quickshell/angelos/bin/angelos start",',
                 lambda m: f'{m.group(1)}"{tetoos} start",\n{m.group(1)}"{tetoos} idle",',
                 out, flags=re.M)

    # workspaces went through angelOS's wrapper
    out = re.sub(r'"spawn ~/\.config/quickshell/angelos/bin/angelos ws (\d+)"',
                 lambda m: f'"spawn sxmwm msg workspace {m.group(1)}"', out)

    def call(m):
        what = m.group(1).strip()
        new = CALLS.get(what)
        if new is None:
            return f'"spawn true"  # was angelOS: {what}'
        return f'"spawn {tetoos} ipc {new}"'

    out = re.sub(r'"spawn qs -c angelos ipc call angelos ([^"]+)"', call, out)

    # A config that never had angelOS: add the autostart entries and the shell
    # keys that are still free, each into the table it belongs to.
    if f"{tetoos} start" not in out:
        out = re.sub(r'^autostart\s*=\s*\[', lambda m: m.group(0) + f'\n  "{tetoos} start",\n  "{tetoos} idle",',
                     out, count=1, flags=re.M)
        if f"{tetoos} start" not in out:
            out = f'autostart = ["{tetoos} start", "{tetoos} idle"]\n' + out
    wanted = [("mod+d", "launcher"), ("mod+n", "control"), ("mod+slash", "settings"),
              ("mod+shift+b", "wallpapers"), ("mod+shift+v", "clipboard"), ("mod+shift+e", "power"),
              ("mod+shift+d", "edit"), ("mod+shift+period", "toggleMode"), ("mod+alt+y", "karaoke"),
              ("mod+l", "lock"), ("xf86audioraisevolume", "volumeUp"), ("xf86audiolowervolume", "volumeDown"),
              ("xf86audiomute", "mute"), ("xf86audiomicmute", "micMute"),
              ("xf86monbrightnessup", "brightnessUp"), ("xf86monbrightnessdown", "brightnessDown")]
    free = [(k, fn) for k, fn in wanted if not re.search(r'^"' + re.escape(k) + r'"\s*=', out, flags=re.M)]
    if free:
        block = "\n".join(f'"{k}" = "spawn {tetoos} ipc {fn}"' for k, fn in free)
        if re.search(r'^\[keybindings\]\s*$', out, flags=re.M):
            out = re.sub(r'^\[keybindings\]\s*$', lambda m: m.group(0) + "\n# tetoOS\n" + block, out, count=1, flags=re.M)
        else:
            out += "\n[keybindings]\n# tetoOS\n" + block + "\n"
    if not re.search(r'^"right"\s*=', out, flags=re.M):
        line = f'"right" = "spawn {tetoos} ipc deskMenuHere"'
        if re.search(r'^\[mouse\.on-canvas\]\s*$', out, flags=re.M):
            out = re.sub(r'^\[mouse\.on-canvas\]\s*$', lambda m: m.group(0) + "\n" + line, out, count=1, flags=re.M)
        else:
            out += "\n[mouse.on-canvas]\n" + line + "\n"

    with open(CONFIG + ".tmp", "w") as f:
        f.write(out)
    os.replace(CONFIG + ".tmp", CONFIG)
    import difflib
    changed = sum(1 for l in difflib.unified_diff(src.splitlines(), out.splitlines(), lineterm="", n=0)
                  if l.startswith("+") and not l.startswith("+++"))
    print(f"config now starts tetoos ({changed} lines changed); backup: {backup}")
    print("log out and back in, or run `tetoos start` (stop any other shell first)")
    return 0


def revert(_shell):
    backups = sorted(glob.glob(CONFIG + ".bak-tetoos-*"))
    if not backups:
        print("no tetoos backup to restore")
        return 1
    shutil.copy2(backups[-1], CONFIG)
    print(f"restored {backups[-1]}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("use", "revert"):
        print(__doc__)
        sys.exit(2)
    sys.exit((use if sys.argv[1] == "use" else revert)(sys.argv[2]))
