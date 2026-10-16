import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// The flip clock card: date header, four digit tiles, the day's progress and
// the week with today lit.
Sticker {
    id: root

    implicitWidth: 300
    implicitHeight: 238
    fill: Theme.paper
    radius: 16
    lift: 4

    readonly property string hh: Sys.hours()
    readonly property string mm: Sys.minutes()

    Row {
        id: head
        x: 12; y: 12
        spacing: 9
        Sticker {
            width: 38; height: 38
            radius: 10
            lift: 2
            fill: Theme.primary
            Label { anchors.centerIn: parent; text: Sys.now.getDate(); size: 17; weight: 700 }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -4
            Label { text: Qt.formatDate(Sys.now, "dddd"); size: 18; weight: 700 }
            Label { text: Qt.formatDate(Sys.now, "MMMM yyyy"); size: 11; weight: 500; color: Theme.textSoft }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 18
        spacing: 4
        visible: !(Config.ready && Config.options.clock24)
        Tag { text: "AM"; size: 10; fill: Sys.ampm() === "AM" ? Theme.primary : Theme.paper2 }
        Tag { text: "PM"; size: 10; fill: Sys.ampm() === "PM" ? Theme.primary : Theme.paper2 }
    }

    Row {
        id: digits
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: head.bottom
        anchors.topMargin: 12
        spacing: 6
        Tile { digit: root.hh.charAt(0); fill: Theme.paper2 }
        Tile { digit: root.hh.charAt(1); fill: Theme.primary }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle { width: 8; height: 8; radius: 2; rotation: 45; color: Theme.ink }
            Rectangle { width: 8; height: 8; radius: 2; rotation: 45; color: Theme.ink }
        }
        Tile { digit: root.mm.charAt(0); fill: Theme.primary }
        Tile { digit: root.mm.charAt(1); fill: Theme.paper2 }
    }

    Row {
        id: progress
        x: 14
        anchors.top: digits.bottom
        anchors.topMargin: 14
        spacing: 8
        Slide {
            anchors.verticalCenter: parent.verticalCenter
            width: root.width - 28 - 44
            height: 12
            value: Sys.dayProgress
            knob: false
            fill: Theme.secondaryStrong
            enabled: false
        }
        Tag { anchors.verticalCenter: parent.verticalCenter; text: Sys.now.getMinutes(); size: 10; fill: Theme.secondary }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: progress.bottom
        anchors.topMargin: 10
        spacing: 4
        Repeater {
            model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            Sticker {
                id: wd
                required property string modelData
                required property int index
                readonly property bool today: Sys.now.getDay() === wd.index
                width: 36; height: 22
                radius: 7
                lift: wd.today ? 2 : 0
                outline: wd.today ? 2 : 1
                edge: wd.today ? Theme.ink : Theme.alpha(Theme.ink, 0.35)
                fill: wd.today ? Theme.primary : Theme.paper
                Label { anchors.centerIn: parent; text: wd.modelData; size: 9; weight: 700; color: wd.today ? Theme.text : Theme.textSoft }
            }
        }
    }

    component Tile: Sticker {
        id: tile
        property string digit: "0"
        width: 52; height: 70
        radius: 12
        lift: 4
        Label { anchors.centerIn: parent; text: tile.digit; size: 46; weight: 700 }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 2; width: parent.width - 4; height: 1.5; color: Theme.alpha(Theme.ink, 0.25) }
    }
}
