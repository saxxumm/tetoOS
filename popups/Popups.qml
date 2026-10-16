import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import "root:/theme"
import "root:/ui"
import "root:/services"
import "root:/desktop"

// The bar's drop-down cards (battery, weather, calendar, player) and the
// desktop's right-click menu. One overlay that exists only while something in
// it is open, and closes it on any click outside.
PanelWindow {
    id: win

    screen: Ui.popupScreen || Quickshell.screens[0]
    readonly property bool open: Ui.popup !== "" || Ui.deskMenuOpen
    visible: win.open || fade.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tetoos-popup"
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property real shown: win.open ? 1 : 0
    Behavior on shown { NumberAnimation { id: fade; duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: { Ui.closePopup(); Ui.deskMenuOpen = false; }
    }
    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: { Ui.closePopup(); Ui.deskMenuOpen = false; }
    }

    // --- the drop-down card ----------------------------------------------------
    property string which: ""
    Connections {
        target: Ui
        function onPopupChanged() { if (Ui.popup !== "") win.which = Ui.popup; }
    }

    readonly property bool barBottom: Config.ready && Config.options.barPosition === "bottom"
    Item {
        id: card
        readonly property Item body: loader.item
        width: body ? body.implicitWidth : 0
        height: body ? body.implicitHeight : 0
        x: Math.max(10, Math.min(win.width - width - 10, (Ui.popupX < 0 ? win.width / 2 : Ui.popupX) - width / 2))
        y: win.which === "bread" ? (win.height - height) / 2 - (1 - win.shown) * 16
            : win.barBottom ? win.height - height - 58 - (1 - win.shown) * 16 : 52 + (1 - win.shown) * -16
        opacity: Ui.popup !== "" ? win.shown : 0
        scale: 0.94 + 0.06 * win.shown
        transformOrigin: win.barBottom ? Item.Bottom : Item.Top
        visible: opacity > 0.01

        MouseArea { anchors.fill: parent }
        Loader {
            id: loader
            active: win.which !== ""
            sourceComponent: win.which === "battery" ? battery
                : win.which === "weather" ? weather
                : win.which === "calendar" ? calendar
                : win.which === "media" ? media
                : win.which === "bread" ? bread : null
        }
    }

    Component {
        id: weather
        WeatherWidget { dark: true; implicitWidth: 330; implicitHeight: 280 }
    }

    // --- battery -------------------------------------------------------------------
    Component {
        id: battery
        Sticker {
            implicitWidth: 330
            implicitHeight: 300
            fill: Theme.night
            radius: 16
            lift: 4
            Sticker {
                id: top
                x: 10; y: 10
                width: parent.width - 20; height: 92
                radius: 12
                lift: 2
                fill: Theme.primary
                gloss: true
                Row {
                    x: 14; y: 6
                    spacing: 2
                    Label { text: Math.round(Power.level * 100); size: 50; weight: 700 }
                    Label { anchors.bottom: parent.bottom; anchors.bottomMargin: 14; text: "%"; size: 22; weight: 700 }
                }
                Row {
                    x: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    spacing: 6
                    BatteryGlyph { anchors.verticalCenter: parent.verticalCenter }
                    Label { text: Power.charging ? "Plugged in" : "On battery · " + Power.timeLeft; size: 12; weight: 700 }
                }
                Tag {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 14
                    text: Power.level > 0.6 ? "GREAT" : Power.level > 0.3 ? "OKAY" : Power.level > 0.15 ? "LOW" : "CHARGE ME"
                    size: 13
                    fill: Theme.paper
                }
            }
            Column {
                x: 16
                anchors.top: top.bottom
                anchors.topMargin: 14
                width: parent.width - 32
                spacing: 10
                Row {
                    spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.primary }
                    Label { text: "LIFE GAUGE"; size: 10; weight: 700; color: Theme.nightText; font.letterSpacing: 0.8 }
                }
                Row {
                    spacing: 5
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            width: 24; height: 18
                            radius: 6
                            color: index < Math.round(Power.level * 10) ? Theme.primary : Theme.alpha(Theme.nightText, 0.12)
                            border.color: Theme.alpha(Theme.nightText, 0.3)
                            border.width: 1
                        }
                    }
                }
                Row {
                    spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Theme.secondary }
                    Label { text: "POWER MODE"; size: 10; weight: 700; color: Theme.nightText; font.letterSpacing: 0.8 }
                }
                Row {
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: "eco", label: "Saver", p: PowerProfile.PowerSaver },
                            { icon: "balance", label: "Balanced", p: PowerProfile.Balanced },
                            { icon: "rocket_launch", label: "Boost", p: PowerProfile.Performance }
                        ]
                        Tap {
                            required property var modelData
                            width: (298 - 16) / 3
                            height: 50
                            radius: 12
                            icon: modelData.icon
                            text: modelData.label
                            textSize: 12
                            active: Power.profile === modelData.p
                            fill: active ? Theme.secondary : Theme.night2
                            fg: active ? Theme.text : Theme.nightText
                            enabled: modelData.p !== PowerProfile.Performance || Power.hasProfiles
                            onClicked: Power.setProfile(modelData.p)
                        }
                    }
                }
            }
        }
    }

    // --- calendar ------------------------------------------------------------------
    Component {
        id: calendar
        Sticker {
            id: cal
            implicitWidth: 330
            implicitHeight: 318
            radius: 16
            lift: 4
            property date month: new Date(Sys.now.getFullYear(), Sys.now.getMonth(), 1)
            readonly property var cells: {
                const first = new Date(cal.month.getFullYear(), cal.month.getMonth(), 1);
                const start = (first.getDay() + 6) % 7;        // weeks start on Monday
                const list = [];
                for (let i = 0; i < 42; i++) list.push(new Date(first.getFullYear(), first.getMonth(), i - start + 1));
                return list;
            }
            Row {
                x: 14; y: 12
                spacing: 8
                Sticker {
                    width: 36; height: 36; radius: 10; lift: 2; fill: Theme.primary
                    Icon { anchors.centerIn: parent; icon: "calendar_month"; size: 20; filled: true }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -4
                    Label { text: Qt.formatDate(cal.month, "MMMM"); size: 18; weight: 700 }
                    Label { text: Qt.formatDate(cal.month, "yyyy"); size: 11; weight: 500; color: Theme.textSoft }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 16
                spacing: 6
                Tap { width: 28; height: 28; icon: "chevron_left"; iconSize: 18; onClicked: cal.month = new Date(cal.month.getFullYear(), cal.month.getMonth() - 1, 1) }
                Tap { width: 28; height: 28; icon: "today"; iconSize: 16; onClicked: cal.month = new Date(Sys.now.getFullYear(), Sys.now.getMonth(), 1) }
                Tap { width: 28; height: 28; icon: "chevron_right"; iconSize: 18; onClicked: cal.month = new Date(cal.month.getFullYear(), cal.month.getMonth() + 1, 1) }
            }
            Grid {
                x: 14; y: 62
                columns: 7
                spacing: 4
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Label { required property string modelData; width: 40; horizontalAlignment: Text.AlignHCenter; text: modelData; size: 10; weight: 700; color: Theme.textSoft }
                }
                Repeater {
                    model: cal.cells
                    Sticker {
                        id: day
                        required property var modelData
                        readonly property bool today: modelData.toDateString() === Sys.now.toDateString()
                        readonly property bool inMonth: modelData.getMonth() === cal.month.getMonth()
                        width: 40; height: 32
                        radius: 9
                        lift: today ? 2 : 0
                        outline: today ? 2 : 0
                        fill: today ? Theme.primary : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: day.modelData.getDate()
                            size: 13
                            weight: day.today ? 700 : 600
                            color: day.inMonth ? Theme.text : Theme.alpha(Theme.textSoft, 0.45)
                        }
                    }
                }
            }
        }
    }

    // --- player --------------------------------------------------------------------
    Component {
        id: media
        Sticker {
            implicitWidth: 340
            implicitHeight: 152
            radius: 16
            lift: 4
            fill: Theme.paper
            ClippingRectangle {
                id: art
                x: 12; y: 12
                width: 96; height: 96
                radius: 14
                color: Theme.secondary
                border.color: Theme.ink
                border.width: 2
                Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; sourceSize.width: 256; asynchronous: true }
                Icon { anchors.centerIn: parent; visible: Media.art === ""; icon: "album"; size: 44; filled: true }
            }
            Column {
                anchors.left: art.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 14
                spacing: -2
                Label { width: parent.width; text: Media.has ? Media.title : "Nothing playing"; size: 16; weight: 700 }
                Label { width: parent.width; text: Media.artist; size: 12; weight: 500; color: Theme.textSoft }
                Label { width: parent.width; text: Media.identity; size: 10; weight: 600; color: Theme.alpha(Theme.textSoft, 0.7) }
            }
            Row {
                anchors.left: art.right
                anchors.leftMargin: 12
                y: 72
                spacing: 8
                Tap { width: 34; height: 34; icon: "skip_previous"; onClicked: Media.previous() }
                Tap { width: 40; height: 40; icon: Media.playing ? "pause" : "play_arrow"; fill: Theme.primary; onClicked: Media.toggle() }
                Tap { width: 34; height: 34; icon: "skip_next"; onClicked: Media.next() }
                Tap { width: 34; height: 34; icon: "swap_horiz"; visible: Media.players.length > 1; onClicked: Media.cycle() }
            }
            Row {
                x: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 8
                Label { anchors.verticalCenter: parent.verticalCenter; text: Media.formatTime(Media.position); size: 10; weight: 600; color: Theme.textSoft }
                Slide { anchors.verticalCenter: parent.verticalCenter; width: 340 - 24 - 80; height: 10; value: Media.progress; onMoved: v => Media.seek(v) }
                Label { anchors.verticalCenter: parent.verticalCenter; text: Media.formatTime(Media.length); size: 10; weight: 600; color: Theme.textSoft }
            }
        }
    }

    // --- the bread of the day ---------------------------------------------------------
    Component {
        id: bread
        Sticker {
            id: loaf
            readonly property var card: Bread.last
            readonly property int stars: card ? card.stars : 0
            implicitWidth: 340
            implicitHeight: 396
            radius: 20
            lift: 5
            fill: Theme.paper
            Row {
                x: 16; y: 14
                spacing: 9
                Sticker {
                    width: 36; height: 36; radius: 10; lift: 2; fill: Theme.primary
                    Icon { anchors.centerIn: parent; icon: "bakery_dining"; size: 21; filled: true }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -4
                    Label { text: "Батон дня"; size: 18; weight: 700 }
                    Label { text: Qt.formatDate(Sys.now, "d MMMM") + " · коллекция " + Bread.collected + "/" + Bread.cards.length; size: 10; weight: 500; color: Theme.textSoft }
                }
            }
            Sticker {
                id: face
                x: 16; y: 64
                width: parent.width - 32
                height: 250
                radius: 16
                lift: 4
                fill: loaf.stars >= 5 ? Theme.warn : loaf.stars >= 4 ? Theme.secondary : loaf.stars >= 3 ? Theme.tertiary : Theme.primary
                gloss: true
                Dots { anchors.fill: parent; anchors.margins: 3; dot: Theme.alpha(Theme.ink, 0.10); spacing: 14 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    spacing: 2
                    Repeater {
                        model: 5
                        Icon {
                            required property int index
                            icon: "star"
                            filled: index < loaf.stars
                            size: 24
                            color: index < loaf.stars ? Theme.ink : Theme.alpha(Theme.ink, 0.25)
                            scale: index < loaf.stars ? 1 : 0.85
                        }
                    }
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 44
                    width: 29 * 4; height: 31 * 4
                    source: Quickshell.shellDir + "/assets/teto/eat.png"
                    smooth: false
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 0
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: loaf.card ? loaf.card.name : "Сегодня уже был"; size: 19; weight: 700 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: loaf.card ? loaf.card.text : "Новый батон — завтра ✦"; size: 12; weight: 500; color: Theme.textSoft }
                }
                Tag {
                    visible: !!loaf.card && loaf.card.count > 1
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: 12
                    text: "×" + (loaf.card ? loaf.card.count : 0)
                    size: 11
                    fill: Theme.paper
                }
            }
            Sticker {
                x: 16
                anchors.top: face.bottom
                anchors.topMargin: 14
                width: parent.width - 32
                height: fortune.implicitHeight + 18
                radius: 12
                lift: 2
                fill: Theme.night
                Label {
                    id: fortune
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    text: "✦ " + (loaf.card ? loaf.card.fortune : "Предсказание обновится завтра.")
                    size: 12
                    weight: 600
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    color: Theme.nightText
                }
            }
        }
    }

    // --- desktop menu ----------------------------------------------------------------
    Sticker {
        id: menu
        visible: Ui.deskMenuOpen
        x: Math.min(win.width - width - 8, Ui.deskMenuX)
        y: Math.min(win.height - height - 8, Ui.deskMenuY)
        width: 200
        height: menuCol.height + 12
        radius: 14
        lift: 4
        fill: Theme.night
        scale: Ui.deskMenuOpen ? 1 : 0.9
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        MouseArea { anchors.fill: parent }
        Column {
            id: menuCol
            x: 6; y: 6
            width: parent.width - 12
            Repeater {
                model: [
                    { icon: "edit", label: "Edit desktop", run: () => { Ui.editing = true; } },
                    { icon: "wallpaper", label: "Wallpapers", run: () => Ui.openPhone("wallpapers") },
                    { icon: "palette", label: "Group themes", run: () => Ui.openSettings("general") },
                    { icon: "terminal", label: "Terminal", run: () => Quickshell.execDetached(["kitty"]) },
                    { icon: "settings", label: "Settings", run: () => Ui.openPhone("settings") }
                ]
                Rectangle {
                    id: item
                    required property var modelData
                    width: menuCol.width
                    height: 34
                    radius: 9
                    color: itemArea.containsMouse ? Theme.night2 : "transparent"
                    Row {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Icon { icon: item.modelData.icon; size: 17; color: Theme.nightText; filled: itemArea.containsMouse }
                        Label { text: item.modelData.label; size: 13; weight: 600; color: Theme.nightText }
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Ui.deskMenuOpen = false; item.modelData.run(); }
                    }
                }
            }
        }
    }
}
