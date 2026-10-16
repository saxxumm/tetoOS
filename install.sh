#!/usr/bin/env bash
# tetoOS installer.
#
#   ./install.sh                 ask before each step
#   ./install.sh --yes           take the defaults without asking
#   ./install.sh --compositor hyprland|sxmwm|none
#   ./install.sh --no-deps       skip system packages
#   ./install.sh --no-fonts      skip the Fredoka / Material Symbols download
#   ./install.sh --wallpapers    download the four Teto wallpapers (default: ask)
#   ./install.sh --no-wallpapers
#   ./install.sh --eq            install the ten-band PipeWire equalizer chain
#   ./install.sh --no-eq
#
# Everything it writes is under your home directory, except the packages.
# Configs it changes are backed up first (*.bak-tetoos-<time>), and
# `tetoos revert` takes the compositor hook out again.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/tetoos"
target="$config/quickshell/tetoos"

yes=0 deps=1 fonts=1 walls=ask eq=ask comp=auto
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) yes=1 ;;
        --no-deps) deps=0 ;;
        --no-fonts) fonts=0 ;;
        --wallpapers) walls=1 ;;
        --no-wallpapers) walls=0 ;;
        --eq) eq=1 ;;
        --no-eq) eq=0 ;;
        --compositor) comp="$2"; shift ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

pink=$'\e[38;5;204m' dim=$'\e[2m' bold=$'\e[1m' off=$'\e[0m'
say() { printf '%s✦%s %s\n' "$pink" "$off" "$*"; }
note() { printf '  %s%s%s\n' "$dim" "$*" "$off"; }
ask() {   # ask "question" default(y|n)
    local q=$1 def=${2:-y} a
    if [ "$yes" = 1 ]; then [ "$def" = y ]; return; fi
    read -r -p "  $q [$( [ "$def" = y ] && echo Y/n || echo y/N )] " a || a=""
    a=${a:-$def}
    [[ $a =~ ^[YyДд] ]]
}
stamp=$(date +%Y%m%d-%H%M%S)

printf '\n%s%s  tetoOS%s — a Kasane Teto desktop shell for Hyprland and sxmwm\n\n' "$bold" "$pink" "$off"

