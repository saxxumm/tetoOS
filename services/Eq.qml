pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The ten-band equalizer, as a curve and a sink to play it through.
//
// The audio itself is PipeWire's: config/sxmwm/pipewire/99-sxmwm-equalizer.conf
// builds a chain of ten biquads and publishes it as a sink, and this writes band
// gains at it while it runs. Nothing here does any filtering — this is a control
// surface for a graph that exists whether the shell is running or not.
//
// THE THREE STATES worth keeping apart, because the menu shows a different thing
// for each:
//   * no sink        — the drop-in is not installed, or filter-chain.service is
//                      not running. Nothing to control.
//   * sink, unrouted — the chain exists but nothing plays into it. The curve is
//                      real and saved, and audible on nothing.
//   * sink, routed   — the equalizer is the default output.
//
// WRITES ARE ONE-WAY. A gain written into the chain is not echoed back: pw-dump
// and `pw-cli e <id> Props` both keep reporting the Gain values the .conf was
// built with, whatever has been written since. So the saved curve here is the
// only record of what the chain is set to, and the chain is re-fed from it
// whenever the sink appears — including after filter-chain.service restarts,
// which rebuilds every biquad at 0 dB under a fresh node id.
Singleton {
    id: root

    // The ten-band chains this shell knows how to drive, in the order it
    // prefers them. They share one layout (eq_band_1..10, same frequencies),
    // so whichever filter-chain drop-in is installed, the sliders work.
    readonly property var candidates: ["effect_input.tetoos_eq10", "effect_input.inir_eq10", "effect_input.sxmwm_eq10"]
    readonly property string sinkName: {
        if (!Pipewire.nodes) return root.candidates[0];
        for (const c of root.candidates)
            for (const n of Pipewire.nodes.values) if (n.name === c) return c;
        return root.candidates[0];
    }
    // A nested test session shares the real PipeWire graph: it must not
    // re-feed the saved curve into it on start, only on a deliberate change.
    readonly property bool nested: Quickshell.env("TETOOS_NESTED") === "1"

    // A description of the .conf, not a second source of truth: the frequencies,
    // Q values and filter types live there. Ten octave-spaced bands, the lowest
    // and highest of them shelves so nothing above or below the table is left
    // behind.
    readonly property var bands: [
        { label: "32",  unit: "Hz" },
        { label: "64",  unit: "Hz" },
        { label: "125", unit: "Hz" },
        { label: "250", unit: "Hz" },
        { label: "500", unit: "Hz" },
        { label: "1",   unit: "kHz" },
        { label: "2",   unit: "kHz" },
        { label: "4",   unit: "kHz" },
        { label: "8",   unit: "kHz" },
        { label: "16",  unit: "kHz" }
    ]

    readonly property real minDb: -12
    readonly property real maxDb: 12
    // Gains live on a half-decibel grid, so a slider drag lands on a value that
    // prints exactly and compares exactly against a preset.
    readonly property real stepDb: 0.5

    // The curve the user chose, and whether it is in circuit. Turning the
    // equalizer off flattens the chain without forgetting the curve, which is
    // what makes it an A/B switch rather than a reset.
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool active: true

    // --- the presets --------------------------------------------------------
    // Ordered the way the menu lays them out. "Custom" is not in here: it is
    // what `preset` reports when the curve matches none of these.
    readonly property var presets: [
        { id: "flat",     name: "FLAT",  gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        // Shelf plus the two bass octaves, tapering out before the mids so voices
        // and snares keep their body instead of turning boomy.
        { id: "bass",     name: "BASS",  gains: [6, 5, 3.5, 1.5, 0, 0, 0, 0, 0, 0] },
        // Duck the low end that masks speech, lift the 1–4 kHz presence range.
        { id: "vocal",    name: "VOCAL", gains: [-2, -2, -1, 0, 1.5, 3, 3.5, 2, 0, -1] },
        { id: "treble",   name: "AIR",   gains: [0, 0, 0, 0, 0, 0, 1.5, 3, 4.5, 5.5] },
        // Equal-loudness style smile curve, for listening quietly.
        { id: "loudness", name: "LOUD",  gains: [5, 4, 2, 0, -1, -1, 0, 2, 3.5, 4] },
        // Teto's: a bright, forward voice — the UTAU range up front, a little air.
        { id: "teto",     name: "TETO",  gains: [1, 1, 0, -1, 0, 2, 3.5, 3, 2, 1.5] }
    ]

    readonly property string preset: {
        for (const p of root.presets) {
            let same = true;
            for (let i = 0; i < p.gains.length; i++) {
                if (root.steps(p.gains[i]) !== root.steps(root.gains[i])) { same = false; break; }
            }
            if (same) return p.id;
        }
        return "custom";
    }

    readonly property bool flat: root.preset === "flat"

    // --- the sink -----------------------------------------------------------
    readonly property var node: {
        if (!Pipewire.nodes) return null;
        for (const n of Pipewire.nodes.values) if (n.name === root.sinkName) return n;
        return null;
    }

    readonly property bool available: Demo.on || root.node !== null

    // Keeps the node bound so its id and name stay readable rather than going
    // blank the moment nothing else is looking at it.
    PwObjectTracker {
        objects: root.node ? [root.node] : []
    }

    // --- which output the session is using ----------------------------------
    // The current sink comes from Audio, which asks the daemon for it rather
    // than trusting Quickshell's own idea of the default — see the note there.
    // A routing button that cannot see what it did is worse than no button.
    readonly property bool routed: Demo.on || root.available && Audio.defaultSinkName === root.sinkName

    // Where to go back to when the equalizer is switched out of the path.
    // Remembered rather than guessed: "the other one" is ambiguous the moment a
    // headset is connected, and dropping the user on the wrong output is worse
    // than leaving them where they were.
    property string lastPlainName: ""

    Connections {
        target: Audio
        function onDefaultSinkNameChanged() {
            const name = Audio.defaultSinkName;
            if (name !== "" && name !== root.sinkName) root.lastPlainName = name;
        }
    }

    // Nothing was ever seen but the equalizer — the session came up with it
    // already chosen, so there is no "back" to go to. Any real output will do,
    // which is better than a button that quietly does nothing.
    readonly property var fallbackNode: {
        if (!Pipewire.nodes) return null;
        for (const n of Pipewire.nodes.values) {
            if (n.isSink && !n.isStream && n.name !== root.sinkName) return n;
        }
        return null;
    }

    // wpctl rather than Quickshell's own preferredDefaultAudioSink, for the same
    // reason the state above is read from the daemon: writes through that
    // property were not reliably taken here, and moving the output is the one
    // thing in this menu that has to work on the first press.
    function route() {
        if (!root.available || root.nested) return;
        let target = root.node;
        if (root.routed) target = Audio.nodeNamed(root.lastPlainName) || root.fallbackNode;
        if (!target) return;
        router.command = ["wpctl", "set-default", String(target.id)];
        router.running = true;
    }

    Process {
        id: router
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("could not move the output:", text.trim());
        }
        // The daemon takes a moment to settle, and the button should show what
        // it did rather than what it was.
        onExited: settle.restart()
    }

    Timer {
        id: settle
        interval: 250
        repeat: false
        onTriggered: Audio.readDefault()
    }

    // --- editing the curve --------------------------------------------------
    // Everything below derives from the half-step integer rather than from the
    // float: two curves that print the same must count as the same, and
    // 0.1 + 0.2 must not get a say in it.
    function steps(db) {
        if (!isFinite(db)) return 0;
        const clamped = Math.max(root.minDb, Math.min(root.maxDb, db));
        const scaled = clamped / root.stepDb;
        // Rounded away from zero: Math.round(-7.5) is -7, which would turn
        // -3.75 dB into -3.5 dB on one side of the dial and -4.0 on the other.
        return scaled < 0 ? -Math.round(-scaled) : Math.round(scaled);
    }

    function clamp(db) { return root.steps(db) * root.stepDb; }

    // "+3.5", "0.0", "-1.5" — built from the half-step integer so a
    // comma-decimal locale cannot reach it. pw-cli parses what this produces.
    function formatDb(db) {
        const halves = root.steps(db);
        const magnitude = Math.abs(halves);
        const text = Math.floor(magnitude / 2) + (magnitude % 2 === 1 ? ".5" : ".0");
        if (halves > 0) return "+" + text;
        return halves < 0 ? "-" + text : text;
    }

    function setBand(index, db) {
        if (index < 0 || index >= root.bands.length) return;
        const wanted = root.clamp(db);
        if (root.gains[index] === wanted) return;
        const next = root.gains.slice();
        next[index] = wanted;
        root.gains = next;
        root.push();
    }

    function nudgeBand(index, deltaDb) {
        root.setBand(index, root.gains[index] + deltaDb);
    }

    function usePreset(id) {
        for (const p of root.presets) {
            if (p.id !== id) continue;
            root.gains = p.gains.slice();
            root.push();
            return;
        }
    }

    function reset() { root.usePreset("flat"); }

    function toggle() {
        root.active = !root.active;
        root.push();
    }

    // --- writing it at the chain --------------------------------------------
    // What the chain is actually set to: the curve, or ten zeroes while the
    // equalizer is switched out.
    readonly property var applied: root.active ? root.gains : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // One pw-cli call carrying all ten bands. A Props write is cheap but not
    // free, and a slider drag produces one per pixel — hence the timer, which
    // collapses a drag into a few writes without the knob feeling laggy.
    Timer {
        id: commit
        interval: 40
        repeat: false
        onTriggered: {
            state.save();
            if (!root.available || root.nested) return;
            const parts = [];
            for (let i = 0; i < root.applied.length; i++) {
                // toFixed is ECMAScript, not locale-aware: always a '.' separator,
                // which is the only form the SPA-JSON parser accepts.
                parts.push('"eq_band_' + (i + 1) + ':Gain" ' + root.applied[i].toFixed(2));
            }
            writer.command = ["pw-cli", "s", String(root.node.id), "Props",
                              "{ params = [ " + parts.join(" ") + " ] }"];
            writer.running = true;
        }
    }

    function push() { commit.restart(); }

    Process {
        id: writer
        // pw-cli prints the pod it sent and exits before the daemon has done
        // anything with it. There is no acknowledgement to wait for and nothing
        // useful in the output, so it is thrown away.
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("equalizer write failed:", text.trim());
        }
    }

    // A chain that has just appeared is a chain built from the .conf's defaults:
    // every band at 0 dB, under a node id that is new. Push the saved curve into
    // it. This is the path that runs at login, and again after
    // `systemctl --user restart filter-chain.service`.
    onNodeChanged: if (root.node && !root.nested) root.push()

    // --- what is remembered -------------------------------------------------
    FileView {
        id: state
        path: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/equalizer.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false

        function save() {
            state.setText(JSON.stringify({ active: root.active, gains: root.gains }, null, 2) + "\n");
        }

        onLoaded: {
            try {
                const saved = JSON.parse(state.text());
                if (Array.isArray(saved.gains) && saved.gains.length === root.bands.length) {
                    root.gains = saved.gains.map(g => root.clamp(g));
                }
                if (saved.active !== undefined) root.active = saved.active;
            } catch (e) {
                // No curve saved yet, or one edited badly by hand: flat stands.
            }
            if (!root.nested) root.push();
        }
    }
}
