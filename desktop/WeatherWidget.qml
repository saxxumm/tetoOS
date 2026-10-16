import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// The weather card: now, the three numbers that matter, and three days.
// `dark` turns it into the bar's night-ink popup.
Sticker {
    id: root

    property bool live: true
    property bool dark: false
    readonly property color fg: root.dark ? Theme.nightText : Theme.text
    readonly property color soft: root.dark ? Theme.nightSoft : Theme.textSoft
    readonly property color cell: root.dark ? Theme.night2 : Theme.paper2

    implicitWidth: 300
    implicitHeight: 262
    fill: root.dark ? Theme.night : Theme.paper
    radius: 16
    lift: 4

    // now
    Sticker {
        id: now
        x: 10; y: 10
        width: parent.width - 20
        height: 92
        radius: 12
        lift: 2
        fill: Theme.secondary
        gloss: true

        Column {
            x: 12; y: 8
            spacing: -6
            Label { text: (Weather.condition || "Weather").toUpperCase(); size: 10; weight: 700; font.letterSpacing: 0.8 }
            Row {
                spacing: 6
                Label { text: Weather.loaded ? Weather.temp : "--"; size: 42; weight: 700 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -4
                    Label { text: "°C"; size: 15; weight: 700 }
                    Label { text: "↑" + Weather.high + "°  ↓" + Weather.low + "°"; size: 10; weight: 600 }
                }
            }
        }
        Tag {
            x: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            icon: "pin_drop"
            text: Weather.place !== "" ? Weather.place : "somewhere"
            size: 10
            fill: Theme.paper
            width: Math.min(implicitWidth, parent.width - 90)
        }
        Sticker {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 58; height: 58
            radius: 29
            lift: 2
            fill: Theme.paper
            Icon { anchors.centerIn: parent; icon: Weather.icon; size: 32; filled: true }
        }
    }

    // details
    Row {
        id: cells
        x: 10
        anchors.top: now.bottom
        anchors.topMargin: 10
        spacing: 7
        Cell { label: "HUMIDITY"; value: Weather.humidity + "%" }
        Cell { label: "WIND · " + Weather.windDir; value: Weather.wind + " km/h" }
        Cell { label: "FEELS"; value: Weather.feels + "°" }
    }

    // days
    Column {
        x: 10
        anchors.top: cells.bottom
        anchors.topMargin: 9
        width: parent.width - 20
        spacing: 5
        Repeater {
            model: Weather.days.slice(0, 3)
            Item {
                id: day
                required property var modelData
                required property int index
                width: parent.width
                height: 22
                Sticker {
                    width: 62; height: 20
                    radius: 10
                    lift: 0
                    outline: 1.5
                    fill: day.index === 0 ? Theme.primary : root.cell
                    Label { anchors.centerIn: parent; text: day.modelData.label; size: 10; weight: 700; color: day.index === 0 ? Theme.text : root.fg }
                }
                Icon { x: 70; anchors.verticalCenter: parent.verticalCenter; icon: Weather.iconFor(day.modelData.code); size: 16; filled: true; color: root.fg }
                Label { x: 92; anchors.verticalCenter: parent.verticalCenter; text: day.modelData.high + "°"; size: 12; weight: 700; color: root.fg }
                Label { x: 118; anchors.verticalCenter: parent.verticalCenter; text: day.modelData.low + "°"; size: 10; weight: 600; color: root.soft }
                Rectangle {
                    x: 142
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 142 - 50
                    height: 5
                    radius: 2.5
                    color: Theme.alpha(root.fg, 0.18)
                    Rectangle {
                        width: parent.width * Math.max(0.05, Math.min(1, (day.modelData.high + 5) / 40))
                        height: parent.height
                        radius: 2.5
                        color: Theme.primaryStrong
                    }
                }
                Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "💧" + day.modelData.rain + "%"; size: 10; weight: 600; color: root.soft }
            }
        }
    }

    component Cell: Sticker {
        id: cell
        property string label: ""
        property string value: ""
        width: (root.width - 20 - 14) / 3
        height: 42
        radius: 10
        lift: 2
        fill: root.cell
        Column {
            anchors.centerIn: parent
            spacing: -3
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: cell.label; size: 8; weight: 700; color: root.soft; font.letterSpacing: 0.5 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: cell.value; size: 15; weight: 700; color: root.fg }
        }
    }
}
