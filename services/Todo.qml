pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The list of things still to beat.
//
// A to-do list is the one widget in a shell whose entire value is that it
// survives a reboot, so it is a file first and a model second: every change
// writes ~/.local/state/tetoos/todo.json immediately rather than on shutdown,
// because the session that loses the list is always the one that crashed.
//
// Entries keep their own id rather than being addressed by index: the pane
// sorts unfinished first, so an index means something different to the list
// and to the thing drawing it, and the wrong task gets struck through.
Singleton {
    id: root

    property var entries: []

    readonly property var pending: root.entries.filter(e => !e.done)
    readonly property var done: root.entries.filter(e => e.done)
    readonly property int count: root.pending.length

    function add(text) {
        const body = (text || "").trim();
        if (body.length === 0) return;
        root.entries = root.entries.concat([{
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1000),
            text: body,
            done: false,
            at: new Date().toISOString()
        }]);
        file.save();
    }

    function toggle(id) {
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, { done: !e.done }) : e);
        file.save();
    }

    function remove(id) {
        root.entries = root.entries.filter(e => e.id !== id);
        file.save();
    }

    function clearDone() {
        root.entries = root.entries.filter(e => !e.done);
        file.save();
    }

    FileView {
        id: file
        path: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/todo.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false

        function save() {
            file.setText(JSON.stringify(root.entries, null, 2) + "\n");
        }

        onLoaded: {
            try {
                const saved = JSON.parse(file.text());
                if (Array.isArray(saved)) root.entries = saved;
            } catch (e) {
                // No list yet, or a file edited into something that is not one.
                // The empty list stands; overwriting it is one keystroke away
                // and losing it silently would not be.
            }
        }
    }
}
