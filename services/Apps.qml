pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Applications for the launcher: a forgiving search over the desktop entries,
// ranked by how well the name matches and then by how often you open it.
Singleton {
    id: root

    property var counts: ({})

    readonly property var all: {
        const list = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        return list.slice().sort((a, b) => (root.counts[b.id] || 0) - (root.counts[a.id] || 0)
            || a.name.localeCompare(b.name));
    }

    function score(entry, q) {
        const name = (entry.name || "").toLowerCase();
        if (name === q) return 1000;
        if (name.startsWith(q)) return 800 - name.length;
        const words = name.split(/[\s\-_.]+/);
        if (words.some(w => w.startsWith(q))) return 600 - name.length;
        if (name.indexOf(q) >= 0) return 400 - name.indexOf(q);
        const extra = ((entry.genericName || "") + " " + (entry.keywords || []).join(" ") + " " + (entry.id || "")).toLowerCase();
        if (extra.indexOf(q) >= 0) return 200;
        // letters in order: "tg" finds "Telegram"
        let i = 0;
        for (const ch of name) if (ch === q[i]) i++;
        return i === q.length ? 100 - name.length : -1;
    }

    function search(text) {
        const q = (text || "").trim().toLowerCase();
        if (q === "") return root.all;
        return root.all
            .map(e => ({ e: e, s: root.score(e, q) + Math.min(50, (root.counts[e.id] || 0) * 5) }))
            .filter(x => x.s >= 0)
            .sort((a, b) => b.s - a.s)
            .map(x => x.e);
    }

    function launch(entry) {
        if (!entry) return;
        const next = Object.assign({}, root.counts);
        next[entry.id] = (next[entry.id] || 0) + 1;
        root.counts = next;
        store.setText(JSON.stringify(root.counts));
        entry.execute();
    }

    function iconFor(entry) {
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, "application-x-executable") : "";
    }

    FileView {
        id: store
        path: (Quickshell.env("TETOOS_STATE") || Quickshell.env("HOME") + "/.local/state/tetoos") + "/launches.json"
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: { try { root.counts = JSON.parse(store.text()); } catch (e) {} }
    }
}
