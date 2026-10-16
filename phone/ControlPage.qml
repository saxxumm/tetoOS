import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// The control centre, held upright: who you are, the switches, the levels and
// what has been trying to get your attention.
Item {
    id: root

    // --- the network's pulse, sampled only while this page is open ----------
    property real rx: 0
    property real tx: 0
    property var last: null
    function human(bps) {
        if (bps < 1024) return Math.round(bps) + " B/s";
        if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + " KB/s";
        return (bps / 1048576).toFixed(1) + " MB/s";
    }
    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let r = 0, t = 0;
            for (const line of text().split("\n").slice(2)) {
                const f = line.trim().split(/[:\s]+/);
                if (f.length < 10 || f[0] === "lo") continue;
                r += Number(f[1]); t += Number(f[9]);
            }
            const now = Date.now();
            if (root.last) {
                const dt = (now - root.last.at) / 1000;
                root.rx = Math.max(0, (r - root.last.r) / dt);
                root.tx = Math.max(0, (t - root.last.t) / dt);
            }
            root.last = { r: r, t: t, at: now };
        }
    }
    Timer { running: true; repeat: true; interval: 1500; triggeredOnStart: true; onTriggered: netdev.reload() }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 30
        y: -40
        spacing: -4
        Label { anchors.right: parent.right; text: root.human(root.rx) + " ↓"; size: 10; weight: 700 }
        Label { anchors.right: parent.right; text: root.human(root.tx) + " ↑"; size: 10; weight: 600; color: Theme.textSoft }
    }

    // --- banner ---------------------------------------------------------------
    ClippingRectangle {
        id: banner
        x: 12
        y: 4
        width: parent.width - 24
        height: 118
        radius: 24
        color: Theme.paper3
        border.color: Theme.ink
        border.width: 2
        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 800
            sourceSize.height: 450
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.45; color: Theme.alpha(Theme.paper, 0) }
                GradientStop { position: 1; color: Theme.alpha(Theme.paper, 0.85) }
            }
        }
    }

    Avatar {
        id: face
        x: 26
        y: banner.y + banner.height - 42
        width: 72; height: 72
        radius: 36
    }
    Column {
        anchors.left: face.right
        anchors.leftMargin: 10
        anchors.top: banner.bottom
        anchors.topMargin: 4
        spacing: -4
        Label { text: Sys.name; size: 16; weight: 700; width: 120 }
        Label { text: Sys.user + "@" + Sys.host; size: 10; weight: 500; color: Theme.textSoft; width: 120 }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: banner.bottom
        anchors.topMargin: 6
        spacing: 7
        Tap { width: 36; height: 36; icon: "settings"; onClicked: Ui.openPhone("settings") }
        Tap { width: 36; height: 36; icon: "wallpaper"; onClicked: Ui.openPhone("wallpapers") }
        Tap { width: 36; height: 36; icon: "dashboard_customize"; onClicked: { Ui.closePhone(); Ui.editing = true; } }
        Tap { width: 36; height: 36; icon: "power_settings_new"; fill: Theme.primary; onClicked: Ui.powerRail = !Ui.powerRail }
    }

    // --- switches ---------------------------------------------------------------
    Column {
        id: switches
        x: 16
        y: banner.y + banner.height + 52
        width: parent.width - 32
        spacing: 11

        Row {
            spacing: 9
            Big {
                icon: Net.symbol; title: "Wi-Fi"; sub: Net.label; active: Net.wifiEnabled
                onClicked: Net.toggleWifi()
                onRightClicked: Ui.openPhone("wifi")
                More { onOpen: Ui.openPhone("wifi") }
            }
            Big {
                icon: Bt.enabled ? "bluetooth" : "bluetooth_disabled"; title: "Bluetooth"; sub: Bt.label; active: Bt.enabled
                onClicked: Bt.toggle()
                onRightClicked: Ui.openPhone("bluetooth")
                More { onOpen: Ui.openPhone("bluetooth") }
            }
            Small { icon: "graphic_eq"; fill: Eq.routed ? Theme.primary : Theme.paper; onClicked: Ui.openPhone("sound") }
        }

        Row {
            spacing: 9
            Column {
                spacing: 6
                Big {
                    icon: Audio.micMuted ? "mic_off" : "mic"; title: "Microphone"; sub: Math.round(Audio.micVolume * 100) + "%"
                    active: !Audio.micMuted
                    onClicked: Audio.toggleMicMute()
                }
                Slide { width: parent.width; height: 12; value: Audio.micVolume; fill: Theme.secondaryStrong; onMoved: v => Audio.setMicVolume(v) }
            }
            Column {
                spacing: 6
                Big {
                    icon: Audio.muted ? "volume_off" : "volume_up"; title: "Speaker"; sub: Math.round(Audio.volume * 100) + "%"
                    active: !Audio.muted
                    onClicked: Audio.toggleMute()
                }
                Slide { width: parent.width; height: 12; value: Math.min(1, Audio.volume); onMoved: v => Audio.setVolume(v) }
            }
            Small { icon: "screenshot_region"; onClicked: { Ui.closePhone(); Quickshell.execDetached(["sh", "-c", "sleep 0.4; grim -g \"$(slurp)\" - | wl-copy"]); } }
        }

        Row {
            spacing: 9
            Big {
                icon: "nightlight"; title: "Night light"; sub: Night.enabled ? Night.temperature + "K" : "off"; active: Night.enabled
                onClicked: Night.toggle()
            }
            Big {
                icon: "contrast"; title: "Dark mode"; sub: Theme.dark ? "on" : "off"; active: Theme.dark
                onClicked: Config.options.mode = Theme.dark ? "light" : "dark"
            }
            Small { icon: "colorize"; onClicked: { Ui.closePhone(); Quickshell.execDetached(["sh", "-c", "sleep 0.3; hyprpicker -a"]); } }
        }

        Row {
            spacing: 9
            Big {
                icon: Notifs.doNotDisturb ? "notifications_off" : "notifications"; title: "Do not disturb"; sub: Notifs.doNotDisturb ? "quiet" : "off"
                active: Notifs.doNotDisturb
                onClicked: Notifs.toggleDnd()
            }
            Big {
                icon: "coffee"; title: "Caffeine"; sub: Caffeine.on ? "awake" : "off"; active: Caffeine.on
                onClicked: Caffeine.toggle()
            }
            Small { icon: "lock"; onClicked: { Ui.closePhone(); Ui.lockRequested(); } }
        }

        Row {
            spacing: 10
            visible: Brightness.available
            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "brightness_6"; size: 18; filled: true }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Brightness"; size: 12; weight: 700 }
            Slide {
                anchors.verticalCenter: parent.verticalCenter
                width: switches.width - 150
                height: 14
                value: Brightness.value
                fill: Theme.tertiaryStrong
                onMoved: v => Brightness.set(v)
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Brightness.value * 100) + "%"; size: 11; weight: 700 }
        }
    }

    // --- notifications ----------------------------------------------------------
    Sticker {
        id: tray
        anchors.top: switches.bottom
        anchors.topMargin: 26
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        radius: 24
        fill: Theme.paper2
        lift: 0

        Scroll {
            id: list
            anchors.fill: parent
            anchors.margins: 10
            anchors.topMargin: 20
            contentHeight: notes.height
            Column {
                id: notes
                width: list.width
                spacing: 8
                Repeater {
                    model: Notifs.history.slice(0, 20)
                    Sticker {
                        id: note
                        required property var modelData
                        width: notes.width
                        height: noteText.implicitHeight + 20
                        radius: 14
                        lift: 2
                        fill: Theme.paper
                        Column {
                            id: noteText
                            x: 12; y: 9
                            width: parent.width - 24
                            spacing: 0
                            Row {
                                spacing: 6
                                Label { text: note.modelData.appName || "notification"; size: 10; weight: 700; color: Theme.textSoft }
                                Label { text: Notifs.ago(note.modelData.time); size: 10; weight: 500; color: Theme.textSoft }
                            }
                            Label { width: parent.width; text: note.modelData.summary; size: 13; weight: 700 }
                            Label { width: parent.width; visible: text !== ""; text: note.modelData.body; size: 11; weight: 500; wrapMode: Text.Wrap; maximumLineCount: 3; color: Theme.textSoft }
                        }
                        MouseArea { anchors.fill: parent; onClicked: Notifs.forget(note.modelData.id) }
                    }
                }
                Column {
                    visible: Notifs.history.length === 0
                    width: notes.width
                    topPadding: 24
                    spacing: 4
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "notifications_paused"; size: 44; color: Theme.alpha(Theme.textSoft, 0.6) }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "All quiet"; size: 14; weight: 700; color: Theme.textSoft }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Teto approves of this silence"; size: 11; weight: 500; color: Theme.alpha(Theme.textSoft, 0.8) }
                }
            }
        }
    }
    Tag {
        anchors.horizontalCenter: tray.horizontalCenter
        anchors.verticalCenter: tray.top
        text: "Notifications"
        icon: "notifications"
        size: 12
        fill: Theme.paper
    }
    Tap {
        visible: Notifs.history.length > 0
        anchors.right: tray.right
        anchors.rightMargin: 12
        anchors.verticalCenter: tray.top
        height: 24
        text: "clear"
        textSize: 11
        lift: 2
        onClicked: { Notifs.clearHistory(); Notifs.dismissAll(); }
    }

    component Big: Tap {
        property string title: ""
        text: title
        width: (switches.width - 9 * 2 - 44) / 2
        height: 46
        radius: 23
        textSize: 13
        iconSize: 19
        fill: active ? Theme.primary : Theme.paper
        gloss: active
        maxText: width - 60
    }
    // the chevron at the end of a pill: the details page behind the switch
    component More: Item {
        id: more
        signal open()
        anchors.right: parent ? parent.right : undefined
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        anchors.rightMargin: 6
        width: 24; height: 30
        Icon { anchors.centerIn: parent; icon: "chevron_right"; size: 18; opacity: moreArea.containsMouse ? 1 : 0.55 }
        MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: more.open() }
    }

    component Small: Tap {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 42; height: 42
        iconSize: 19
    }
}
