import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// The phone: one device that is the launcher and the control centre held
// upright, and the settings and the wallpaper picker turned on its side.
//
// It is drawn as an object rather than a panel — a slab with a thickness, a
// notch, side keys — tilted in perspective and leaning after the pointer.
// Turning it between pages is a real quarter turn: the new orientation starts
// rotated by 90° and springs flat.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tetoos-phone"
    WlrLayershell.keyboardFocus: Ui.phoneOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: Ui.phoneOpen || out.running

    property string page: ""
    readonly property bool landscape: page === "settings" || page === "wallpapers" || page === "sound"

    // a tilt that follows the pointer, a few degrees either way
    property real leanX: 0
    property real leanY: 0
    readonly property bool tilting: Config.ready && Config.options.tilt

    // orientation: target size, and the spin that sells the quarter turn
    readonly property real portraitW: 420
    readonly property real portraitH: 860
    readonly property real landscapeW: Math.min(1060, win.width - 160)
    readonly property real landscapeH: 520
    property real spin: 0
    property real rise: 1          // 1 = below the screen, 0 = in place

    Connections {
        target: Ui
        function onPhoneChanged() {
            if (Ui.phone === "") {
                out.restart();
                return;
            }
            const wasLandscape = win.landscape;
            const wasOpen = win.page !== "" && win.rise < 0.5;
            win.page = Ui.phone;
            if (!wasOpen) {
                out.stop();
                win.spin = win.landscape ? -14 : 10;
                enter.restart();
            } else if (wasLandscape !== win.landscape) {
                win.spin = win.landscape ? 90 : -90;
                turn.restart();
            }
        }
    }

    ParallelAnimation {
        id: enter
        NumberAnimation { target: win; property: "rise"; from: 1; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
        NumberAnimation { target: win; property: "spin"; to: 0; duration: 640; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }
    NumberAnimation {
        id: turn
        target: win
        property: "spin"
        to: 0
        duration: 620
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }
    SequentialAnimation {
        id: out
        NumberAnimation { target: win; property: "rise"; to: 1; duration: 300; easing.type: Easing.InBack; easing.overshoot: 1.1 }
        ScriptAction { script: { win.page = ""; win.spin = 0; } }
    }

    // outside the phone: close
    MouseArea {
        anchors.fill: parent
        hoverEnabled: win.tilting
        onClicked: Ui.closePhone()
        onPositionChanged: event => {
            if (!win.tilting) return;
            win.leanY = (event.x / width - 0.5) * 10;
            win.leanX = -(event.y / height - 0.5) * 8;
        }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: Ui.phoneOpen
        Keys.onEscapePressed: {
            if (Ui.powerRail) Ui.powerRail = false;
            else if (Ui.phone === "settings" && Ui.settingsPage !== "") Ui.settingsPage = "";
            else Ui.closePhone();
        }

        Item {
            id: device

            readonly property real targetW: win.landscape ? win.landscapeW : win.portraitW
            readonly property real targetH: win.landscape ? win.landscapeH : win.portraitH
            width: targetW
            height: targetH
            x: (win.width - width) / 2 + (win.landscape ? 0 : 40)
            y: win.landscape
                ? (win.height - height) / 2 + win.rise * win.height
                : win.height - height + 70 + win.rise * (height + 80)

            Behavior on leanSmoothX { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on leanSmoothY { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            property real leanSmoothX: win.leanX
            property real leanSmoothY: win.leanY

            transform: [
                Rotation {
                    origin.x: device.width / 2
                    origin.y: device.height / 2
                    axis { x: 0; y: 0; z: 1 }
                    angle: win.spin + (win.landscape ? -1.5 : 3)
                },
                Rotation {
                    origin.x: device.width / 2
                    origin.y: device.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: (win.landscape ? 8 : -16) + device.leanSmoothY
                },
                Rotation {
                    origin.x: device.width / 2
                    origin.y: device.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: (win.landscape ? 6 : 4) + device.leanSmoothX
                }
            ]

            // swallow clicks on the body so they do not close it
            MouseArea { anchors.fill: parent; hoverEnabled: false }

            // the slab's thickness, then the frame
            Rectangle {
                x: win.landscape ? 6 : 12
                y: 9
                width: parent.width
                height: parent.height
                radius: 58
                color: Theme.mix(Theme.ink, "black", 0.35)
            }
            // side keys, on the thick edge
            Repeater {
                model: win.landscape ? [[0.22, 0.1], [0.36, 0.07], [0.62, 0.12]] : [[0.2, 0.06], [0.29, 0.1], [0.42, 0.1]]
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool power: index === 2
                    x: win.landscape ? modelData[0] * device.width : device.width + 5
                    y: win.landscape ? -7 : modelData[0] * device.height
                    width: win.landscape ? modelData[1] * device.width * 0.6 : 9
                    height: win.landscape ? 9 : modelData[1] * device.height * 0.6
                    radius: 4
                    color: power && sideArea.containsMouse ? Theme.primaryStrong : Theme.mix(Theme.ink, "black", 0.2)
                    MouseArea {
                        id: sideArea
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: parent.power
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.powerRail = !Ui.powerRail
                    }
                }
            }
            Rectangle {
                id: frame
                anchors.fill: parent
                radius: 56
                color: Theme.ink
                border.color: Theme.mix(Theme.ink, "white", 0.18)
                border.width: 2
            }

            ClippingRectangle {
                id: screen
                anchors.fill: parent
                anchors.margins: 13
                radius: 44
                color: Theme.paper

                // the page, faded across on a change
                Loader {
                    id: content
                    anchors.fill: parent
                    anchors.topMargin: win.landscape ? 0 : 46
                    anchors.leftMargin: win.landscape ? 34 : 0
                    active: win.page !== ""
                    focus: true
                    source: win.page === "control" ? "ControlPage.qml"
                        : win.page === "launcher" ? "LauncherPage.qml"
                        : win.page === "settings" ? "SettingsPage.qml"
                        : win.page === "wallpapers" ? "WallpaperPage.qml"
                        : win.page === "sound" ? "SoundPage.qml"
                        : win.page === "wifi" || win.page === "bluetooth" ? "NetPage.qml" : ""
                    opacity: status === Loader.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                }

                // status row (portrait only): clock and the network's pulse
                Item {
                    visible: !win.landscape
                    x: 30
                    y: 14
                    width: parent.width - 60
                    height: 30
                    Column {
                        spacing: -4
                        Label { text: Sys.time(); size: 15; weight: 700 }
                        Label { text: Qt.formatDate(Sys.now, "ddd, d MMM"); size: 10; weight: 500; color: Theme.textSoft }
                    }
                    Row {
                        visible: win.page !== "control"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Icon { icon: Net.symbol; size: 15; filled: true }
                        BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; visible: Power.hasBattery }
                        Label { text: Math.round(Power.level * 100) + "%"; size: 11; weight: 700; visible: Power.hasBattery }
                    }
                }

                // the dim behind the power keys
                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.ink, 0.55)
                    opacity: Ui.powerRail ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    MouseArea { anchors.fill: parent; enabled: Ui.powerRail; onClicked: Ui.powerRail = false }
                }
            }

            // the notch: top centre upright, left centre on its side
            Rectangle {
                width: win.landscape ? 30 : 128
                height: win.landscape ? 128 : 30
                radius: 15
                x: win.landscape ? 20 : (parent.width - width) / 2
                y: win.landscape ? (parent.height - height) / 2 : 20
                color: Theme.ink
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: Theme.mix(Theme.ink, "white", 0.25)
                    x: win.landscape ? 10 : parent.width - 24
                    y: win.landscape ? parent.height - 24 : 10
                }
            }

            // power keys, fanned out along the side
            Column {
                anchors.left: parent.right
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: win.landscape ? 0 : -120
                spacing: 12
                Repeater {
                    model: [
                        { icon: "lock", tip: "Lock", act: () => { Ui.closePhone(); Ui.lockRequested(); } },
                        { icon: "dark_mode", tip: "Suspend", act: () => { Ui.closePhone(); Power.suspend(); } },
                        { icon: "downloading", tip: "Hibernate", act: () => { Ui.closePhone(); Power.hibernate(); } },
                        { icon: "logout", tip: "Log out", act: () => Power.logout() },
                        { icon: "restart_alt", tip: "Reboot", act: () => Power.reboot() },
                        { icon: "power_settings_new", tip: "Shut down", act: () => Power.shutdown() },
                        { icon: "dashboard_customize", tip: "Edit desktop", act: () => { Ui.closePhone(); Ui.editing = true; } },
                        { icon: "wallpaper", tip: "Wallpapers", act: () => Ui.openPhone("wallpapers") }
                    ]
                    Tap {
                        id: key
                        required property var modelData
                        required property int index
                        width: 46; height: 46
                        icon: modelData.icon
                        iconSize: 22
                        fill: index === 5 ? Theme.bad : Theme.paper
                        opacity: Ui.powerRail ? 1 : 0
                        scale: Ui.powerRail ? 1 : 0.4
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160 + key.index * 30 } }
                        Behavior on scale { NumberAnimation { duration: 260 + key.index * 30; easing.type: Easing.OutBack } }
                        onClicked: modelData.act()
                        Tag {
                            visible: key.hovered
                            anchors.left: parent.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: key.modelData.tip
                            size: 11
                            fill: Theme.paper
                        }
                    }
                }
            }
        }
    }
}
