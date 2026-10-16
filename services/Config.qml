pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the shell remembers: ~/.local/state/tetoos/config.json.
//
// Written back on every change, read back when something else edits the file,
// so `jq` and the settings phone never disagree for long.
Singleton {
    id: root

    property alias options: adapter
    property bool ready: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: Quickshell.env("TETOOS_STATE") || root.home + "/.local/state/tetoos"
    readonly property string shellDir: Quickshell.shellDir

    // Widget placement is the one nested thing here. It is replaced whole on
    // every edit (never mutated in place), which is what makes bindings on it
    // and the JSON writer both see the change.
    function widget(name) {
        const all = adapter.widgets || {};
        return all[name] || root.defaultWidgets[name] || { x: 0.1, y: 0.1, on: false };
    }

    function setWidget(name, patch) {
        const all = Object.assign({}, adapter.widgets || {});
        all[name] = Object.assign({}, root.widget(name), patch);
        adapter.widgets = all;
    }

    // Fractions of the screen, top-left of each widget. Laid out for the Teto
    // wallpaper, whose face is on the left: the cards stack on the right.
    readonly property var defaultWidgets: ({
        clock: { x: 0.035, y: 0.62, on: true },
        todo: { x: 0.80, y: 0.11, on: true },
        user: { x: 0.585, y: 0.11, on: true },
        weather: { x: 0.585, y: 0.385, on: true },
        calendar: { x: 0.80, y: 0.52, on: false },
        visualizer: { x: 0, y: 0.80, on: true },
        system: { x: 0.035, y: 0.33, on: false }
    })

    function set(key, value) { adapter[key] = value; }
    function toggle(key) { adapter[key] = !adapter[key]; }

    FileView {
        id: file
        path: root.stateDir + "/config.json"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        blockLoading: true

        onFileChanged: file.reload()
        onAdapterUpdated: file.writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            // First run: write the defaults so there is a file to edit.
            file.writeAdapter();
            root.ready = true;
        }

        JsonAdapter {
            id: adapter

            // look
            property string mode: "light"            // light | dark | auto
            property string palette: "wallpaper"     // wallpaper | a preset name
            property string wallpaper: root.home + "/Pictures/wallpapers/teto/wallhaven-yq2mdd.jpg"
            property string lockWallpaper: ""
            property string wallpaperDir: root.home + "/Pictures/wallpapers"

            // bar
            property bool bar: true
            property string barStyle: "float"        // float | straight | transparent
            property string barPosition: "top"       // top | bottom
            property bool barWeather: true
            property bool barMedia: true
            property bool barTray: true
            property bool barWindow: true

            // dock
            property bool dock: true
            property list<string> pinned: ["kitty", "firefox", "org.kde.dolphin", "spotify"]

            // desktop
            property var widgets: ({})
            property bool widgetsLocked: false
            property bool visualizer: true

            // clock
            property bool clock24: true
            property bool showSeconds: false

            // quick buttons in the control centre
            property list<string> quick: ["wifi", "bluetooth", "mic", "speaker", "night", "dark", "dnd", "caffeine"]
            property int quickColumns: 2

            // who
            property string displayName: ""
            property string weatherPlace: ""

            // motion
            property bool tilt: true

            // sound
            property bool sounds: true
            property real soundVolume: 0.6

            // mini Teto
            property bool teto: true
            property bool tetoVoice: true
            property string tetoChatter: "normal"   // quiet | normal | chatty
            property bool tetoKaraoke: false
            property real tetoScale: 4
            property int tetoLove: 0
            property string breadDay: ""
            property var breadBox: ({})

            // lyrics (lrclib.net)
            property bool lyrics: true
            property bool lyricsBar: true
        }
    }
}
