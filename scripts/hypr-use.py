#!/usr/bin/env python3
"""Hook tetoOS into Hyprland's config, or take it out again.

    hypr-use.py use <shell dir>
    hypr-use.py revert <shell dir>

Hyprland 0.55+ reads ~/.config/hypr/hyprland.lua; older ones hyprland.conf.
`use` writes tetoos.lua (or tetoos.conf) next to it with the shell's path
filled in, backs the main file up as <file>.bak-tetoos-<time>, and appends two
lines — a marker comment and the require/source. `revert` removes exactly
those two lines and the tetoos file. Nothing else in your config is touched.
"""
import os
import shutil
import sys
import time

HYPR = os.environ.get("TETOOS_HYPR_DIR") or os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "hypr")
MARK = "tetoOS"


def files():
    lua = os.path.join(HYPR, "hyprland.lua")
    conf = os.path.join(HYPR, "hyprland.conf")
    if os.path.exists(lua):
        return "lua", lua, os.path.join(HYPR, "tetoos.lua"), [f"-- {MARK}", 'pcall(require, "tetoos")']
    if os.path.exists(conf):
        return "conf", conf, os.path.join(HYPR, "tetoos.conf"), [f"# {MARK}", "source = " + os.path.join(HYPR, "tetoos.conf")]
    return None, None, None, None


def use(shell):
    kind, main, ours, lines = files()
    if not kind:
        print(f"no hyprland.lua or hyprland.conf in {HYPR}.")
        print("Start Hyprland once so it writes its default config, then run `tetoos use hyprland` again.")
        return 1
    template = os.path.join(shell, "hypr", "tetoos." + kind)
    binary = os.path.join(shell, "bin", "tetoos")
    with open(template) as f:
        text = f.read().replace("@TETOOS@", binary)
    with open(ours, "w") as f:
        f.write(text)
    with open(main) as f:
        current = f.read()
    if lines[1] in current:
        print(f"{main} already loads tetoOS; refreshed {ours}")
        return 0
    backup = f"{main}.bak-tetoos-{time.strftime('%Y%m%d-%H%M%S')}"
    shutil.copy2(main, backup)
    with open(main, "a") as f:
        if not current.endswith("\n"):
            f.write("\n")
        f.write("\n" + "\n".join(lines) + "\n")
    print(f"wrote {ours}; {main} now loads it (backup: {backup})")
    print("Hyprland reloads its config on save. If tetoOS is not up, log out and back in,")
    print("or run: " + binary + " start")
    return 0


def revert(_shell):
    kind, main, ours, lines = files()
    if not kind:
        print("no Hyprland config found")
        return 1
    with open(main) as f:
        keep = [l for l in f.read().split("\n") if l.strip() not in lines]
    # drop the blank line the append left behind, if it is now trailing
    while len(keep) > 1 and keep[-1] == "" and keep[-2] == "":
        keep.pop()
    text = "\n".join(keep)
    # if nothing else changed since `use`, put the backup back byte for byte
    import glob
    backups = sorted(glob.glob(main + ".bak-tetoos-*"))
    if backups:
        with open(backups[-1]) as f:
            before = f.read()
        if before.rstrip() == text.rstrip():
            text = before
    with open(main, "w") as f:
        f.write(text)
    if os.path.exists(ours):
        os.remove(ours)
    print(f"tetoOS taken out of {main}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("use", "revert"):
        print(__doc__)
        sys.exit(2)
    sys.exit((use if sys.argv[1] == "use" else revert)(sys.argv[2]))
