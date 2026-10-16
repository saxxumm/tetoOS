import QtQuick
import Quickshell
import "root:/theme"
import "root:/ui"
import "root:/services"

// Settings, with the phone on its side: six cards, each a page of switches.
Item {
    id: root

    readonly property var cards: [
        { key: "quick", title: "Quick", sub: "The things you reach for most", icon: "tune", tint: Theme.primary },
        { key: "general", title: "General", sub: "Look, palette and clock", icon: "palette", tint: Theme.secondary },
        { key: "bar", title: "Bar", sub: "Where it sits and what it carries", icon: "toolbar", tint: Theme.tertiary },
        { key: "desktop", title: "Desktop", sub: "Wallpaper, widgets and effects", icon: "wallpaper", tint: Theme.secondary },
        { key: "canvas", title: Compositor.name, sub: "Workspaces and windows", icon: "grid_view", tint: Theme.tertiary },
        { key: "about", title: "tetoOS", sub: "Teto, sounds, lyrics, credits", icon: "favorite", tint: Theme.primary }
    ]
    readonly property var current: root.cards.find(c => c.key === Ui.settingsPage) || null

    // --- header --------------------------------------------------------------
    Sticker {
        id: title
        x: 14; y: 16
        width: 300; height: 46
        radius: 16
        fill: root.current ? root.current.tint : Theme.secondary
        gloss: true
        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Sticker {
                width: 30; height: 30
                radius: 9
                lift: 0
                fill: Theme.paper
                Icon { anchors.centerIn: parent; icon: root.current ? root.current.icon : "settings"; size: 18; filled: true }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4
                Label { text: root.current ? root.current.title : "Settings"; size: 18; weight: 700 }
                Label { text: root.current ? root.current.sub : "Pick what you want to change"; size: 10; weight: 500; color: Theme.textSoft }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 20
        spacing: 9
        Tap { visible: root.current !== null; height: 34; icon: "apps"; text: "Menu"; onClicked: Ui.settingsPage = "" }
        Sticker {
            width: 110; height: 38
            radius: 13
            lift: 2
            Column {
                anchors.centerIn: parent
                spacing: -4
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Sys.time(); size: 15; weight: 700 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(Sys.now, "ddd, d MMM"); size: 9; weight: 500; color: Theme.textSoft }
            }
        }
        Tap { width: 36; height: 36; icon: "close"; onClicked: Ui.closePhone() }
    }

    // --- home: the six cards ---------------------------------------------------
    Grid {
        id: home
        visible: root.current === null
        anchors.top: title.bottom
        anchors.topMargin: 22
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 3
        spacing: 18
        Repeater {
            model: root.cards
            Item {
                id: card
                required property var modelData
                required property int index
                width: (root.width - 28 - 36) / 3
                height: (root.height - 120 - 18) / 2
                readonly property real sink: cardArea.pressed ? 4 : 0
                Sticker {
                    y: card.sink
                    width: parent.width; height: parent.height
                    radius: 20
                    lift: 5 - card.sink
                    fill: Theme.paper

                    Rectangle {
                        x: 2; y: 2
                        height: parent.height - 4
                        width: (parent.width - 4) * (cardArea.containsMouse ? 1 : 0.32)
                        radius: 18
                        color: Theme.alpha(card.modelData.tint, 0.8)
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        y: 10
                        text: String(card.index + 1).padStart(2, "0")
                        size: 38
                        weight: 700
                        color: Theme.alpha(Theme.ink, 0.12)
                    }
                    Sticker {
                        x: 22; y: 22
                        width: 42; height: 42
                        radius: 12
                        rotation: 45
                        lift: 2
                        fill: card.modelData.tint
                        Icon { anchors.centerIn: parent; rotation: -45; icon: card.modelData.icon; size: 22; filled: true }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        y: 62
                        spacing: 4
                        Repeater {
                            model: [Theme.primaryStrong, Theme.secondaryStrong, Theme.tertiaryStrong]
                            Rectangle { required property color modelData; width: 7; height: 18; radius: 3; rotation: 20; color: modelData }
                        }
                    }
                    Column {
                        x: 20
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        spacing: -4
                        Label { text: card.modelData.title; size: 26; weight: 700 }
                        Label { text: card.modelData.sub; size: 11; weight: 500; color: Theme.textSoft }
                    }
                }
                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ui.settingsPage = card.modelData.key
                }
            }
        }
    }

    // --- pages -----------------------------------------------------------------------
    Scroll {
        id: page
        visible: root.current !== null
        anchors.top: title.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        contentHeight: pageCol.height + 24
        onVisibleChanged: contentY = 0

        Column {
            id: pageCol
            x: 14
            width: page.width - 34
            spacing: 22
            topPadding: 8

            // QUICK -------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "quick"
                label: "Panels"; icon: "view_quilt"; tint: Theme.primary
                Flow {
                    width: parent.width; spacing: 10
                    Toggle { label: "Bar"; on: Config.options.bar; onFlip: Config.toggle("bar") }
                    Toggle { label: "Dock"; on: Config.options.dock; onFlip: Config.toggle("dock") }
                    Toggle { label: "Visualizer"; on: Config.options.visualizer; onFlip: Config.toggle("visualizer") }
                    Toggle { label: "Phone tilt"; on: Config.options.tilt; onFlip: Config.toggle("tilt") }
                }
            }
            Section {
                visible: Ui.settingsPage === "quick" || Ui.settingsPage === "bar"
                label: "Bar"; icon: "toolbar"; tint: Theme.warn
                Choice { label: "Style"; options: ["float", "straight", "transparent"]; value: Config.options.barStyle; onPick: v => Config.options.barStyle = v }
                Choice { label: "Position"; options: ["top", "bottom"]; value: Config.options.barPosition; onPick: v => Config.options.barPosition = v }
            }
            Section {
                visible: Ui.settingsPage === "quick" || Ui.settingsPage === "desktop"
                label: "Desktop widgets"; icon: "widgets"; tint: Theme.secondary
                Flow {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: [["clock", "Clock"], ["user", "User card"], ["weather", "Weather card"], ["todo", "To-Do"], ["calendar", "Calendar"], ["system", "System"], ["visualizer", "Visualizer"]]
                        Toggle {
                            required property var modelData
                            label: modelData[1]
                            on: Config.widget(modelData[0]).on
                            onFlip: Config.setWidget(modelData[0], { on: !Config.widget(modelData[0]).on })
                        }
                    }
                }
            }

            // GENERAL --------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "general"
                label: "Look"; icon: "contrast"; tint: Theme.secondary
                Choice { label: "Mode"; options: ["light", "dark", "auto"]; value: Config.options.mode; onPick: v => Config.options.mode = v }
                Flow {
                    width: parent.width; spacing: 10
                    Toggle { label: "24-hour clock"; on: Config.options.clock24; onFlip: Config.toggle("clock24") }
                    Toggle { label: "Seconds"; on: Config.options.showSeconds; onFlip: Config.toggle("showSeconds") }
                    Toggle { label: "Phone tilt"; on: Config.options.tilt; onFlip: Config.toggle("tilt") }
                }
            }
            Section {
                visible: Ui.settingsPage === "general" || Ui.settingsPage === "desktop"
                label: "Palette"; icon: "palette"; tint: Theme.primary
                Flow {
                    width: parent.width; spacing: 10
                    Repeater {
                        model: Wallpaper.presets
                        Tap {
                            id: presetTap
                            required property var modelData
                            height: 38
                            text: modelData.label
                            icon: modelData.name === "wallpaper" ? "image" : ""
                            active: Config.options.palette === modelData.name
                            fill: active ? Theme.primary : Theme.paper
                            onClicked: Wallpaper.usePreset(modelData.name)
                            Row {
                                visible: presetTap.modelData.seeds.length > 0
                                anchors.right: parent.right
                                anchors.rightMargin: -6
                                anchors.top: parent.top
                                anchors.topMargin: -8
                                spacing: -4
                                Repeater {
                                    model: presetTap.modelData.seeds
                                    Rectangle { required property string modelData; width: 14; height: 14; radius: 7; color: modelData; border.color: Theme.ink; border.width: 2 }
                                }
                            }
                        }
                    }
                }
            }

            // BAR ------------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "bar"
                label: "Modules"; icon: "view_week"; tint: Theme.tertiary
                Flow {
                    width: parent.width; spacing: 10
                    Toggle { label: "Player"; on: Config.options.barMedia; onFlip: Config.toggle("barMedia") }
                    Toggle { label: "Tray"; on: Config.options.barTray; onFlip: Config.toggle("barTray") }
                    Toggle { label: "Weather"; on: Config.options.barWeather; onFlip: Config.toggle("barWeather") }
                    Toggle { label: "Window title"; on: Config.options.barWindow; onFlip: Config.toggle("barWindow") }
                }
            }

            // DESKTOP --------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "desktop"
                label: "Wallpaper"; icon: "image"; tint: Theme.tertiary
                Row {
                    spacing: 10
                    Tap { height: 38; icon: "wallpaper"; text: "Open the picker"; fill: Theme.primary; onClicked: Ui.openPhone("wallpapers") }
                    Tap { height: 38; icon: "dashboard_customize"; text: "Edit desktop"; onClicked: { Ui.closePhone(); Ui.editing = true; } }
                    Tap { height: 38; icon: "shuffle"; text: "Next"; onClicked: Wallpaper.next(1) }
                    Toggle { label: "Lock widgets"; on: Config.options.widgetsLocked; onFlip: Config.toggle("widgetsLocked") }
                }
                Label { text: "Folder: " + Config.options.wallpaperDir; size: 12; weight: 500; color: Theme.textSoft }
            }

            // CANVAS ---------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "canvas"
                label: Compositor.hypr ? "Workspaces" : "Canvas"; icon: "grid_view"; tint: Theme.secondary
                Label { text: "Workspace " + Compositor.workspace + " of " + Compositor.workspaceCount + (Compositor.hypr ? "" : " · zoom " + Math.round(Compositor.zoom * 100) + "%") + " · layout " + Compositor.layout; size: 13; weight: 600 }
                Row {
                    spacing: 10
                    Tap { visible: Compositor.hasOverview; height: 38; icon: "zoom_out_map"; text: "Overview"; onClicked: { Ui.closePhone(); Compositor.action("zoom-to-fit"); } }
                    Tap { visible: Compositor.hasOverview; height: 38; icon: "undo"; text: "Restore view"; onClicked: Compositor.action("restore-view") }
                    Tap { height: 38; icon: "keyboard"; text: "Next layout"; onClicked: Compositor.nextLayout() }
                }
                Row {
                    spacing: 8
                    Repeater {
                        model: Compositor.numbers
                        Tap {
                            required property int modelData
                            width: 40; height: 40
                            text: String(modelData)
                            active: Compositor.workspace === modelData
                            onClicked: Compositor.go(modelData)
                        }
                    }
                }
            }
            Section {
                visible: Ui.settingsPage === "canvas"
                label: "Windows here"; icon: "select_window"; tint: Theme.primary
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: Compositor.canvasWindows
                        Tap {
                            required property var modelData
                            height: 34
                            text: modelData.title || modelData.app_id
                            sub: modelData.app_id
                            maxText: 220
                            active: modelData.is_focused
                            onClicked: { Ui.closePhone(); Compositor.focusWindow(modelData.id); }
                        }
                    }
                    Label { visible: Compositor.canvasWindows.length === 0; text: "No windows on this canvas"; size: 12; color: Theme.textSoft }
                }
            }

            // tetoOS -----------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "about"
                label: "Mini Teto"; icon: "face_5"; tint: Theme.primary
                Flow {
                    width: parent.width; spacing: 10
                    Toggle { label: "Teto in the corner"; on: Config.options.teto; onFlip: Config.toggle("teto") }
                    Toggle { label: "Her voice"; on: Config.options.tetoVoice; onFlip: Config.toggle("tetoVoice") }
                    Toggle { label: "Karaoke bubble"; on: Config.options.tetoKaraoke; onFlip: Config.toggle("tetoKaraoke") }
                }
                Choice { label: "Chatter"; options: ["quiet", "normal", "chatty"]; value: Config.options.tetoChatter; onPick: v => Config.options.tetoChatter = v }
                Choice { label: "Size"; options: ["3", "4", "5"]; value: String(Config.options.tetoScale); onPick: v => Config.options.tetoScale = Number(v) }
                Row {
                    spacing: 10
                    Tag { text: Config.options.tetoLove + " ❤ pets"; icon: "favorite"; size: 12; fill: Theme.primary }
                    Tag { text: "bread " + Bread.collected + "/" + Bread.cards.length; icon: "bakery_dining"; size: 12; fill: Theme.warn }
                    Tap { height: 30; icon: "music_note"; text: "Sing"; textSize: 12; onClicked: { Ui.closePhone(); Teto.singSong(); } }
                    Tap { height: 30; icon: "bakery_dining"; text: "Bread of the day"; textSize: 12; fill: Bread.ready ? Theme.primary : Theme.paper; onClicked: { Ui.closePhone(); Bread.open(); Ui.togglePopup("bread", -1, null); } }
                }
            }
            Section {
                visible: Ui.settingsPage === "about"
                label: "Sounds & lyrics"; icon: "volume_up"; tint: Theme.tertiary
                Flow {
                    width: parent.width; spacing: 10
                    Toggle { label: "Interface sounds"; on: Config.options.sounds; onFlip: Config.toggle("sounds") }
                    Toggle { label: "Lyrics (lrclib.net)"; on: Config.options.lyrics; onFlip: Config.toggle("lyrics") }
                    Toggle { label: "Lyrics on the bar"; on: Config.options.lyricsBar; onFlip: Config.toggle("lyricsBar") }
                }
                Row {
                    spacing: 10
                    Label { anchors.verticalCenter: parent.verticalCenter; width: 80; text: "Volume"; size: 13; weight: 700 }
                    Slide { anchors.verticalCenter: parent.verticalCenter; width: 300; height: 14; value: Config.options.soundVolume; onMoved: v => Config.options.soundVolume = Math.round(v * 20) / 20 }
                    Tap { anchors.verticalCenter: parent.verticalCenter; height: 30; icon: "graphic_eq"; text: "Equalizer"; textSize: 12; onClicked: Ui.openPhone("sound") }
                }
            }

            // ABOUT ----------------------------------------------------------------
            Section {
                visible: Ui.settingsPage === "about"
                label: "About"; icon: "info"; tint: Theme.secondary
                Label { text: "A sticker-sheet shell for sxmwm, reverse-engineered from a video and repainted after its wallpaper."; size: 13; weight: 600; width: parent.width; wrapMode: Text.Wrap }
                Label { text: "Quickshell · Qt " + "6 · palette hues " + Theme.hues.map(h => Math.round(h) + "°").join(" / ") + " · " + (Theme.dark ? "dark" : "light"); size: 12; weight: 500; color: Theme.textSoft }
                Row {
                    spacing: 8
                    Repeater {
                        model: ["paper", "paper3", "primary", "primaryStrong", "secondary", "secondaryStrong", "tertiary", "tertiaryStrong", "night", "ink"]
                        Column {
                            required property string modelData
                            spacing: 3
                            Sticker { width: 52; height: 36; radius: 10; lift: 2; fill: Theme[parent.modelData] }
                            Label { width: 52; horizontalAlignment: Text.AlignHCenter; text: parent.modelData; size: 8; weight: 600; color: Theme.textSoft }
                        }
                    }
                }
                Row {
                    spacing: 10
                    Tap { height: 36; icon: "lock"; text: "Preview lock screen"; onClicked: { Ui.closePhone(); Ui.lockPreview = true; } }
                    Tap { height: 36; icon: "notifications"; text: "Test notification"; onClicked: Notifs.demo("tetoOS", "Hello from Teto", "Your palette was picked from the wallpaper.", "") }
                }
            }
        }
    }

    // --- pieces ------------------------------------------------------------------------
    component Section: Column {
        id: section
        property string label: ""
        property string icon: ""
        property color tint: Theme.primary
        default property alias body: inner.data
        width: pageCol.width
        spacing: -10
        Tag { z: 2; x: 18; text: section.label; icon: section.icon; fill: section.tint; size: 13 }
        Sticker {
            width: section.width
            height: inner.height + 40
            radius: 20
            lift: 4
            fill: Theme.paper
            Column {
                id: inner
                x: 20; y: 24
                width: parent.width - 40
                spacing: 12
            }
        }
    }

    component Toggle: Tap {
        property string label: ""
        property bool on: false
        signal flip()
        height: 42
        width: 196
        radius: 16
        icon: on ? "toggle_on" : "toggle_off"
        iconSize: 24
        iconFilled: on
        text: label
        sub: on ? "ON" : "OFF"
        active: on
        fill: on ? Theme.primary : Theme.paper
        gloss: on
        onClicked: flip()
    }

    component Choice: Row {
        id: choice
        property string label: ""
        property var options: []
        property string value: ""
        signal pick(string v)
        spacing: 10
        Label { anchors.verticalCenter: parent.verticalCenter; width: 80; text: choice.label; size: 13; weight: 700 }
        Repeater {
            model: choice.options
            Tap {
                required property string modelData
                height: 32
                width: 116
                radius: 10
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                active: choice.value === modelData
                fill: active ? Theme.primary : Theme.paper
                onClicked: choice.pick(modelData)
            }
        }
    }
}
