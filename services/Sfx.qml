pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's sounds: scripts/sfx.py synthesises them and keeps one audio
// stream open while they play. Silent in a nested test session, so trying the
// shell inside another one does not chirp through the real speakers.
Singleton {
    id: root

    readonly property bool nested: Quickshell.env("TETOOS_NESTED") === "1"
    readonly property bool enabled: Config.ready && Config.options.sounds && !root.nested
    readonly property real volume: Config.ready ? Config.options.soundVolume : 0.6

    function play(name, pitch) {
        if (!root.enabled) return;
        root.send(name + " " + root.volume.toFixed(2) + " " + (pitch || 1).toFixed(3));
    }

    // Teto's typing voice: one chirp per letter, pitched by the letter so a
    // sentence has a tune rather than a drone.
    function blip(ch) {
        if (!root.enabled || !Config.options.tetoVoice) return;
        const code = ch.toLowerCase().charCodeAt(0) || 0;
        const pitch = 0.9 + (code % 7) * 0.045;
        root.send("blip " + (root.volume * 0.55).toFixed(2) + " " + pitch.toFixed(3));
    }

    function sing(score) {
        if (!root.enabled || !Config.options.tetoVoice) return;
        root.send("sing " + (root.volume * 0.8).toFixed(2) + " " + score);
    }

    function send(line) {
        if (!player.running) player.running = true;
        player.write(line + "\n");
    }

    Process {
        id: player
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/sfx.py"]
        stdinEnabled: true
        running: root.enabled
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("sfx:", text.trim()) }
    }
}
