pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The default sink and source, straight from PipeWire rather than through
// wpctl. Reading and writing the same object means the bar shows a change made
// in any other mixer immediately, and the OSD does not have to shell out twice
// per key press to find out what it did.
//
// It also owns which microphone the session is on. That is a system setting
// rather than a shell one — it is written into the daemon's metadata, every
// application that asks for "the microphone" is handed the one named there, and
// WirePlumber remembers it across a reboot — so this holds the list and the
// switch, and the control centre's INPUT section is only a face for it.
Singleton {
    id: root

    // The sink is the one the daemon names, found by name among the nodes; see
    // "which sink the session is actually on" below for why it is not simply
    // Pipewire.defaultAudioSink. That stays as the fallback for the moment
    // before the first read lands, and for a name that matches no node.
    readonly property var sink: root.nodeNamed(root.defaultSinkName) || Pipewire.defaultAudioSink

    // The microphone resolves the same way and for the same reason:
    // `Pipewire.defaultAudioSource` was measured going stale exactly as its sink
    // counterpart does — switched to another input, with the daemon and pactl
    // both agreeing on the new one, that property still named the old one a
    // second later. So the list, the gain, the meter and the mute all read
    // through the name the daemon gives.
    readonly property var source: root.nodeNamed(root.defaultSourceName) || Pipewire.defaultAudioSource

    // Node properties only stay bound while something tracks the object; without
    // this the volume reads zero and never changes. Every input is tracked
    // rather than only the live one, because the picker prints the state of each
    // microphone on the list and not just of the one it is on.
    PwObjectTracker {
        objects: {
            const all = [root.sink, root.source].concat(root.sources);
            return all.filter((n, i) => n !== null && all.indexOf(n) === i);
        }
    }

    readonly property bool ready: root.sink !== null && root.sink.audio !== null
    readonly property real volume: root.ready ? root.sink.audio.volume : 0
    readonly property bool muted: root.ready ? root.sink.audio.muted : false
    readonly property string sinkName: root.sink ? (root.sink.nickname || root.sink.description || root.sink.name) : ""

    readonly property bool micReady: root.source !== null && root.source.audio !== null
    readonly property real micVolume: root.micReady ? root.source.audio.volume : 0
    readonly property bool micMuted: root.micReady ? root.source.audio.muted : false
    readonly property string sourceName: root.label(root.source)

    // Over 100% is allowed but capped well below what wpctl would let through:
    // PipeWire happily amplifies into distortion, and a volume key should not
    // be able to reach it.
    readonly property real maxVolume: 1.4

    // The microphone stops at unity. PipeWire will amplify an input as happily
    // as an output, and a microphone driven past its hardware does not arrive
    // louder at the other end of the call, it arrives clipped — so a quiet
    // microphone is a reason to pick a different one on the list below, not to
    // turn a gain past where the device stops.
    readonly property real maxMicVolume: 1.0

    function setVolume(v) {
        if (!root.ready) return;
        root.sink.audio.volume = Math.max(0, Math.min(root.maxVolume, v));
    }

    function step(delta) {
        if (!root.ready) return;
        if (root.muted && delta > 0) root.sink.audio.muted = false;
        root.setVolume(root.volume + delta);
    }

    function toggleMute() {
        if (!root.ready) return;
        root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setMicVolume(v) {
        if (!root.micReady) return;
        root.source.audio.volume = Math.max(0, Math.min(root.maxMicVolume, v));
    }

    function micStep(delta) {
        if (!root.micReady) return;
        if (root.micMuted && delta > 0) root.source.audio.muted = false;
        root.setMicVolume(root.micVolume + delta);
    }

    function toggleMicMute() {
        if (!root.micReady) return;
        root.source.audio.muted = !root.source.audio.muted;
    }

    // --- the microphones on offer -------------------------------------------
    // Capture devices and virtual sources, which is what "microphone" means to
    // someone picking one: the built-in analog input, a headset, a loopback, the
    // voice changer's output posing as a microphone.
    //
    // Applications recording are source nodes too and are left out — a call in
    // progress is not somewhere to route the microphone to. That is the same
    // `isStream` split the mixer's `streams` uses, read the other way round.
    // Monitors never appear: a sink's monitor is part of the sink node rather
    // than a node of its own, so there is nothing here to filter out.
    readonly property var sources: {
        const list = [];
        if (!Pipewire.nodes) return list;
        for (const node of Pipewire.nodes.values) {
            if (!node.isSink && !node.isStream && node.audio) list.push(node);
        }
        return list;
    }

    // What to call a node in the interface. The nickname is the short one
    // ("ALC298 Analog"); the description is the long spelled-out one, which is
    // the only name some virtual sources carry; the node name is the last
    // resort and is at least unique.
    function label(node) {
        if (!node) return "";
        if (Demo.on) return node.description;
        return node.nickname || node.description || node.name;
    }

    // Outputs, the same way: real devices and virtual sinks (the equalizer
    // among them), never an application's stream.
    readonly property var sinks: Demo.on ? Demo.sinks : root.realSinks
    readonly property var realSinks: {
        const list = [];
        if (!Pipewire.nodes) return list;
        for (const node of Pipewire.nodes.values) {
            if (node.isSink && !node.isStream && node.audio) list.push(node);
        }
        return list;
    }

    // Writes the daemon's default like setSource does; held back in a nested
    // test session, which shares the real graph.
    function setSink(node) {
        if (!node || node === root.sink || Quickshell.env("TETOOS_NESTED") === "1") return;
        sourceRouter.command = ["wpctl", "set-default", String(node.id)];
        sourceRouter.running = true;
    }

    // Moving the microphone goes through wpctl, for the same reason routing the
    // output does — see `route()` in Eq: writes through Quickshell's own
    // preferred-default properties were not reliably taken here.
    //
    // It is deliberately a write to the daemon rather than a choice remembered
    // in the shell: everything that asks for the default microphone afterwards,
    // this shell included, is handed the new one, and WirePlumber keeps it
    // across a reboot. Picking an input here is the system setting, not a shell
    // preference sitting on top of one.
    function setSource(node) {
        if (!node || node === root.source) return;
        sourceRouter.command = ["wpctl", "set-default", String(node.id)];
        sourceRouter.running = true;
    }

    Process {
        id: sourceRouter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("could not move the microphone:", text.trim());
        }
        // The daemon takes a moment to settle, and the list should show what the
        // click did rather than what it was.
        onExited: sourceSettle.restart()
    }

    Timer {
        id: sourceSettle
        interval: 250
        repeat: false
        onTriggered: root.readDefault()
    }

    // --- which devices the session is actually on ---------------------------
    // `Pipewire.defaultAudioSink` is not an answer to "where is the sound going
    // right now": it was measured going stale in a running shell — the daemon's
    // own `default.audio.sink` naming one sink, pactl agreeing, and that
    // property still naming the output from three switches back, through
    // changes made by the shell and by wpctl alike.
    //
    // It is not fine for the volume keys either, which is how this was found:
    // with the equalizer routed in, every press moved the analog output instead
    // — inaudible, and pinned at maxVolume within a few presses while the sink
    // actually playing never budged. So `sink` above resolves through here too,
    // and anything that has to be right about the current output asks the
    // daemon. `source` resolves through the same poll, for the same reason.
    //
    // It is a poll rather than a subscription because `pw-metadata -m` did not
    // emit the changes it was asked to monitor here either. It runs all the
    // time, since the volume keys are live whether or not a menu is open, and
    // quickens while something is watching: the player menu takes a watch while
    // it is open and drops it when it closes.
    property int watchers: 0
    function watch() { root.watchers++; root.readDefault(); }
    function unwatch() { root.watchers = Math.max(0, root.watchers - 1); }

    property string defaultSinkName: ""
    property string defaultSourceName: ""

    function nodeNamed(name) {
        if (name === "" || !Pipewire.nodes) return null;
        for (const n of Pipewire.nodes.values) if (n.name === name) return n;
        return null;
    }

    // The sink the daemon says is in use. The same node `sink` resolves to,
    // under the name the rest of the shell already asks for.
    readonly property var currentSink: root.sink

    function readDefault() {
        defaultReader.running = true;
        sourceReader.running = true;
    }

    Process {
        id: defaultReader
        command: ["pw-metadata", "0", "default.audio.sink"]
        stdout: StdioCollector {
            // "update: id:0 key:'default.audio.sink' value:'{"name":"…"}' …"
            onStreamFinished: {
                const found = text.match(/"name"\s*:\s*"([^"]+)"/);
                root.defaultSinkName = found ? found[1] : "";
            }
        }
    }

    // The same read for the input side. `default.audio.source` rather than
    // `default.configured.audio.source`: wpctl writes the configured key and the
    // session manager answers by naming the input it actually moved to, which is
    // the one to print.
    Process {
        id: sourceReader
        command: ["pw-metadata", "0", "default.audio.source"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.match(/"name"\s*:\s*"([^"]+)"/);
                root.defaultSourceName = found ? found[1] : "";
            }
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.watchers > 0 ? 1000 : 2000
        onTriggered: root.readDefault()
    }

    // Applications currently playing, for the mixer in the control centre.
    readonly property var streams: Demo.on ? Demo.streams : root.realStreams
    readonly property var realStreams: {
        const list = [];
        for (const node of Pipewire.nodes.values) {
            if (node.isStream && node.isSink && node.audio) list.push(node);
        }
        return list;
    }

    PwObjectTracker {
        objects: root.realStreams
    }
}
