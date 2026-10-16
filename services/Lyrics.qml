pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The line of the song being sung right now, from lrclib.net's synced lyrics.
//
// Asked once per track (artist, title, length) and cached in
// ~/.cache/tetoos/lyrics, so replaying an album costs nothing. Only the track
// name and artist leave the machine; turn it off in Settings → tetoOS.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.options.lyrics
    property var lines: []                 // [{ t: seconds, text }]
    property string status: ""             // "" | loading | none | ok
    property int index: -1
    readonly property string line: root.index >= 0 && root.index < root.lines.length ? root.lines[root.index].text : ""
    readonly property string next: root.index + 1 < root.lines.length ? root.lines[root.index + 1].text : ""
    readonly property bool has: root.lines.length > 0

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/tetoos/lyrics"
    readonly property string key: Media.artist + "\u0000" + Media.title

    // --- fetching -----------------------------------------------------------------
    property string asked: ""
    function fetch() {
        if (!root.enabled || !Media.has || Media.title === "") { root.lines = []; root.status = ""; return; }
        const k = root.key;
        if (k === root.asked) return;
        root.asked = k;
        root.lines = [];
        root.index = -1;
        root.status = "loading";
        getter.command = ["python3", "-I", Quickshell.shellDir + "/scripts/lyrics.py", root.cacheDir,
            Media.artist, Media.title, String(Math.round(Media.length))];
        getter.running = true;
    }

    Process {
        id: getter
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const raw of text.split("\n")) {
                    const m = raw.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
                    if (m) list.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3].trim() });
                }
                root.lines = list;
                root.status = list.length > 0 ? "ok" : "none";
            }
        }
    }

    Timer {
        id: debounce
        interval: 600
        onTriggered: root.fetch()
    }
    Connections {
        target: Media
        function onTitleChanged() { debounce.restart(); }
        function onArtistChanged() { debounce.restart(); }
    }
    onEnabledChanged: { root.asked = ""; debounce.restart(); }

    // --- following the song ---------------------------------------------------------------
    // MPRIS reports a position about once a second; between reports the clock
    // runs on here so a line changes on its beat rather than up to a second late.
    property real base: 0
    property double baseAt: 0
    Connections {
        target: Media
        function onPositionChanged() { root.base = Media.position; root.baseAt = Date.now(); }
    }
    Timer {
        running: root.has && Media.playing
        interval: 150
        repeat: true
        onTriggered: {
            const now = root.base + (Date.now() - root.baseAt) / 1000 + 0.25;
            let i = -1;
            for (let k = 0; k < root.lines.length; k++) {
                if (root.lines[k].t <= now) i = k; else break;
            }
            if (i !== root.index) root.index = i;
        }
    }
}
