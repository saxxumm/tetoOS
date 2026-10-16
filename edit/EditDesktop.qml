import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/theme"
import "root:/ui"
import "root:/services"
import "root:/desktop"
import "root:/bar"
import "root:/dock"

// Edit mode: the desktop shrinks into a framed miniature on a dotted board,
// widgets get handles and can be dragged, and a tray along the bottom adds
// and removes them, restyles the bar and swaps the palette.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    visible: Ui.editing || leave.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tetoos-edit"
    WlrLayershell.keyboardFocus: Ui.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property real t: 0                     // 0 = full size, 1 = miniature
    Connections {
        target: Ui
        function onEditingChanged() { Ui.editing ? enter.restart() : leave.restart(); }
    }
    NumberAnimation { id: enter; target: win; property: "t"; from: 0; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    NumberAnimation { id: leave; target: win; property: "t"; to: 0; duration: 360; easing.type: Easing.InOutCubic }

    readonly property real miniScale: 0.75
    readonly property real s: 1 - (1 - win.miniScale) * win.t
    readonly property real miniX: (win.width - win.width * win.s) / 2
    readonly property real miniY: 22 * win.t

    Item {
        anchors.fill: parent
        focus: Ui.editing
        Keys.onEscapePressed: Ui.editing = false
        Keys.onReturnPressed: Ui.editing = false
    }

    // the board
    Rectangle {
        anchors.fill: parent
        color: Theme.night
        opacity: win.t
        Dots { anchors.fill: parent; dot: Theme.alpha(Theme.nightText, 0.10); spacing: 22; radius: 1.6 }
    }

    // --- the miniature ------------------------------------------------------------
    Sticker {
        x: win.miniX - 8 * win.t
        y: win.miniY - 8 * win.t
        width: win.width * win.s + 16 * win.t
        height: win.height * win.s + 16 * win.t
        radius: 22 * win.t
        lift: 6 * win.t
        fill: Theme.paper
        edge: Theme.paper3
        outline: 3
    }
    Item {
        id: mini
        x: win.miniX
        y: win.miniY
        width: win.width
        height: win.height
        scale: win.s
        transformOrigin: Item.TopLeft
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1080
            asynchronous: true
        }
        Dots { anchors.fill: parent; dot: Theme.alpha(Theme.ink, 0.22); spacing: 36; radius: 2 }

        BarContent {
            id: miniBar
            visible: Config.options.bar
            live: true
            x: 0
            y: Config.options.barPosition === "bottom" ? parent.height - 46 + 6 : 6
            width: parent.width
            height: 34
        }
        DockContent {
            id: miniDock
            visible: Config.options.dock
            live: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: implicitWidth
            height: implicitHeight
        }
        // the bar and dock are pictures here, not controls
        MouseArea { x: miniBar.x; y: miniBar.y; width: miniBar.width; height: miniBar.height; visible: miniBar.visible; acceptedButtons: Qt.AllButtons }
        MouseArea { x: miniDock.x; y: miniDock.y; width: miniDock.width; height: miniDock.height; visible: miniDock.visible; acceptedButtons: Qt.AllButtons }

        Widgets {
            anchors.fill: parent
            editing: Ui.editing
        }
    }

    // --- the tray -------------------------------------------------------------------
    Sticker {
        id: tray
        x: 16
        width: win.width - 32
        height: 150
        y: win.height - height - 18 + (1 - win.t) * 220
        radius: 22
        lift: 6
        fill: Theme.paper

        // washi tape
        Rectangle { x: 60; y: -10; width: 70; height: 18; rotation: -4; color: Theme.alpha(Theme.good, 0.85) }
        Rectangle { x: parent.width - 150; y: -10; width: 80; height: 18; rotation: 3; color: Theme.alpha(Theme.primary, 0.9) }

        Column {
            id: legend
            x: 20; y: 18
            spacing: 6
            Row {
                spacing: 8
                Sticker { width: 20; height: 20; radius: 6; rotation: 45; lift: 0; fill: Theme.primary }
                Label { text: "EDIT DESKTOP"; size: 17; weight: 700; font.letterSpacing: 0.6 }
            }
            Label { text: "Pick it, place it, theme it"; size: 10; weight: 500; color: Theme.textSoft }
            Hint { key: "L"; text: "Left click: add / toggle" }
            Hint { key: "R"; text: "Right click: remove" }
            Hint { key: "✥"; text: "Drag: move" }
        }

        Column {
            id: tabs
            x: 236; y: 14
            spacing: 6
            Repeater {
                model: [["widgets", "WIDGETS", "widgets"], ["bar", "BAR", "toolbar"], ["theme", "THEME", "palette"], ["presets", "PRESETS", "auto_awesome_mosaic"]]
                Tap {
                    required property var modelData
                    width: 92; height: 24
                    radius: 8
                    lift: 2
                    text: modelData[1]
                    textSize: 10
                    active: Ui.editTab === modelData[0]
                    fill: active ? Theme.primary : Theme.paper
                    onClicked: Ui.editTab = modelData[0]
                }
            }
        }

        // tab content
        Item {
            id: shelf
            anchors.left: tabs.right
            anchors.leftMargin: 22
            anchors.right: actions.left
            anchors.rightMargin: 22
            y: 12
            height: parent.height - 24

            Row {
                visible: Ui.editTab === "widgets"
                anchors.centerIn: parent
                spacing: 14
                WidgetCard { name: "clock"; label: "CLOCK"; ClockWidget { scale: 0.32; anchors.centerIn: parent } }
                WidgetCard { name: "user"; label: "USER CARD"; UserWidget { scale: 0.3; anchors.centerIn: parent } }
                WidgetCard { name: "weather"; label: "WEATHER"; WeatherWidget { scale: 0.3; anchors.centerIn: parent; live: false } }
                WidgetCard { name: "todo"; label: "TO-DO"; TodoWidget { scale: 0.21; anchors.centerIn: parent; live: false } }
                WidgetCard { name: "calendar"; label: "CALENDAR"; CalendarWidget { scale: 0.3; anchors.centerIn: parent } }
                WidgetCard { name: "system"; label: "SYSTEM"; SystemWidget { scale: 0.3; anchors.centerIn: parent } }
                WidgetCard { name: "visualizer"; label: "VISUALIZER"; Visualizer { anchors.fill: parent; anchors.margins: 6 } }
            }

            Row {
                visible: Ui.editTab === "bar"
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: ["float", "straight", "transparent"]
                    ChoiceCard {
                        id: styleCard
                        required property string modelData
                        label: modelData.toUpperCase()
                        on: Config.options.barStyle === modelData
                        onPick: Config.options.barStyle = modelData
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 26; height: 12; radius: 6
                                    color: styleCard.modelData === "transparent" ? Theme.alpha(Theme.paper, 0.6) : Theme.paper
                                    border.color: Theme.ink
                                    border.width: styleCard.modelData === "straight" ? 0 : 1.5
                                }
                            }
                        }
                    }
                }
                ChoiceCard {
                    label: Config.options.barPosition === "top" ? "TOP" : "BOTTOM"
                    on: true
                    onPick: Config.options.barPosition = Config.options.barPosition === "top" ? "bottom" : "top"
                    Icon { anchors.centerIn: parent; icon: Config.options.barPosition === "top" ? "vertical_align_top" : "vertical_align_bottom"; size: 34; color: Theme.nightText }
                }
                ChoiceCard {
                    label: Config.options.dock ? "DOCK ON" : "DOCK OFF"
                    on: Config.options.dock
                    onPick: Config.toggle("dock")
                    Icon { anchors.centerIn: parent; icon: "dock_to_bottom"; size: 34; color: Theme.nightText }
                }
            }

            Row {
                visible: Ui.editTab === "theme"
                anchors.centerIn: parent
                spacing: 12
                Repeater {
                    model: Wallpaper.presets
                    ThemeCard {}
                }
            }

            Row {
                visible: Ui.editTab === "presets"
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: [
                        { label: "TETO RIGHT", icon: "view_sidebar", w: { clock: { x: 0.035, y: 0.62, on: true }, todo: { x: 0.80, y: 0.11, on: true }, user: { x: 0.585, y: 0.11, on: true }, weather: { x: 0.585, y: 0.385, on: true }, calendar: { x: 0.80, y: 0.52, on: false }, visualizer: { x: 0, y: 0.8, on: true } } },
                        { label: "LEFT COLUMN", icon: "view_column", w: { clock: { x: 0.80, y: 0.70, on: true }, todo: { x: 0.80, y: 0.11, on: false }, user: { x: 0.02, y: 0.08, on: true }, weather: { x: 0.02, y: 0.335, on: true }, calendar: { x: 0.02, y: 0.6, on: true }, visualizer: { x: 0, y: 0.8, on: true } } },
                        { label: "MINIMAL", icon: "crop_free", w: { clock: { x: 0.70, y: 0.70, on: true }, todo: { x: 0.8, y: 0.1, on: false }, user: { x: 0.6, y: 0.1, on: false }, weather: { x: 0.6, y: 0.4, on: false }, calendar: { x: 0.8, y: 0.5, on: false }, visualizer: { x: 0, y: 0.8, on: false } } },
                        { label: "EVERYTHING", icon: "dashboard", w: { clock: { x: 0.035, y: 0.62, on: true }, todo: { x: 0.80, y: 0.11, on: true }, user: { x: 0.585, y: 0.11, on: true }, weather: { x: 0.585, y: 0.385, on: true }, calendar: { x: 0.80, y: 0.53, on: true }, visualizer: { x: 0, y: 0.8, on: true } } }
                    ]
                    ChoiceCard {
                        id: presetCard
                        required property var modelData
                        label: modelData.label
                        on: false
                        onPick: Config.options.widgets = modelData.w
                        Icon { anchors.centerIn: parent; icon: presetCard.modelData.icon; size: 34; color: Theme.nightText }
                    }
                }
            }
        }

        Column {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Tap {
                width: 150; height: 44
                radius: 14
                icon: Config.options.widgetsLocked ? "lock" : "lock_open"
                text: Config.options.widgetsLocked ? "UNLOCK ALL" : "LOCK ALL"
                sub: Config.options.widgetsLocked ? "drag is off" : "stop drag after done"
                active: Config.options.widgetsLocked
                fill: Theme.secondary
                onClicked: Config.toggle("widgetsLocked")
            }
            Tap {
                width: 150; height: 44
                radius: 14
                icon: "check"
                text: "DONE"
                textSize: 15
                fill: Theme.primary
                gloss: true
                onClicked: Ui.editing = false
            }
        }
    }

    // --- pieces -----------------------------------------------------------------------
    component Hint: Row {
        id: hint
        property string key: ""
        property string text: ""
        spacing: 7
        Sticker {
            width: 18; height: 18; radius: 5; lift: 0; fill: Theme.night
            Label { anchors.centerIn: parent; text: hint.key; size: 9; weight: 700; color: Theme.nightText }
        }
        Label { anchors.verticalCenter: parent.verticalCenter; text: hint.text; size: 11; weight: 600 }
    }

    component WidgetCard: Item {
        id: wc
        property string name: ""
        property string label: ""
        default property alias preview: frame.data
        readonly property bool on: Config.widget(wc.name).on
        width: 118
        height: 118
        Sticker {
            id: box
            width: parent.width
            height: 96
            radius: 14
            lift: 3
            fill: Theme.night
            Item {
                id: frame
                anchors.fill: parent
                anchors.margins: 3
                clip: true
                opacity: wc.on ? 1 : 0.45
            }
        }
        Sticker {
            visible: wc.on
            anchors.right: box.right
            anchors.rightMargin: -6
            y: -6
            width: 22; height: 22; radius: 11; lift: 2
            fill: Theme.primary
            Icon { anchors.centerIn: parent; icon: "check"; size: 15; weight: 800 }
        }
        Sticker {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: lbl.implicitWidth + 18
            height: 20
            radius: 6
            lift: 0
            fill: Theme.night
            Label { id: lbl; anchors.centerIn: parent; text: wc.label; size: 9; weight: 700; color: Theme.nightText; font.letterSpacing: 0.5 }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => Config.setWidget(wc.name, { on: event.button === Qt.RightButton ? false : !wc.on })
        }
    }

    component ChoiceCard: Item {
        id: cc
        property string label: ""
        property bool on: false
        signal pick()
        default property alias art: ccFrame.data
        width: 118
        height: 118
        Sticker {
            id: ccBox
            width: parent.width; height: 96
            radius: 14
            lift: 3
            fill: Theme.night
            edge: cc.on ? Theme.primaryStrong : Theme.ink
            Item { id: ccFrame; anchors.fill: parent }
        }
        Sticker {
            visible: cc.on
            anchors.right: ccBox.right
            anchors.rightMargin: -6
            y: -6
            width: 22; height: 22; radius: 11; lift: 2
            fill: Theme.primary
            Icon { anchors.centerIn: parent; icon: "check"; size: 15; weight: 800 }
        }
        Sticker {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: ccl.implicitWidth + 18
            height: 20
            radius: 6
            lift: 0
            fill: cc.on ? Theme.primary : Theme.night
            Label { id: ccl; anchors.centerIn: parent; text: cc.label; size: 9; weight: 700; color: cc.on ? Theme.text : Theme.nightText }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cc.pick() }
    }

    component ThemeCard: Item {
        id: tc
        required property var modelData
        readonly property bool on: Config.options.palette === tc.modelData.name
        readonly property var seeds: tc.modelData.seeds.length > 0 ? tc.modelData.seeds : [Theme.primaryStrong, Theme.secondaryStrong, Theme.tertiaryStrong]
        width: 112
        height: 118
        Sticker {
            id: tcBox
            width: parent.width; height: 96
            radius: 14
            lift: 3
            fill: Theme.mix(Theme.night, tc.seeds[0], 0.25)
            edge: tc.on ? Theme.paper : Theme.ink
            Column {
                x: 10; y: 12
                spacing: 7
                Rectangle { width: 34; height: 9; radius: 4.5; color: tc.seeds[0] }
                Row {
                    spacing: 6
                    Rectangle { width: 46; height: 22; radius: 6; color: Theme.alpha("white", 0.12) }
                    Rectangle { width: 40; height: 22; radius: 6; color: tc.seeds[1] }
                }
                Row {
                    spacing: 6
                    Rectangle { width: 30; height: 12; radius: 6; color: tc.seeds[2] }
                    Rectangle { width: 12; height: 12; radius: 6; color: tc.seeds[0] }
                }
            }
            Icon { visible: tc.modelData.name === "wallpaper"; anchors.right: parent.right; anchors.rightMargin: 8; y: 8; icon: "image"; size: 18; color: "white"; filled: true }
        }
        Sticker {
            visible: tc.on
            anchors.right: tcBox.right
            anchors.rightMargin: -6
            y: -6
            width: 22; height: 22; radius: 11; lift: 2
            fill: Theme.primary
            Icon { anchors.centerIn: parent; icon: "check"; size: 15; weight: 800 }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tc.modelData.label
            size: 10
            weight: 700
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wallpaper.usePreset(tc.modelData.name) }
    }
}
