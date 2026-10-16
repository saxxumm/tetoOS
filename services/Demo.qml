pragma Singleton
import QtQuick
import Quickshell

// Demo mode (TETOOS_DEMO=1): stand-in data for everything personal, so the
// screenshots in the README show no real name, network, device, music or
// place. Nothing else changes — the shell runs exactly as it does for real.
Singleton {
    id: root

    readonly property bool on: Quickshell.env("TETOOS_DEMO") === "1"

    readonly property string user: "teto"
    readonly property string host: "chimera"
    readonly property string name: "Kasane Teto"
    readonly property string avatar: Quickshell.shellDir + "/assets/teto/happy.png"
    readonly property string place: "Tokyo"

    readonly property var wifi: [
        { name: "Teto-Territory-5G", signalStrength: 0.92, connected: true, known: true, security: 3 },
        { name: "Baguette Bakery", signalStrength: 0.71, connected: false, known: true, security: 3 },
        { name: "UTAU-Lab", signalStrength: 0.55, connected: false, known: false, security: 3 },
        { name: "Chimera Free WiFi", signalStrength: 0.38, connected: false, known: false, security: 0 },
        { name: "Drill-Net", signalStrength: 0.21, connected: false, known: false, security: 3 }
    ]

    readonly property var bluetooth: [
        { deviceName: "Teto Buds", icon: "audio-headset", connected: true, paired: true, batteryAvailable: true, battery: 0.8 },
        { deviceName: "Wireless Controller", icon: "input-gaming", connected: false, paired: true },
        { deviceName: "Baguette Speaker", icon: "audio-speakers", connected: false, paired: false }
    ]

    readonly property var sinks: [
        { name: "alsa_output.speakers", description: "Speakers" },
        { name: "effect_input.tetoos_eq10", description: "tetoOS Equalizer" },
        { name: "bluez_output.teto_buds", description: "Teto Buds" }
    ]
    readonly property var streams: [
        { name: "music", description: "Music Player", properties: { "application.name": "Music Player", "application.icon-name": "audio-x-generic" }, audio: { volume: 0.8, muted: false } },
        { name: "browser", description: "Web Browser", properties: { "application.name": "Web Browser", "application.icon-name": "web-browser" }, audio: { volume: 0.45, muted: false } }
    ]

    readonly property var clips: [
        { id: "1", preview: "Kasane Teto — 31 years old, a chimera, likes baguettes" },
        { id: "2", preview: "https://github.com/saxxumm/tetoOS" },
        { id: "3", preview: "tetoos ipc tetoSing" },
        { id: "4", preview: "Teto Territory! Teto Territory!" }
    ]

    // a song that plays forever, with a clock running under it
    readonly property string title: "Teto Territory"
    readonly property string artist: "Kasane Teto"
    readonly property real length: 140
    property real position: 6
    Timer {
        running: root.on
        interval: 1000
        repeat: true
        onTriggered: root.position = (root.position + 1) % root.length
    }
}
