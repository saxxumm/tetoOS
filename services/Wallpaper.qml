pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper, the list to pick from, and the colours that follow it.
//
// Setting a wallpaper writes the path into the config (the background layer
// cross-fades to it) and, unless a preset palette is pinned, asks palette.py
// for a scheme read off the new picture. Theme picks the file up and eases.
Singleton {
    id: root

    readonly property string current: Config.ready ? Config.options.wallpaper : ""
    readonly property string script: Quickshell.shellDir + "/scripts/palette.py"
    property var list: []                  // [{ path, thumb, name }]
    property bool scanning: false

    // Presets: a seed colour each, from the voices of the wallpaper's world.
    // The generator fills in the other two hues itself.
    readonly property var presets: [
        { name: "wallpaper", label: "From wallpaper", seeds: [] },
        { name: "teto", label: "Kasane Teto", seeds: ["#d13d5a", "#a986d6", "#9fd0ef"] },
        { name: "miku", label: "Hatsune Miku", seeds: ["#39c5bb", "#b39ddb", "#f48fb1"] },
        { name: "rin", label: "Kagamine Rin", seeds: ["#f2b51b", "#f08a5d", "#7dc4e4"] },
        { name: "luka", label: "Megurine Luka", seeds: ["#e86ca5", "#c9a7eb", "#f4d06f"] },
        { name: "kaito", label: "KAITO", seeds: ["#3d6fd6", "#7ad3e6", "#e8a0c4"] },
        { name: "gumi", label: "GUMI", seeds: ["#6cc04a", "#f28c4b", "#8fb7f0"] },
        { name: "neru", label: "Akita Neru", seeds: ["#e8c547", "#6a7fd8", "#f0a3b7"] }
    ]

    function set(path) {
        if (!path || path === root.current) return;
        Config.options.wallpaper = path;
        if (Config.options.palette === "wallpaper") root.recolor(path);
    }

    function recolor(path) {
        painter.command = ["python3", "-I", root.script, "image", path || root.current];
        painter.running = true;
    }

    function usePreset(name) {
        const p = root.presets.find(x => x.name === name);
        if (!p) return;
        Config.options.palette = name;
        if (p.seeds.length === 0) { root.recolor(root.current); return; }
        painter.command = ["python3", "-I", root.script, "seed"].concat(p.seeds);
        painter.running = true;
    }

    function next(step) {
        if (root.list.length === 0) return;
        const i = root.list.findIndex(w => w.path === root.current);
        const n = (i + step + root.list.length) % root.list.length;
        root.set(root.list[n].path);
    }

    function rescan() {
        if (scanner.running) return;
        root.scanning = true;
        scanner.found = [];
        scanner.command = ["python3", "-I", root.script, "thumbs", Config.options.wallpaperDir];
        scanner.running = true;
    }

    Process {
        id: painter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("palette:", text.trim());
        }
    }

    Process {
        id: scanner
        property var found: []
        stdout: SplitParser {
            onRead: line => {
                try { scanner.found.push(JSON.parse(line)); } catch (e) {}
            }
        }
        onExited: {
            root.list = scanner.found.slice();
            root.scanning = false;
            // the configured picture is gone (or never was): take the first one there is
            if (root.list.length > 0 && !root.list.some(w => w.path === root.current))
                root.set(root.list[0].path);
        }
    }

    // The first scan once the config says where to look; later ones when the
    // picker opens.
    Connections {
        target: Config
        function onReadyChanged() { if (Config.ready) root.rescan(); }
    }
    Component.onCompleted: if (Config.ready) root.rescan()
}
