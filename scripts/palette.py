#!/usr/bin/env python3
"""tetoOS palette generator.

Reads a wallpaper, finds the hues that carry it and writes the shell's scheme:
a light and a dark set of the same roles, every one of them picked in OKLCH so
that a red wallpaper and a teal one come out equally legible.

    palette.py image <path> [--out FILE]
    palette.py seed <#hex> [<#hex> ...] [--out FILE]
    palette.py thumbs <dir> [--size 480]

The shell watches the output file and repaints itself when it changes.
"""

import hashlib
import json
import math
import os
import sys

STATE = os.environ.get("TETOOS_STATE") or os.path.expanduser("~/.local/state/tetoos")
OUT = os.path.join(STATE, "colors.json")
THUMBS = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "tetoos", "thumbs")


# --- colour maths -----------------------------------------------------------

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def rgb_to_oklab(r, g, b):
    r, g, b = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_to_rgb(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def oklch_to_hex(L, C, h):
    """OKLCH to #rrggbb, pulling chroma in until the colour fits sRGB."""
    lo, hi = 0.0, C
    best = None
    for _ in range(24):
        c = hi if best is None else (lo + hi) / 2
        a, b = c * math.cos(math.radians(h)), c * math.sin(math.radians(h))
        rgb = oklab_to_rgb(L, a, b)
        if all(-1e-4 <= x <= 1 + 1e-4 for x in rgb):
            best = rgb
            if c == hi:
                break
            lo = c
        else:
            hi = c if best is not None else hi * 0.5
            if best is None and hi < 1e-4:
                best = oklab_to_rgb(L, 0, 0)
                break
    if best is None:
        best = oklab_to_rgb(L, 0, 0)
    out = [max(0, min(1, linear_to_srgb(max(0.0, x)))) for x in best]
    return "#%02x%02x%02x" % tuple(round(x * 255) for x in out)


def hex_to_oklch(value):
    value = value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    L, a, bb = rgb_to_oklab(r, g, b)
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


# --- reading a wallpaper ----------------------------------------------------

BINS = 72


def hue_profile(path):
    from PIL import Image

    img = Image.open(path)
    img.draft("RGB", (320, 180))
    img = img.convert("RGB")
    img.thumbnail((160, 160))
    hist = [0.0] * BINS
    total_c, total_w, total_l, n = 0.0, 0.0, 0.0, 0
    for r, g, b in (img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()):
        L, a, bb = rgb_to_oklab(r / 255, g / 255, b / 255)
        C = math.hypot(a, bb)
        total_l += L
        n += 1
        if C < 0.03 or L < 0.18 or L > 0.97:
            continue
        w = C ** 1.5 * (1 - abs(L - 0.62))
        h = math.degrees(math.atan2(bb, a)) % 360
        hist[int(h / (360 / BINS)) % BINS] += w
        total_c += C * w
        total_w += w
    # circular smoothing
    sm = [0.0] * BINS
    for i in range(BINS):
        for d in range(-3, 4):
            sm[i] += hist[(i + d) % BINS] * math.exp(-(d * d) / 4.5)
    mean_c = total_c / total_w if total_w else 0.0
    return sm, mean_c, (total_l / n if n else 0.5), (total_w / n if n else 0.0)


def peaks(hist, count=3, gap_deg=40):
    hist = list(hist)
    found = []
    first = max(range(BINS), key=lambda k: hist[k])
    # Skin tones (orange-beige, 40-72 deg) are in almost every illustration and
    # almost never what the picture is "about": they may lead, but they are
    # damped as an accent so a character's hair or eyes win the second slot.
    for i in range(BINS):
        deg = (i + 0.5) * 360 / BINS
        if 40 <= deg <= 72 and abs(i - first) > 2:
            hist[i] *= 0.45
    gap = int(gap_deg / (360 / BINS))
    top = max(hist) or 1
    for _ in range(count):
        i = max(range(BINS), key=lambda k: hist[k])
        if hist[i] <= 0:
            break
        found.append(((i + 0.5) * 360 / BINS, hist[i] / top))
        for d in range(-gap, gap + 1):
            hist[(i + d) % BINS] = 0
    return found


FALLBACK_HUES = [300.0, 205.0, 350.0, 150.0, 60.0]


def circular(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


# --- the scheme -------------------------------------------------------------

def scheme(h1, h2, h3, vivid):
    """Both modes from three hues. `vivid` (0.35..1) scales every chroma."""

    def c(x):
        return x * vivid

    def k(L, C, h):
        return oklch_to_hex(L, C, h)

    light = {
        "paper": k(0.985, c(0.012), h1),
        "paper2": k(0.955, c(0.026), h1),
        "paper3": k(0.915, c(0.042), h1),
        "ink": k(0.33, c(0.075), h1),
        "text": k(0.30, c(0.07), h1),
        "textSoft": k(0.50, c(0.06), h1),
        "primary": k(0.865, c(0.085), h1),
        "primaryStrong": k(0.62, c(0.17), h1),
        "strongText": k(0.99, 0.005, h1),
        "secondary": k(0.85, c(0.075), h2),
        "secondaryStrong": k(0.60, c(0.14), h2),
        "tertiary": k(0.86, c(0.09), h3),
        "tertiaryStrong": k(0.64, c(0.16), h3),
        "night": k(0.32, c(0.06), h1),
        "night2": k(0.40, c(0.07), h1),
        "nightText": k(0.97, c(0.015), h1),
        "nightSoft": k(0.80, c(0.04), h1),
        "good": k(0.80, 0.14, 150),
        "warn": k(0.84, 0.14, 85),
        "bad": k(0.66, 0.19, 25),
        "shadow": k(0.33, c(0.075), h1),
    }
    # Dark is not light inverted: cards sit a step above a near-black ink,
    # fills that mark "on" are mid-tone and saturated enough to read as colour
    # under light text, and the status colours drop so light text stays legible.
    dark = {
        "paper": k(0.255, c(0.028), h1),
        "paper2": k(0.30, c(0.034), h1),
        "paper3": k(0.355, c(0.04), h1),
        "ink": k(0.13, c(0.03), h1),
        "text": k(0.95, c(0.018), h1),
        "textSoft": k(0.74, c(0.045), h1),
        "primary": k(0.52, c(0.14), h1),
        "primaryStrong": k(0.74, c(0.16), h1),
        "strongText": k(0.17, c(0.04), h1),
        "secondary": k(0.48, c(0.10), h2),
        "secondaryStrong": k(0.76, c(0.12), h2),
        "tertiary": k(0.50, c(0.09), h3),
        "tertiaryStrong": k(0.78, c(0.12), h3),
        "night": k(0.20, c(0.035), h1),
        "night2": k(0.27, c(0.042), h1),
        "nightText": k(0.95, c(0.018), h1),
        "nightSoft": k(0.74, c(0.045), h1),
        "good": k(0.58, 0.13, 150),
        "warn": k(0.60, 0.12, 80),
        "bad": k(0.58, 0.17, 25),
        "shadow": k(0.07, c(0.02), h1),
    }
    return light, dark


def from_image(path):
    hist, mean_c, mean_l, colourful = hue_profile(path)
    found = peaks(hist)
    if not found:
        # A grey wallpaper: a quiet blue-grey scheme rather than a loud guess.
        h1, h2, h3, vivid = 250.0, 300.0, 200.0, 0.35
    else:
        h1 = found[0][0]
        chosen = [h1]
        for hue, weight in found[1:]:
            if weight > (0.12 if len(chosen) == 1 else 0.08):
                chosen.append(hue)
        # A picture with one colour in it still gets three: the pastel trio
        # the original rice wore (lavender, pink, sky), minus whichever of them
        # sits on top of a hue already taken.
        for hue in FALLBACK_HUES:
            if len(chosen) >= 3:
                break
            if all(circular(hue, other) >= 45 for other in chosen):
                chosen.append(hue)
        h2, h3 = chosen[1], chosen[2]
        vivid = max(0.35, min(1.0, mean_c / 0.09 + colourful * 4))
    light, dark = scheme(h1, h2, h3, vivid)
    return {
        "source": "wallpaper",
        "wallpaper": os.path.abspath(path),
        "hues": [round(h1, 1), round(h2, 1), round(h3, 1)],
        "vivid": round(vivid, 3),
        "suggestDark": mean_l < 0.42,
        "light": light,
        "dark": dark,
    }


def from_seeds(seeds):
    hues = [hex_to_oklch(s) for s in seeds]
    h1 = hues[0][2]
    chosen = [h for _, _, h in hues[:3]]
    for hue in FALLBACK_HUES:
        if len(chosen) >= 3:
            break
        if all(circular(hue, other) >= 45 for other in chosen):
            chosen.append(hue)
    h2, h3 = chosen[1], chosen[2]
    vivid = max(0.45, min(1.0, hues[0][1] / 0.13))
    light, dark = scheme(h1, h2, h3, vivid)
    return {
        "source": "seed",
        "seeds": seeds,
        "hues": [round(h1, 1), round(h2, 1), round(h3, 1)],
        "vivid": round(vivid, 3),
        "suggestDark": False,
        "light": light,
        "dark": dark,
    }


def write(data, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, out)


def thumbs(directory, size):
    from PIL import Image

    os.makedirs(THUMBS, exist_ok=True)
    made = 0
    for root, _, files in os.walk(os.path.expanduser(directory)):
        for name in sorted(files):
            if not name.lower().endswith((".png", ".jpg", ".jpeg", ".webp", ".bmp")):
                continue
            src = os.path.join(root, name)
            st = os.stat(src)
            key = hashlib.sha1(f"{src}:{st.st_mtime_ns}:{size}".encode()).hexdigest()[:20]
            dst = os.path.join(THUMBS, key + ".jpg")
            if not os.path.exists(dst):
                try:
                    img = Image.open(src)
                    img.draft("RGB", (size * 2, size * 2))
                    img = img.convert("RGB")
                    img.thumbnail((size, size))
                    img.save(dst, "JPEG", quality=86)
                    made += 1
                except Exception as e:  # a broken file is skipped, not fatal
                    print(f"skip {src}: {e}", file=sys.stderr)
                    continue
            print(json.dumps({"path": src, "thumb": dst, "name": name}))
    print(f"made {made}", file=sys.stderr)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    out = OUT
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        del argv[i:i + 2]
    cmd = argv[1]
    if cmd == "image":
        write(from_image(argv[2]), out)
    elif cmd == "seed":
        write(from_seeds(argv[2:]), out)
    elif cmd == "thumbs":
        size = 480
        if "--size" in argv:
            size = int(argv[argv.index("--size") + 1])
        thumbs(argv[2], size)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
