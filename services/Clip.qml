pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, over cliphist.
//
// cliphist is optional: without it the launcher's clipboard mode says so rather
// than showing an empty list, which is the difference between "you have copied
// nothing" and "nothing is recording what you copy".
Singleton {
    id: root

    property bool available: false
    property var entries: []

    // cliphist lists one entry per line as "<id>\t<preview>".
    function refresh() {
        if (Demo.on) { root.available = true; root.entries = Demo.clips; return; }
        if (!root.available) return;
        lister.running = true;
    }

    // Decoding by id rather than pasting the preview: the list truncates long
    // entries and mangles binary ones, and the id is what cliphist keeps whole.
    function copy(id) {
        if (Demo.on) return;
        copier.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        copier.running = true;
    }

    // One entry out of the history: cliphist deletes whatever line it is fed.
    function remove(entry) {
        if (!entry) return;
        remover.command = ["sh", "-c", "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete", "sh", entry.id, entry.preview];
        remover.running = true;
        root.entries = root.entries.filter(e => e.id !== entry.id);
    }
    Process { id: remover }

    function wipe() {
        wiper.running = true;
        root.entries = [];
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-copy >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                if (root.available) root.refresh();
            }
        }
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    list.push({ id: line.slice(0, tab), preview: line.slice(tab + 1) });
                }
                root.entries = list;
            }
        }
    }

    Process { id: copier }
    Process { id: wiper; command: ["cliphist", "wipe"] }
}
