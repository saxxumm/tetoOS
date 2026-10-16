import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/theme"
import "root:/ui"
import "root:/services"

// The bar's pills, laid out in three groups. Used by the bar window and,
// non-interactive, inside the edit mode's miniature desktop.
Item {
    id: root

    property var screen: null
    property bool live: true
    readonly property string style: Config.ready ? Config.options.barStyle : "float"
    readonly property bool flat: root.style !== "float"
    readonly property real lift: root.flat ? 0 : Theme.lift
    readonly property real h: 28

    // centre of an item, in this bar's (= the screen's) coordinates
    function centerOf(item) { return item.mapToItem(root, item.width / 2, 0).x; }

    // A straight bar is one band with the pills set into it.
    Sticker {
        visible: root.style === "straight"
        x: -Theme.outline
        y: Config.ready && Config.options.barPosition === "bottom" ? 0 : -Theme.outline - 10
        width: root.width + Theme.outline * 2
        height: root.height + 10 + Theme.outline
        radius: 0
        lift: Theme.lift
        fill: Theme.paper2
    }

    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Pill {
            id: wsLabel
            width: 92
            fill: Theme.primary
            onClicked: Compositor.hasOverview ? Compositor.action("zoom-to-fit") : Ui.togglePhone("launcher")
            Label { anchors.centerIn: parent; text: "Workspace " + Compositor.workspace; size: 12; weight: 700 }
        }

        Pill {
            id: media
            visible: Config.ready && Config.options.barMedia
            width: 150
            fill: Theme.paper
            onClicked: Ui.togglePopup("media", root.centerOf(media), root.screen)
            onMiddle: Media.toggle()
            onScrolled: d => d > 0 ? Media.next() : Media.previous()

            Rectangle {
                x: Theme.outline
                y: Theme.outline
                height: parent.height - Theme.outline * 2
                width: Math.max(0, (parent.width - Theme.outline * 2) * Media.progress)
                radius: height / 2
                color: Theme.primary
                visible: Media.has
            }
            ClippingRectangle {
                id: art
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height - 8
                height: width
                radius: width / 2
                color: Theme.secondary
                border.color: Theme.ink
                border.width: 2
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 64
                    sourceSize.height: 64
                    asynchronous: true
                    visible: Media.art !== ""
                }
                Icon { anchors.centerIn: parent; visible: Media.art === ""; icon: "music_note"; size: 12; filled: true }
            }
            Column {
                anchors.left: art.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.has ? (Media.title || Media.identity) : "Nothing playing"
                    size: 11
                    weight: 700
                }
                Label {
                    width: parent.width
                    visible: Media.has && Media.artist !== ""
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.artist
                    size: 9
                    weight: 500
                    color: Theme.textSoft
                }
            }
        }

        // the line being sung, typed in as it changes
        Pill {
            id: lyric
            visible: Config.ready && Config.options.lyricsBar && Lyrics.line !== "" && Media.playing
            width: Math.min(240, lyricText.implicitWidth + 40)
            fill: Theme.secondary
            onClicked: Config.options.tetoKaraoke = !Config.options.tetoKaraoke
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; icon: "lyrics"; size: 14; filled: true }
            Label {
                id: lyricText
                x: 28
                anchors.verticalCenter: parent.verticalCenter
                width: lyric.width - 38
                text: Lyrics.line
                size: 11
                weight: 700
                opacity: 1
                onTextChanged: { lyricIn.restart(); }
                NumberAnimation on opacity { id: lyricIn; from: 0; to: 1; duration: 260 }
            }
        }

        Pill {
            id: tray
            visible: !Demo.on && Config.ready && Config.options.barTray && SystemTray.items.values.length > 0
            width: trayRow.implicitWidth + 18
            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: SystemTray.items
                    IconImage {
                        id: trayIcon
                        required property var modelData
                        implicitSize: 16
                        source: modelData.icon
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            enabled: root.live
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: event => {
                                const it = trayIcon.modelData;
                                if (event.button === Qt.RightButton || it.onlyMenu) {
                                    if (it.hasMenu) {
                                        const p = trayIcon.mapToItem(null, 0, trayIcon.height + 8);
                                        it.display(QsWindow.window, p.x, p.y);
                                    }
                                } else if (event.button === Qt.MiddleButton) it.secondaryActivate();
                                else it.activate();
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Pill {
            id: status
            width: statusRow.implicitWidth + 22
            onClicked: Ui.togglePhone("control")
            onScrolled: d => { Audio.step(d > 0 ? 0.05 : -0.05); Ui.showOsd("volume"); }
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 7
                Icon { icon: Net.symbol; size: 15; filled: true }
                Icon { icon: Bt.enabled ? (Bt.connectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"; size: 15; filled: true }
                Icon { icon: Audio.muted ? "volume_off" : Audio.volume > 0.6 ? "volume_up" : Audio.volume > 0.2 ? "volume_down" : "volume_mute"; size: 15; filled: true }
            }
        }

        Pill {
            id: weather
            visible: Config.ready && Config.options.barWeather
            width: weatherRow.implicitWidth + 22
            onClicked: Ui.togglePopup("weather", root.centerOf(weather), root.screen)
            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 5
                Icon { icon: Weather.icon; size: 16; filled: true }
                Label { text: Weather.loaded ? Weather.temp + "°C" : "—"; size: 12; weight: 700 }
            }
        }

        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: Compositor.numbers
                Tap {
                    id: wsDot
                    required property int modelData
                    readonly property bool here: modelData === Compositor.workspace
                    anchors.verticalCenter: parent.verticalCenter
                    width: here ? 30 : 24
                    height: width
                    lift: root.lift
                    fill: here ? Theme.secondary : Theme.paper
                    enabled: root.live
                    onClicked: Compositor.go(modelData)
                    onWheel: d => Compositor.go(Math.max(1, Math.min(Compositor.workspaceCount, Compositor.workspace + (d > 0 ? -1 : 1))))
                    Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
                    Label { anchors.centerIn: parent; text: wsDot.modelData; size: wsDot.here ? 13 : 11; weight: 700 }
                }
            }
        }

        Pill {
            id: time
            width: timeLabel.implicitWidth + 22
            fill: Theme.paper
            onClicked: Ui.togglePopup("calendar", root.centerOf(time), root.screen)
            Label { id: timeLabel; anchors.centerIn: parent; text: Sys.time(); size: 12; weight: 700 }
        }

        Pill {
            id: date
            width: dateRow.implicitWidth + 22
            onClicked: Ui.togglePopup("calendar", root.centerOf(date), root.screen)
            Row {
                id: dateRow
                anchors.centerIn: parent
                spacing: 5
                Icon { icon: "calendar_month"; size: 15; filled: true }
                Label { text: Qt.formatDate(Sys.now, "ddd, MMM d"); size: 12; weight: 700 }
            }
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Pill {
            id: recPill
            visible: Rec.recording
            width: recRow.implicitWidth + 20
            fill: Theme.bad
            onClicked: Rec.stop()
            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9; height: 9; radius: 4.5
                    color: "white"
                    opacity: Rec.elapsed % 2 ? 1 : 0.35
                }
                Label { text: "REC " + Rec.clock; size: 12; weight: 700; color: "white" }
            }
        }

        Pill {
            width: toolRow.implicitWidth + 16
            Row {
                id: toolRow
                anchors.centerIn: parent
                spacing: 2
                ToolIcon { icon: "screenshot_region"; onUse: Quickshell.execDetached(["sh", "-c", "~/.config/sxmwm/scripts/snip 2>/dev/null || (grim -g \"$(slurp)\" - | wl-copy)"]) }
                ToolIcon { icon: "colorize"; onUse: Quickshell.execDetached(["sh", "-c", "hyprpicker -a"]) }
                ToolIcon { icon: "screen_record"; on: Rec.recording; onUse: Rec.toggle() }
                ToolIcon { icon: "nightlight"; on: Night.enabled; onUse: Night.toggle() }
                ToolIcon { icon: "contrast"; on: Theme.dark; onUse: Config.options.mode = Theme.dark ? "light" : "dark" }
                ToolIcon { icon: "coffee"; on: Caffeine.on; onUse: Caffeine.toggle() }
            }
        }

        Pill {
            id: battery
            visible: Power.hasBattery
            width: batRow.implicitWidth + 20
            fill: Power.low ? Theme.bad : Theme.paper
            onClicked: Ui.togglePopup("battery", root.centerOf(battery), root.screen)
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 4
                BatteryGlyph { anchors.verticalCenter: parent.verticalCenter }
                Label { text: Math.round(Power.level * 100) + "%"; size: 12; weight: 700 }
            }
        }

        Pill {
            id: mic
            width: 34
            fill: Audio.micMuted ? Theme.paper : Theme.tertiary
            onClicked: { Audio.toggleMicMute(); Ui.showOsd("mic"); }
            Icon { anchors.centerIn: parent; icon: Audio.micMuted ? "mic_off" : "mic"; size: 16; filled: true }
        }

        Pill {
            id: win
            visible: Config.ready && Config.options.barWindow
            width: Math.min(220, winRow.implicitWidth + 22)
            fill: Theme.secondary
            onClicked: Compositor.action("fit-window")
            Row {
                id: winRow
                anchors.centerIn: parent
                spacing: 6
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 16
                    readonly property var entry: Compositor.focusedApp !== "" && DesktopEntries.applications.values.length > 0
                        ? DesktopEntries.heuristicLookup(Compositor.focusedApp) : null
                    source: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
                    visible: source !== ""
                }
                Label {
                    text: Compositor.focusedTitle !== "" ? Compositor.focusedTitle : "Desktop"
                    size: 12
                    weight: 700
                    width: Math.min(implicitWidth, 170)
                }
            }
        }

        Tap {
            anchors.verticalCenter: parent.verticalCenter
            width: root.h
            height: root.h
            icon: "settings"
            iconSize: 17
            lift: root.lift
            fill: Theme.primary
            enabled: root.live
            onClicked: Ui.togglePhone("settings")
        }
    }

    // --- pieces ---------------------------------------------------------------

    component Pill: Item {
        id: pill
        property color fill: Theme.paper
        default property alias content: face.content
        signal clicked()
        signal middle()
        signal scrolled(int delta)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: root.h
        width: 60
        readonly property real sink: area.pressed ? root.lift : 0
        Sticker {
            id: face
            y: pill.sink
            width: pill.width
            height: pill.height
            radius: height / 2
            lift: root.lift - pill.sink
            fill: root.style === "transparent" ? Theme.alpha(pill.fill, 0.72)
                : area.containsMouse ? Theme.mix(pill.fill, Theme.paper, 0.4) : pill.fill
            Behavior on fill { ColorAnimation { duration: Theme.quick } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: root.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: event => event.button === Qt.MiddleButton ? pill.middle() : pill.clicked()
            onWheel: event => pill.scrolled(event.angleDelta.y)
            z: -1
        }
    }

    component ToolIcon: Item {
        id: tool
        property string icon: ""
        property bool on: false
        signal use()
        width: 24
        height: 24
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tool.on ? Theme.primary : toolArea.containsMouse ? Theme.paper3 : "transparent"
            border.color: tool.on ? Theme.ink : "transparent"
            border.width: 1.5
        }
        Icon { anchors.centerIn: parent; icon: tool.icon; size: 15; filled: tool.on }
        MouseArea {
            id: toolArea
            anchors.fill: parent
            enabled: root.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.use()
        }
    }
}
