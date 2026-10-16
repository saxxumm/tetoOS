pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with wf-recorder: the whole output, into ~/Видео/Screencasts.
// The bar shows a red pill with the time while it runs; clicking it stops.
Singleton {
    id: root

    property bool recording: rec.running
    property double since: 0
    property string file: ""
    property int elapsed: 0
    readonly property string clock: Math.floor(root.elapsed / 60) + ":" + String(root.elapsed % 60).padStart(2, "0")

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed = Math.floor((Date.now() - root.since) / 1000)
    }

    function toggle() { root.recording ? root.stop() : root.start(); }

    function start() {
        if (rec.running) return;
        dirProbe.running = true;
    }
    function stop() {
        if (rec.running) rec.signal(2);      // SIGINT: wf-recorder finishes the file
    }

    Process {
        id: dirProbe
        // a nested test session records into /tmp, not into your videos
        command: ["sh", "-c", Quickshell.env("TETOOS_NESTED") === "1" ? "d=/tmp/tetoos-rec; mkdir -p \"$d\"; echo \"$d\""
            : "d=$(xdg-user-dir VIDEOS 2>/dev/null || echo \"$HOME/Videos\")/Screencasts; mkdir -p \"$d\"; echo \"$d\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.file = text.trim() + "/tetoOS-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
                root.since = Date.now();
                root.elapsed = 0;
                rec.command = ["wf-recorder", "-y", "-f", root.file];
                rec.running = true;
                Sfx.play("pop", 0.8);
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "media-record", "Started recording this monitor", "Click the red pill on the bar to stop"]);
            }
        }
    }

    Process {
        id: rec
        onExited: (code, status) => {
            Sfx.play("pop", 1.2);
            Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "video-x-generic", "Recording saved", root.file]);
        }
    }
}
