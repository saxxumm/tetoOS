pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What the output sounds like, as numbers: a bar per frequency band, read off
// cava's raw output.
//
// Nothing in Quickshell can do this on its own — a spectrum needs an FFT over
// the audio itself, and the shell never sees a sample. cava does exactly that
// job and nothing else, so this is a reader for it rather than an analyser.
//
// COST. cava wakes up `framerate` times a second and the shell repaints on every
// frame it sends, so this runs only while something is looking at it: the player
// menu sets `watchers` while it is open and drops it when it closes. Nobody
// watching means no process at all, not a paused one.
//
// WITHOUT CAVA there is still an honest thing to show. PipeWire will report a
// node's peak level to anyone who asks, which is one number rather than a
// spectrum — so the menu falls back to a level meter and says why, instead of
// drawing twenty-four bars out of one value and calling it an analyser.
Singleton {
    id: root

    readonly property int bars: 40
    readonly property int framerate: 30

    // 0..1 per bar, oldest frame until cava sends the next one.
    property var levels: []

    // Reference counted rather than a plain bool: the menu and anything else
    // that grows a visualiser later should not be able to switch each other off.
    property int watchers: 0
    readonly property bool wanted: root.watchers > 0

    function watch() { root.watchers++; }
    function unwatch() { root.watchers = Math.max(0, root.watchers - 1); }

    // Null until the probe has answered, so the menu can say "checking" rather
    // than flashing an install hint at every open.
    property var available: null

    readonly property bool running: root.available === true && root.wanted

    // --- the peak fallback --------------------------------------------------
    // Audio's daemon-backed answer, not Quickshell's default sink: a meter on the
    // sink nothing is playing to reads zero and looks broken.
    readonly property var sink: Audio.currentSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    PwNodePeakMonitor {
        id: monitor
        node: root.sink
        // Only while there is no spectrum to show instead: the peak monitor is
        // cheap, but it is still a stream into the graph.
        enabled: root.wanted && root.available === false
    }

    readonly property real peak: monitor.enabled ? monitor.peak : 0

    // --- cava ---------------------------------------------------------------
    Process {
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() === "yes"
        }
    }

    // cava has no command line for any of this; a config file is the only way to
    // ask for raw output. Written into the state directory rather than
    // ~/.config/cava, which belongs to the user's own cava.
    readonly property string configPath: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/cava.conf"

    FileView {
        id: config
        path: root.configPath
        preload: true
        atomicWrites: true
        printErrors: false
        Component.onCompleted: config.setText(
            "# Written by the shell. Edit quickshell/services/Spectrum.qml, not this.\n" +
            "[general]\n" +
            "framerate = " + root.framerate + "\n" +
            "bars = " + root.bars + "\n" +
            "autosens = 1\n" +
            "[input]\n" +
            // The default sink's monitor, whichever sink that is — including the
            // equalizer's, so the bars show the curve doing its work.
            "method = pipewire\n" +
            "source = auto\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 100\n" +
            // One set of bars rather than one per channel: the strip is a
            // spectrum, not a stereo display.
            "channels = mono\n"
        )
    }

    Process {
        id: cava
        running: root.running
        command: ["cava", "-p", root.configPath]

        // One frame per line, bar values separated by semicolons: "4;17;39;…;".
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const fields = line.split(";");
                const next = [];
                for (const f of fields) {
                    if (f === "") continue;          // the trailing separator
                    const v = parseInt(f, 10);
                    next.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100)));
                }
                if (next.length > 0) root.levels = next;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("cava:", text.trim());
        }

        // A stopped visualiser should not leave its last frame frozen on screen
        // the next time the menu opens.
        onRunningChanged: if (!cava.running) root.levels = []
    }
}
