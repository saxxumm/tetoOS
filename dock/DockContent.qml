import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// The dock: shell buttons, kept applications with a dot per open window, the
// windows of anything else open on this canvas, and the player.
Sticker {
    id: root

    property bool live: true

    fill: Theme.paper
    radius: 18
    lift: 4
    outline: 2.5
    implicitHeight: 54
    implicitWidth: row.implicitWidth + 20

    // One entry per application: kept ones first, in the order they were kept.
    readonly property var entries: {
        const pinned = Config.ready ? Array.from(Config.options.pinned) : [];
        const byApp = {};
        const order = [];
        for (const w of Compositor.canvasWindows) {
            const id = (w.app_id || "window").toLowerCase();
            if (!byApp[id]) { byApp[id] = []; order.push(id); }
            byApp[id].push(w);
        }
        const match = app => {
            const key = app.toLowerCase();
            for (const id of order) if (id === key || id.indexOf(key) >= 0 || key.indexOf(id) >= 0) return id;
            return null;
        };
        const used = {};
        const list = [];
        for (const app of pinned) {
            const id = match(app);
            if (id) used[id] = true;
            list.push({ app: app, windows: id ? byApp[id] : [], pinned: true });
        }
        const extra = order.filter(id => !used[id]).map(id => ({ app: id, windows: byApp[id], pinned: false }));
        return { pinned: list, extra: extra };
    }

    function entryFor(app) {
        if (!app || DesktopEntries.applications.values.length === 0) return null;
        return DesktopEntries.byId(app) || DesktopEntries.heuristicLookup(app);
    }

    function activate(entry) {
        if (!root.live) return;
        if (entry.windows.length === 0) {
            const e = root.entryFor(entry.app);
            if (e) e.execute(); else Quickshell.execDetached([entry.app]);
            return;
        }
        const focused = entry.windows.find(w => w.is_focused);
        const target = focused && entry.windows.length > 1
            ? entry.windows[(entry.windows.indexOf(focused) + 1) % entry.windows.length]
            : entry.windows[entry.windows.length - 1];
        Compositor.focusWindow(target.id);
    }

    function togglePin(app) {
        if (!Config.ready) return;
        const list = Array.from(Config.options.pinned);
        const i = list.indexOf(app);
        if (i >= 0) list.splice(i, 1); else list.push(app);
        Config.options.pinned = list;
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Tap {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            icon: "search"
            iconSize: 19
            lift: 2.5
            enabled: root.live
            onClicked: Ui.togglePhone("launcher")
        }
        Tap {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            icon: Compositor.hasOverview ? "grid_view" : "apps"
            iconSize: 18
            lift: 2.5
            enabled: root.live
            onClicked: Compositor.hasOverview ? Compositor.action("zoom-to-fit") : Ui.togglePhone("launcher")
        }
        Tap {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            icon: "wallpaper"
            iconSize: 18
            lift: 2.5
            enabled: root.live
            onClicked: Ui.togglePhone("wallpapers")
        }

        Divider {}

        Repeater {
            model: root.entries.pinned
            AppButton {}
        }

        Divider { visible: root.entries.extra.length > 0 }

        Repeater {
            model: root.entries.extra
            AppButton {}
        }

        Divider {}

        // the player
        Sticker {
            id: player
            anchors.verticalCenter: parent.verticalCenter
            width: 214
            height: 40
            radius: 14
            lift: 2.5
            fill: Theme.primary

            Rectangle {
                x: Theme.outline
                y: parent.height - Theme.outline - 4
                width: (parent.width - Theme.outline * 2) * Media.progress
                height: 4
                radius: 2
                color: Theme.primaryStrong
                visible: Media.has
            }

            ClippingRectangle {
                id: cover
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30
                radius: 9
                color: Theme.secondary
                border.color: Theme.ink
                border.width: 2
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 96; sourceSize.height: 96
                    asynchronous: true
                    visible: Media.art !== ""
                }
                Icon { anchors.centerIn: parent; visible: Media.art === ""; icon: "music_note"; size: 16; filled: true }
            }
            Column {
                anchors.left: cover.right
                anchors.leftMargin: 7
                anchors.right: controls.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3
                Label { width: parent.width; text: Media.has ? (Media.title || Media.identity) : "Nothing playing"; size: 12; weight: 700 }
                Label { width: parent.width; text: Media.has ? Media.artist : "press play somewhere"; size: 10; weight: 500; color: Theme.textSoft }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                MiniButton { icon: "skip_previous"; onUse: Media.previous() }
                Tap {
                    width: 26; height: 26
                    icon: Media.playing ? "pause" : "play_arrow"
                    iconSize: 16
                    lift: 2
                    fill: Theme.paper
                    enabled: root.live
                    onClicked: Media.toggle()
                }
                MiniButton { icon: "skip_next"; onUse: Media.next() }
            }
        }
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 2
        height: 26
        radius: 1
        color: Theme.alpha(Theme.ink, 0.35)
    }

    component MiniButton: Item {
        id: mini
        property string icon: ""
        signal use()
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 22; height: 26
        Icon { anchors.centerIn: parent; icon: mini.icon; size: 18; filled: true; opacity: miniArea.containsMouse ? 1 : 0.8 }
        MouseArea { id: miniArea; anchors.fill: parent; hoverEnabled: true; enabled: root.live; cursorShape: Qt.PointingHandCursor; onClicked: mini.use() }
    }

    component AppButton: Item {
        id: app
        required property var modelData
        readonly property var entry: root.entryFor(modelData.app)
        readonly property string art: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
        readonly property bool here: modelData.windows.some(w => w.is_focused)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 38
        height: 46

        Tap {
            id: face
            y: 2
            width: 38; height: 38
            lift: 2.5
            fill: app.here ? Theme.secondary : Theme.paper
            enabled: root.live
            onClicked: root.activate(app.modelData)
            onRightClicked: root.togglePin(app.modelData.app)
            onMiddleClicked: { const e = app.entry; if (e) e.execute(); }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 24
                source: app.art
                visible: app.art !== ""
                asynchronous: true
            }
            Label {
                anchors.centerIn: parent
                visible: app.art === ""
                text: app.modelData.app.charAt(0).toUpperCase()
                size: 16
                weight: 700
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -3
            spacing: 3
            Repeater {
                model: Math.min(3, app.modelData.windows.length)
                Rectangle {
                    width: app.here ? 9 : 5
                    height: 5
                    radius: 2.5
                    color: app.here ? Theme.primaryStrong : Theme.ink
                }
            }
        }
    }
}
