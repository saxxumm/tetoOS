#!/usr/bin/env python3
"""Mini Teto's pixel frames, 29x31 art pixels each.

    teto-sprites.py <out dir> [--preview file.png]

BASE is mini Teto as drawn by saxxumm, pixel for pixel. Every other frame is
that drawing with a few cells of the face changed (a blink, a smile, a mouth)
or a baguette laid over it; nothing else of the drawing is touched.
"""
import os
import sys

PAL = {
    "#": "#e81e46",   # hair
    "A": "#010001",   # ink
    "B": "#b51d36",   # hair shade
    "C": "#fee2d0",   # skin
    "D": "#36474f",   # coat
    "E": "#273238",   # coat shade
    "F": "#e67883",   # hair shine
    "G": "#fe8b80",   # hair over skin
    "H": "#f9bbd0",   # blush
    "I": "#5e1422",   # eye
    "J": "#222022",   # boot
    "K": "#ecb862",   # bread
    "L": "#b97b2c",   # bread crust
    "M": "#f8dea4",   # bread crumb
    "N": "#8a1e30",   # mouth
}

BASE = [
    ".............................",
    "..............A..............",
    ".............A#A.............",
    "............A#A..............",
    "..........AAAA#AAAA..........",
    "...AAAAA.A#########A.AAAAA...",
    "..A#####A#FF#FFF#FF#A#####A..",
    "..A####B#F#########F#B####A..",
    "..ABBBBBB#B#####B#B#BBBBBBA..",
    "...ABBBB#B##B###BB#B#BBBBA...",
    "...A###BB##BGB#BGGB#BB###A...",
    "...ABBBB#BBIGB#BCIGB#BBBBA...",
    "....ABBBBBGBCGBGCBCBBBBBA....",
    "....A##B#BC#CCGCC#CB#B##A....",
    "....ABBAABHHCCCCCHHBAA#BA....",
    ".....A#A.BACCCCCCCAB.A#A.....",
    "......A....AAAAAAA....A......",
    "............ADCDA............",
    "...........ACD#DCA...........",
    "..........ACDD#DDCA..........",
    ".........A##DEBED##A.........",
    ".........AEDDD#DDDEA.........",
    "........AEEDDD#DDDEEA........",
    "........A#BEEEEEEEB#A........",
    ".........AABDEDEDBAA.........",
    "...........A#####A...........",
    "...........AJA.AJA...........",
    "...........A#A.A#A...........",
    "...........AAA.AAA...........",
    ".............................",
    ".............................",
]

W, H = 29, 31

# the face, as (row, column)
EYE_TOP = 11
LEFT_EYE = 11
RIGHT_EYE = 17
MOUTH = (15, 14)


def grid():
    return [list(line) for line in BASE]


def put(g, r, c, ch):
    if 0 <= r < H and 0 <= c < W:
        g[r][c] = ch


def eye(g, col, kind):
    t = EYE_TOP
    if kind == "closed":
        put(g, t, col, "G")
        put(g, t + 1, col, "I")
    elif kind == "happy":
        put(g, t, col, "I")
        put(g, t + 1, col - 1, "I")
        put(g, t + 1, col, "C")
        put(g, t + 1, col + 1, "I")
    elif kind == "wide":
        put(g, t, col, "I")
        put(g, t + 1, col, "I")
        put(g, t, col + 1, "I")
        put(g, t + 1, col + 1, "B")


def mouth(g, kind):
    r, c = MOUTH
    if kind == "open":
        put(g, r, c, "N")
    elif kind == "wide":
        for d in (-1, 0, 1):
            put(g, r, c + d, "N")
    elif kind == "o":
        put(g, r, c, "I")


def bread(g):
    """A baguette held up to the mouth, across the coat from the left."""
    cells = [(20, 7), (19, 8), (18, 9), (17, 10), (16, 11), (15, 12)]
    for i, (r, c) in enumerate(cells):
        put(g, r, c, "M" if i % 2 else "K")
        put(g, r, c + 1, "K")
        put(g, r + 1, c, "L")
    for r in range(H):
        for c in range(W):
            if g[r][c] != ".":
                continue
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                rr, cc = r + dr, c + dc
                if 0 <= rr < H and 0 <= cc < W and g[rr][cc] in "KLM":
                    g[r][c] = "A"
                    break


def frame(eyes="open", mouth_kind="", loaf=False, right=None):
    g = grid()
    eye(g, LEFT_EYE, eyes)
    eye(g, RIGHT_EYE, right or eyes)
    if mouth_kind:
        mouth(g, mouth_kind)
    if loaf:
        bread(g)
    return g


FRAMES = {
    "idle": dict(),
    "blink": dict(eyes="closed"),
    "talk": dict(mouth_kind="open"),
    "happy": dict(eyes="happy", mouth_kind="open"),
    "sleep": dict(eyes="closed"),
    "shock": dict(eyes="wide", mouth_kind="o"),
    "dizzy": dict(eyes="closed", mouth_kind="o"),
    "cheer": dict(eyes="happy", mouth_kind="wide"),
    "wink": dict(eyes="open", right="happy", mouth_kind="open"),
    "eat": dict(mouth_kind="o", loaf=True),
    "chew": dict(eyes="happy", mouth_kind="open", loaf=True),
}


def to_image(g):
    from PIL import Image
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for r in range(H):
        for c in range(W):
            ch = g[r][c]
            if ch in PAL:
                col = PAL[ch]
                im.putpixel((c, r), tuple(int(col[i:i + 2], 16) for i in (1, 3, 5)) + (255,))
    return im


def main(argv):
    out = argv[1] if len(argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for line in BASE:
        assert len(line) == W, line
    assert len(BASE) == H
    imgs = []
    for name, kw in FRAMES.items():
        im = to_image(frame(**kw))
        im.save(os.path.join(out, name + ".png"))
        imgs.append(im)
    if "--preview" in argv:
        from PIL import Image
        p = argv[argv.index("--preview") + 1]
        s = 8
        sheet = Image.new("RGBA", (len(imgs) * (W * s + 8), H * s), (187, 222, 250, 255))
        for i, im in enumerate(imgs):
            sheet.alpha_composite(im.resize((W * s, H * s), Image.NEAREST), (i * (W * s + 8), 0))
        sheet.save(p)
    print(" ".join(FRAMES))


if __name__ == "__main__":
    main(sys.argv)