# --- 1. where the shell lives ---------------------------------------------------
mkdir -p "$config/quickshell"
if [ "$(readlink -f "$here")" != "$(readlink -f "$target" 2>/dev/null || true)" ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "$target.bak-tetoos-$stamp"
        note "moved the old $target aside"
    fi
    ln -s "$here" "$target"
    say "linked $target → $here"
else
    say "shell is in $target"
fi
chmod +x "$here/bin/tetoos" "$here"/scripts/*.py

# --- 2. packages ---------------------------------------------------------------------
want=(quickshell qt6-declarative qt6-5compat python python-pillow python-numpy
      ttf-fira-sans ttf-jetbrains-mono-nerd ttf-material-symbols-variable
      cava grim slurp wl-clipboard cliphist wf-recorder hyprpicker swayidle
      brightnessctl networkmanager bluez bluez-utils pipewire wireplumber
      pipewire-pulse libpulse libqalculate curl playerctl wlsunset)
if [ "$deps" = 1 ]; then
    if command -v pacman >/dev/null; then
        missing=() repo=() aur=()
        for p in "${want[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
        for p in "${missing[@]}"; do
            if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
        done
        if [ ${#missing[@]} -eq 0 ]; then
            say "all packages are already installed"
        else
            say "missing packages: ${missing[*]}"
            if [ ${#repo[@]} -gt 0 ] && ask "install ${#repo[@]} from the repos with sudo pacman?" y; then
                sudo pacman -S --needed "${repo[@]}"
            fi
            if [ ${#aur[@]} -gt 0 ]; then
                helper=$(command -v paru || command -v yay || true)
                if [ -n "$helper" ] && ask "install ${aur[*]} from the AUR with $(basename "$helper")?" y; then
                    "$helper" -S --needed "${aur[@]}"
                else
                    note "install these yourself: ${aur[*]}"
                fi
            fi
        fi
    else
        say "not an Arch-based system: install these (or your distro's names for them):"
        note "${want[*]}"
    fi
fi

# --- 3. fonts -----------------------------------------------------------------------------
if [ "$fonts" = 1 ]; then
    fdir="$data/fonts/tetoos"
    if ! fc-list | grep -qi fredoka; then
        if ask "download the Fredoka font (OFL, Google Fonts, ~160 KB)?" y; then
            mkdir -p "$fdir"
            curl -fsSL -o "$fdir/Fredoka-Variable.ttf" \
                'https://github.com/google/fonts/raw/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf' \
                && say "Fredoka installed" || note "download failed; the shell falls back to Fira Sans"
        fi
    fi
    if ! fc-list | grep -qi 'Material Symbols Rounded'; then
        if ask "download Material Symbols Rounded (Apache 2.0, ~5 MB)?" y; then
            mkdir -p "$fdir"
            curl -fsSL -o "$fdir/MaterialSymbolsRounded.ttf" \
                'https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf' \
                && say "Material Symbols installed" || note "download failed; icons will be missing"
        fi
    fi
    fc-cache -f "$data/fonts" >/dev/null 2>&1 || true
fi

# --- 4. wallpapers ----------------------------------------------------------------------------
wdir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/wallpapers/teto"
if [ "$walls" = ask ]; then ask "download four Kasane Teto wallpapers from wallhaven.cc (~16 MB)?" y && walls=1 || walls=0; fi
if [ "$walls" = 1 ]; then
    mkdir -p "$wdir"
    for u in https://w.wallhaven.cc/full/yq/wallhaven-yq2mdd.jpg \
             https://w.wallhaven.cc/full/gw/wallhaven-gwpxx3.png \
             https://w.wallhaven.cc/full/je/wallhaven-je9jop.png \
             https://w.wallhaven.cc/full/gw/wallhaven-gw71g7.png; do
        f="$wdir/$(basename "$u")"
        [ -f "$f" ] || curl -fsSL -o "$f" "$u" || note "could not fetch $u"
    done
    say "wallpapers in $wdir"
fi

# --- 5. first colours and settings -----------------------------------------------------------------
mkdir -p "$state"
if [ ! -f "$state/config.json" ]; then
    first="$wdir/wallhaven-yq2mdd.jpg"
    [ -f "$first" ] || first=$(ls "$wdir"/*.jpg "$wdir"/*.png 2>/dev/null | head -1 || true)
    [ -n "$first" ] && printf '{ "wallpaper": "%s", "wallpaperDir": "%s" }\n' "$first" "$(dirname "$wdir")" > "$state/config.json"
fi
if [ ! -f "$state/colors.json" ]; then
    pic=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$state/config.json" 2>/dev/null || true)
    if [ -n "$pic" ] && [ -f "$pic" ]; then
        TETOOS_STATE="$state" python3 -I "$here/scripts/palette.py" image "$pic"
    else
        TETOOS_STATE="$state" python3 -I "$here/scripts/palette.py" seed "#d13d5a" "#a986d6" "#9fd0ef"
    fi
    say "colours written"
fi

# --- 6. equalizer -------------------------------------------------------------------------------------
eqdir="$config/pipewire/filter-chain.conf.d"
have_eq=$(ls "$eqdir"/*eq*.conf 2>/dev/null | head -1 || true)
if [ "$eq" = ask ]; then
    if [ -n "$have_eq" ]; then
        note "an equalizer chain is already installed ($(basename "$have_eq")); tetoOS will drive it"
        eq=0
    else
        ask "install the ten-band PipeWire equalizer (filter-chain)?" y && eq=1 || eq=0
    fi
fi
if [ "$eq" = 1 ]; then
    mkdir -p "$eqdir"
    cp "$here/pipewire/99-tetoos-equalizer.conf" "$eqdir/"
    systemctl --user enable filter-chain.service >/dev/null 2>&1 || true
    systemctl --user restart filter-chain.service >/dev/null 2>&1 \
        && say "equalizer installed (pick 'tetoOS Equalizer' as the output, or use the Sound page)" \
        || note "copied to $eqdir; start it with: systemctl --user enable --now filter-chain.service"
fi

# --- 7. compositor ---------------------------------------------------------------------------------------
if [ "$comp" = auto ]; then
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -e "$config/hypr/hyprland.lua" ] || [ -e "$config/hypr/hyprland.conf" ]; then
        comp=hyprland
    elif command -v sxmwm >/dev/null || [ -e "$config/sxmwm/config.toml" ]; then
        comp=sxmwm
    else
        comp=none
    fi
fi
case "$comp" in
    hyprland|sxmwm)
        if ask "hook tetoOS into $comp's config (backup kept, undo with 'tetoos revert $comp')?" y; then
            "$here/bin/tetoos" use "$comp" || true
        fi ;;
    *)
        note "no Hyprland or sxmwm config found; run 'tetoos use hyprland' once Hyprland has made one" ;;
esac

# --- 8. a command on PATH -------------------------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sf "$here/bin/tetoos" "$HOME/.local/bin/tetoos"

printf '\n'
say "done. Start it now with:  ${bold}tetoos start${off}   (stop any other shell first)"
note "settings: Super+/ · launcher: Super+D · Teto: right-click her"
note "your own Teto frames go in $data/tetoos/teto/ (idle.png, talk.png, …)"
