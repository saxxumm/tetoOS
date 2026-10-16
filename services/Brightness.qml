pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Panel backlight, through logind rather than brightnessctl.
//
// /sys/class/backlight is root-owned and the `video` group alone does not make
// it writable, so a plain write fails. logind exposes SetBrightness on the
// active session for exactly this, it is allowed for the session sitting at the
// seat, and it needs no extra package or udev rule — which is why this shell
// has no brightnessctl dependency.
Singleton {
    id: root

    property string device: ""
    property int raw: 0
    property int max: 0
    readonly property bool available: root.device !== "" && root.max > 0
    readonly property real value: root.max > 0 ? root.raw / root.max : 0

    // Never all the way off: a backlight at zero looks exactly like a machine
    // that has crashed, and finding the key back is guesswork in the dark.
    readonly property real minimum: 0.02

    function set(fraction) {
        if (!root.available) return;
        const target = Math.round(Math.max(root.minimum, Math.min(1, fraction)) * root.max);
        root.raw = target;
        writer.command = [
            "busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetBrightness",
            "ssu", "backlight", root.device, String(target)
        ];
        writer.running = true;
    }

    function step(delta) {
        root.set(root.value + delta);
    }

    Process {
        id: writer
    }

    // Which backlight, and how far it goes. Read once: the device does not
    // change, and the current value is re-read below only when something else
    // might have moved it.
    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            "d=$(ls /sys/class/backlight 2>/dev/null | head -1); " +
            "[ -n \"$d\" ] && printf '%s %s %s' \"$d\" \"$(cat /sys/class/backlight/$d/max_brightness)\" \"$(cat /sys/class/backlight/$d/brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 3) return;
                root.device = parts[0];
                root.max = parseInt(parts[1]);
                root.raw = parseInt(parts[2]);
            }
        }
    }

    // A slow re-read, so the shell agrees with whatever else touched the
    // backlight — a lid sensor, a power profile, the firmware itself.
    Timer {
        running: root.available
        interval: 10000
        repeat: true
        onTriggered: reread.running = true
    }

    Process {
        id: reread
        command: ["sh", "-c", "cat /sys/class/backlight/" + root.device + "/brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v) && !writer.running) root.raw = v;
            }
        }
    }
}
