pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server, the live popups' model, and the history the control
// centre lists.
//
// One singleton because there is exactly one org.freedesktop.Notifications on
// the bus: a second instance would fail to take the name and then silently show
// nothing at all.
Singleton {
    id: root

    // Urgent notifications stay until dismissed. Everything else leaves on its
    // own — a notification you have to dismiss is a notification you learn to
    // dismiss without reading.
    readonly property int ordinaryTimeout: 6000
    readonly property int lowTimeout: 4000

    property bool doNotDisturb: false
    property var history: []
    readonly property int historyLimit: 60
    readonly property int count: root.history.length

    // Off in a nested test session: there is one notification bus name per
    // login, and the real shell already holds it.
    readonly property bool serve: Quickshell.env("TETOOS_NESTED") !== "1"
    readonly property var server: serverLoader.item
    property var fakes: []
    readonly property var popups: (root.server && root.server.trackedNotifications
        ? root.server.trackedNotifications.values : []).concat(root.fakes)

    // A notification that never touched the bus, for previews and tests.
    function demo(app, summary, body, icon) {
        const n = { id: -Date.now(), appName: app, summary: summary, body: body, appIcon: icon || "",
            image: "", urgency: 1, fake: true, time: new Date() };
        n.dismiss = () => { root.fakes = root.fakes.filter(x => x.id !== n.id); };
        root.fakes = root.fakes.concat([n]);
        root.remember(n);
    }

    function remember(n) {
        const entry = {
            id: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            appIcon: n.appIcon || "",
            urgency: n.urgency,
            time: new Date()
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
        if (!root.doNotDisturb) Sfx.play("chime", 1);
    }

    function clearHistory() { root.history = []; }

    function forget(id) {
        root.history = root.history.filter(e => e.id !== id);
    }

    function dismissAll() {
        for (const n of root.popups.slice()) n.dismiss();
        root.fakes = [];
    }

    function toggleDnd() { root.doNotDisturb = !root.doNotDisturb; }

    // "2 min ago" beats a timestamp in a list you scan rather than read.
    function ago(date) {
        const s = Math.max(0, (Date.now() - date.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void { root.toggleDnd(); }
        function clear(): void { root.clearHistory(); }
        function dismissAll(): void { root.dismissAll(); }
        function count(): int { return root.count; }
        function demo(app: string, summary: string, body: string): void { root.demo(app, summary, body, ""); }
    }

    LazyLoader {
        id: serverLoader
        active: root.serve

    NotificationServer {

        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        inlineReplySupported: true
        // Reloading the shell must not resurrect notifications the user has
        // already seen and forgotten about.
        keepOnReload: false

        onNotification: notification => {
            root.remember(notification);
            // Do not disturb still records: the point is to stop the
            // interruption, not to lose the message.
            notification.tracked = !root.doNotDisturb
                || notification.urgency === NotificationUrgency.Critical;
        }
    }
    }
}
