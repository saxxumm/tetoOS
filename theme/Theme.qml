pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services"

// Every colour, size and duration the shell uses.
//
// The colours are not written here. scripts/palette.py reads the wallpaper and
// writes ~/.local/state/tetoos/colors.json with a light and a dark set of the
// same roles; this file watches it and eases every role to its new value, so a
// new wallpaper repaints the whole desk in one sweep rather than in a flicker.
//
// The look is a sticker sheet: every surface is a pale fill inside a thick ink
// outline with a hard shadow under it, and the ink is the wallpaper's own hue
// pushed dark rather than black.
Singleton {
    id: root

    // --- mode ---------------------------------------------------------------
    // auto: dark at night, or all day on a dark wallpaper
    readonly property bool nightHours: Sys.now.getHours() >= 20 || Sys.now.getHours() < 7
    readonly property bool dark: Config.ready && (Config.options.mode === "dark"
        || (Config.options.mode === "auto" && (root.suggestDark || root.nightHours)))
    property bool suggestDark: false
    property var hues: [7.5, 300, 205]
    property string source: ""

    // --- colour roles ---------------------------------------------------------
    // Teto until the file is read: crimson ink on rose paper.
    property color paper: "#fff8f8"
    property color paper2: "#fbecee"
    property color paper3: "#f6dde1"
    property color ink: "#5a1f2b"
    property color text: "#521c27"
    property color textSoft: "#7f5560"
    property color primary: "#f6c9cf"
    property color primaryStrong: "#d6425f"
    property color strongText: "#fffafa"
    property color secondary: "#dccbf3"
    property color secondaryStrong: "#8f6bc9"
    property color tertiary: "#bfe1f6"
    property color tertiaryStrong: "#3b93c4"
    property color night: "#4b1b25"
    property color night2: "#61283a"
    property color nightText: "#fff3f4"
    property color nightSoft: "#e2b8c0"
    property color good: "#8fd99a"
    property color warn: "#f1cf6b"
    property color bad: "#e2454f"
    property color shadow: "#5a1f2b"

    readonly property var roles: ["paper", "paper2", "paper3", "ink", "text", "textSoft",
        "primary", "primaryStrong", "strongText", "secondary", "secondaryStrong",
        "tertiary", "tertiaryStrong", "night", "night2", "nightText", "nightSoft",
        "good", "warn", "bad", "shadow"]

    // Easing every role at once is one property animation per role; cheap,
    // and it only runs for the half second after a wallpaper change.
    Behavior on paper { ColorAnimation { duration: root.recolor } }
    Behavior on paper2 { ColorAnimation { duration: root.recolor } }
    Behavior on paper3 { ColorAnimation { duration: root.recolor } }
    Behavior on ink { ColorAnimation { duration: root.recolor } }
    Behavior on text { ColorAnimation { duration: root.recolor } }
    Behavior on textSoft { ColorAnimation { duration: root.recolor } }
    Behavior on primary { ColorAnimation { duration: root.recolor } }
    Behavior on primaryStrong { ColorAnimation { duration: root.recolor } }
    Behavior on strongText { ColorAnimation { duration: root.recolor } }
    Behavior on secondary { ColorAnimation { duration: root.recolor } }
    Behavior on secondaryStrong { ColorAnimation { duration: root.recolor } }
    Behavior on tertiary { ColorAnimation { duration: root.recolor } }
    Behavior on tertiaryStrong { ColorAnimation { duration: root.recolor } }
    Behavior on night { ColorAnimation { duration: root.recolor } }
    Behavior on night2 { ColorAnimation { duration: root.recolor } }
    Behavior on nightText { ColorAnimation { duration: root.recolor } }
    Behavior on nightSoft { ColorAnimation { duration: root.recolor } }
    Behavior on shadow { ColorAnimation { duration: root.recolor } }

    property var scheme: null

    function apply() {
        if (!root.scheme) return;
        const set = root.dark ? root.scheme.dark : root.scheme.light;
        if (!set) return;
        for (const role of root.roles) if (set[role]) root[role] = set[role];
    }
    onDarkChanged: root.apply()

    FileView {
        id: colors
        path: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: colors.reload()
        onLoaded: {
            try {
                const data = JSON.parse(colors.text());
                root.suggestDark = !!data.suggestDark;
                root.hues = data.hues || root.hues;
                root.source = data.source || "";
                root.scheme = data;
                root.apply();
            } catch (e) {
                console.warn("tetoos: unreadable colors.json:", e);
            }
        }
    }

    // --- helpers --------------------------------------------------------------
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // --- type -----------------------------------------------------------------
    readonly property string font: "Fredoka"
    readonly property string fontAlt: "Fira Sans"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "Material Symbols Rounded"

    // --- metrics --------------------------------------------------------------
    readonly property int outline: 2
    readonly property int lift: 3          // how far the hard shadow drops
    readonly property int radius: 14
    readonly property int radiusSmall: 9
    readonly property int pill: 999
    readonly property int gap: 8
    readonly property int barHeight: 34

    // --- motion ---------------------------------------------------------------
    readonly property int recolor: 650
    readonly property int quick: 140
    readonly property int normal: 260
    readonly property int slow: 420
    readonly property var bouncy: [0.34, 1.56, 0.64, 1, 1, 1]
}
