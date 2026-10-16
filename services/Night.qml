pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The night light: the panel's colour temperature, warmed after dark.
//
// sxmwm serves wlr-gamma-control, so any of the usual clients can do this and
// none of it belongs in the shell — what belongs here is the switch, the
// temperature, and knowing which of them is installed. wlsunset is preferred
// over gammastep because it needs no location service to be useful: told a
// temperature and told to hold it, it holds it.
//
// `-S` and `-s` (sunrise and sunset as fixed times) rather than coordinates on
// purpose. Geoclue on this machine answers slowly or not at all, and a night
// light that comes on at an hour nobody can predict gets turned off for good.
Singleton {
    id: root

    property bool enabled: false
    // Kelvin. 6500 is the panel's own white; 4000 is the usual evening warmth,
    // and below 3000 everything starts looking like a sepia photograph.
    property int temperature: 4000
    property string backend: ""

    readonly property bool available: root.backend !== ""
    readonly property var steps: [6000, 5000, 4500, 4000, 3500, 3000, 2500]

    function toggle() { root.enabled ? root.off() : root.on(); }

    function on() {
        if (!root.available) {
            warn.command = ["notify-send", "-a", "SXmWM", "-u", "critical",
                            "No night light", "Install wlsunset or gammastep"];
            warn.running = true;
            return;
        }
        root.enabled = true;
        root.apply();
        state.save();
    }

    function off() {
        root.enabled = false;
        stopper.running = true;
        state.save();
    }

    function setTemperature(k) {
        root.temperature = Math.round(Math.max(2000, Math.min(6500, k)));
        state.save();
        if (root.enabled) root.apply();
    }

    // Restarted rather than signalled: neither client has a way to be told a
    // new temperature while it runs, and both are a few hundred kilobytes that
    // start in milliseconds.
    function apply() {
        const t = String(root.temperature);
        const cmd = root.backend === "wlsunset"
            // Sunrise and sunset one minute apart at midnight means "night, all
            // day": the high temperature is never reached, so -t is what the
            // screen sits at, which is the whole point of a manual switch.
            ? "pkill -x wlsunset; exec wlsunset -S 00:00 -s 00:01 -t " + t + " -T " + t
            : "pkill -x gammastep; exec gammastep -O " + t;
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            "command -v wlsunset >/dev/null && echo wlsunset || " +
            "{ command -v gammastep >/dev/null && echo gammastep; } || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim();
                // Whatever was on when the session ended goes back on, because
                // a night light you have to switch on again every login is one
                // you stop switching on.
                if (root.enabled && root.available) root.apply();
            }
        }
    }

    Process { id: runner }
    Process {
        id: stopper
        command: ["sh", "-c", "pkill -x wlsunset; pkill -x gammastep; true"]
    }
    Process { id: warn }

    FileView {
        id: state
        path: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/night.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false

        function save() {
            state.setText(JSON.stringify({
                enabled: root.enabled,
                temperature: root.temperature
            }, null, 2) + "\n");
        }

        onLoaded: {
            try {
                const saved = JSON.parse(state.text());
                if (saved.temperature) root.temperature = saved.temperature;
                if (saved.enabled !== undefined) root.enabled = saved.enabled;
            } catch (e) {
                // Defaults stand.
            }
        }
    }
}
