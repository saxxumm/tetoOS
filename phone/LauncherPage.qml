import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// The launcher. Type to find an application or a shell action; start with
// "clip" for the clipboard history, or "=" (or just a sum) for a calculator.
// Arrows walk the results, Enter takes one.
Item {
    id: root

    readonly property string q: Ui.query
    readonly property bool clipMode: /^clip\b/i.test(root.q)
    readonly property string clipQuery: root.q.replace(/^clip\s*/i, "").toLowerCase()
    readonly property bool mathMode: !root.clipMode && (/^=/.test(root.q) || /^[\d\s.()+\-*/^%]+$/.test(root.q) && /\d\s*[+\-*/^%]\s*\d/.test(root.q))
    property int selected: 0

    // shell actions, found by name like applications
    readonly property var actions: [
        { name: "Lock", sub: "Lock the screen", icon: "lock", run: () => { Ui.closePhone(); Ui.lockRequested(); } },
        { name: "Suspend", sub: "Sleep, keep everything", icon: "dark_mode", run: () => { Ui.closePhone(); Power.suspend(); } },
        { name: "Hibernate", sub: "Sleep to disk", icon: "downloading", run: () => { Ui.closePhone(); Power.hibernate(); } },
        { name: "Reboot", sub: "Restart the machine", icon: "restart_alt", run: () => Power.reboot() },
        { name: "Shut down", sub: "Power off", icon: "power_settings_new", run: () => Power.shutdown() },
        { name: "Wallpapers", sub: "Pick the vibe", icon: "wallpaper", run: () => Ui.openPhone("wallpapers") },
        { name: "Settings", sub: "How the shell behaves", icon: "settings", run: () => Ui.openPhone("settings") },
        { name: "Edit desktop", sub: "Move widgets, change themes", icon: "dashboard_customize", run: () => { Ui.closePhone(); Ui.editing = true; } },
        { name: "Dark mode", sub: "Toggle light and dark", icon: "contrast", run: () => { Config.options.mode = Theme.dark ? "light" : "dark"; } },
        { name: "Overview", sub: "See the whole canvas", icon: "zoom_out_map", run: () => { Ui.closePhone(); Compositor.action("zoom-to-fit"); } },
        { name: "Next keyboard layout", sub: "Switch the input language", icon: "keyboard", run: () => Compositor.nextLayout() },
        { name: "Clipboard", sub: "Everything you copied", icon: "content_paste", run: () => { Ui.query = "clip "; } },
        { name: "Clear clipboard history", sub: "Delete everything copied", icon: "delete_sweep", run: () => { Clip.wipe(); Ui.query = "clip "; } },
        { name: "Next wallpaper", sub: "Shuffle along the folder", icon: "skip_next", run: () => Wallpaper.next(1) },
        { name: "Record screen", sub: "wf-recorder, into Видео/Screencasts", icon: "screen_record", run: () => { Ui.closePhone(); Rec.toggle(); } },
        { name: "Equalizer", sub: "Ten bands, presets, mixer", icon: "graphic_eq", run: () => Ui.openPhone("sound") },
        { name: "Teto, sing", sub: "Mini Teto sings you a song", icon: "music_note", run: () => { Ui.closePhone(); Teto.singSong(); } },
        { name: "Bread of the day", sub: "Today's loaf and fortune", icon: "bakery_dining", run: () => { Ui.closePhone(); Bread.open(); Ui.togglePopup("bread", -1, null); } }
    ]

    readonly property var foundActions: {
        const q = root.q.trim().toLowerCase();
        if (q.length < 2 || root.clipMode || root.mathMode) return [];
        return root.actions.filter(a => a.name !== "Overview" || Compositor.hasOverview).filter(a => a.name.toLowerCase().indexOf(q) >= 0
            || a.name.toLowerCase().split(" ").some(w => w.startsWith(q))).slice(0, 3);
    }
    readonly property var foundApps: root.clipMode || root.mathMode ? [] : Apps.search(root.q)
    readonly property var clips: {
        if (!root.clipMode) return [];
        const q = root.clipQuery;
        return Clip.entries.filter(e => q === "" || e.preview.toLowerCase().indexOf(q) >= 0).slice(0, 60);
    }
    readonly property int total: root.clipMode ? root.clips.length : root.foundActions.length + Math.min(root.foundApps.length, 24)

    onQChanged: root.selected = 0
    onClipModeChanged: if (root.clipMode) Clip.refresh()

    function activate(i) {
        if (root.clipMode) {
            const c = root.clips[i];
            if (c) { Clip.copy(c.id); Ui.closePhone(); }
            return;
        }
        if (root.mathMode) {
            if (calc.result !== "") Quickshell.execDetached(["wl-copy", calc.result]);
            Ui.closePhone();
            return;
        }
        if (i < root.foundActions.length) { root.foundActions[i].run(); return; }
        const app = root.foundApps[i - root.foundActions.length];
        if (app) { Apps.launch(app); Ui.closePhone(); }
    }

    // --- the field --------------------------------------------------------------
    Sticker {
        id: field
        x: 18
        y: 4
        width: parent.width - 36
        height: 44
        radius: 22
        fill: Theme.paper
        Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; icon: root.clipMode ? "content_paste" : root.mathMode ? "calculate" : "search"; size: 20 }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.right: clear.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Ui.query
            onTextEdited: Ui.query = input.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: 600
            selectionColor: Theme.primary
            clip: true
            focus: true
            Component.onCompleted: input.forceActiveFocus()
            Keys.onDownPressed: root.selected = Math.min(root.total - 1, root.selected + (root.clipMode || root.selected < root.foundActions.length ? 1 : 4))
            Keys.onUpPressed: root.selected = Math.max(0, root.selected - (root.clipMode || root.selected <= root.foundActions.length ? 1 : 4))
            Keys.onRightPressed: event => { if (input.cursorPosition < input.text.length) event.accepted = false; else root.selected = Math.min(root.total - 1, root.selected + 1); }
            Keys.onLeftPressed: event => { if (input.cursorPosition > 0) event.accepted = false; else root.selected = Math.max(0, root.selected - 1); }
            Keys.onReturnPressed: root.activate(root.selected)
            Keys.onEnterPressed: root.activate(root.selected)
            Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.total)
            Label {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Search apps, actions, clip, = 2+2"
                size: 15
                weight: 500
                color: Theme.alpha(Theme.textSoft, 0.7)
            }
        }
        Tap {
            id: clear
            visible: input.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28
            icon: "close"
            iconSize: 16
            lift: 0
            onClicked: { Ui.query = ""; input.forceActiveFocus(); }
        }
    }

    // --- calculator ---------------------------------------------------------------
    Process {
        id: calc
        property string result: ""
        command: ["qalc", "-t", root.q.replace(/^=\s*/, "")]
        stdout: StdioCollector { onStreamFinished: calc.result = text.trim().split("\n").pop() }
    }
    Timer {
        running: root.mathMode && root.q.replace(/^=\s*/, "") !== ""
        interval: 120
        onTriggered: calc.running = true
    }
    Sticker {
        visible: root.mathMode
        anchors.top: field.bottom
        anchors.topMargin: 18
        x: 18
        width: parent.width - 36
        height: 120
        radius: 22
        fill: Theme.secondary
        gloss: true
        Column {
            anchors.centerIn: parent
            spacing: 2
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.q.replace(/^=\s*/, ""); size: 13; weight: 600; color: Theme.textSoft }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "= " + (calc.result || "…"); size: 30; weight: 700 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Enter copies the answer"; size: 10; weight: 500; color: Theme.textSoft }
        }
    }

    // --- actions + apps -------------------------------------------------------------
    Scroll {
        id: results
        visible: !root.clipMode && !root.mathMode
        anchors.top: field.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        contentHeight: resultCol.height + 20

        Column {
            id: resultCol
            x: 16
            width: results.width - 32
            spacing: 8

            Repeater {
                model: root.foundActions
                Tap {
                    id: act
                    required property var modelData
                    required property int index
                    width: resultCol.width
                    height: 44
                    radius: 18
                    icon: modelData.icon
                    text: modelData.name
                    sub: modelData.sub
                    fill: root.selected === act.index ? Theme.secondary : Theme.paper
                    onClicked: modelData.run()
                }
            }

            Grid {
                id: grid
                columns: 4
                columnSpacing: 0
                rowSpacing: 10
                topPadding: 6
                Repeater {
                    model: root.foundApps.slice(0, 24)
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool here: root.selected === root.foundActions.length + cell.index
                        width: resultCol.width / 4
                        height: 92
                        Tap {
                            id: tile
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 2
                            width: 60; height: 60
                            radius: 18
                            fill: cell.here ? Theme.primary : Theme.paper
                            onClicked: { Apps.launch(cell.modelData); Ui.closePhone(); }
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 38
                                source: Apps.iconFor(cell.modelData)
                                asynchronous: true
                            }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: tile.bottom
                            anchors.topMargin: 8
                            width: parent.width - 6
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.name
                            size: 11
                            weight: 650
                        }
                    }
                }
            }

            Label {
                visible: root.foundApps.length === 0 && root.foundActions.length === 0
                width: resultCol.width
                topPadding: 30
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing called “" + root.q + "”"
                size: 14
                color: Theme.textSoft
            }
        }
    }

    // --- clipboard ---------------------------------------------------------------
    Item {
        visible: root.clipMode
        anchors.top: field.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Row {
            id: clipHead
            x: 22
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "content_paste"; size: 18; filled: true }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Clipboard"; size: 16; weight: 700 }
        }
        Tag {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: clipHead.verticalCenter
            text: Clip.entries.length
            size: 11
            fill: Theme.secondary
        }

        Scroll {
            id: clipList
            anchors.top: clipHead.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.5
            contentHeight: clipCol.height + 6
            Column {
                id: clipCol
                x: 16
                width: clipList.width - 32
                spacing: 7
                Repeater {
                    model: root.clips
                    Tap {
                        id: clipRow
                        required property var modelData
                        required property int index
                        width: clipCol.width - (clipRow.index % 2) * 6
                        x: (clipRow.index % 2) * 6
                        height: 34
                        radius: 14
                        icon: "notes"
                        iconSize: 14
                        text: modelData.preview.replace(/\s+/g, " ").slice(0, 80)
                        textSize: 12
                        maxText: width - 60
                        fill: root.selected === clipRow.index ? Theme.secondary : Theme.paper
                        onClicked: root.selected = clipRow.index
                        onRightClicked: { Clip.copy(modelData.id); Ui.closePhone(); }
                    }
                }
                Label {
                    visible: root.clips.length === 0
                    text: Clip.available ? "Nothing copied yet" : "cliphist is not running"
                    size: 13
                    color: Theme.textSoft
                }
            }
        }

        Sticker {
            id: preview
            anchors.top: clipList.bottom
            anchors.topMargin: 12
            x: 16
            width: parent.width - 32
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            radius: 18
            fill: Theme.paper2
            readonly property var entry: root.clips[root.selected] || null
            Text {
                x: 14; y: 12
                width: parent.width - 28
                height: parent.height - 64
                text: preview.entry ? preview.entry.preview : ""
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 12
            }
            Label {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                text: preview.entry ? preview.entry.preview.length + " characters" : ""
                size: 10
                color: Theme.textSoft
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 8
                Tap { width: 34; height: 30; radius: 10; icon: "delete"; fill: Theme.tertiary; enabled: !!preview.entry; onClicked: Clip.remove(preview.entry) }
                Tap { height: 30; text: "Copy"; fill: Theme.secondary; enabled: !!preview.entry; onClicked: root.activate(root.selected) }
            }
        }
    }
}
