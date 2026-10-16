import QtQuick
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// Who is here: a banner cut from the wallpaper, the face, the greeting, and
// how the day is going.
Sticker {
    id: root

    implicitWidth: 300
    implicitHeight: 232
    fill: Theme.paper
    radius: 16
    lift: 4

    ClippingRectangle {
        id: banner
        x: 10
        y: 10
        width: parent.width - 20
        height: 66
        radius: 11
        color: Theme.paper3
        border.color: Theme.ink
        border.width: 2

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 360
            asynchronous: true
            opacity: 0.9
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 9
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(Theme.paper, 0.75) }
                GradientStop { position: 0.6; color: Theme.alpha(Theme.paper, 0.0) }
            }
        }
    }

    Tag {
        anchors.right: banner.right
        anchors.rightMargin: 8
        anchors.top: banner.top
        anchors.topMargin: 8
        text: Sys.greeting
        caps: true
        size: 10
        fill: Theme.paper
    }

    Avatar {
        id: face
        x: 20
        y: 40
        width: 64
        height: 64
        radius: 18
    }

    Column {
        anchors.left: face.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 80
        spacing: -4
        Label { width: parent.width; text: Sys.name; size: 21; weight: 700 }
        Label { width: parent.width; text: "@" + Sys.user + (Sys.host !== "" ? " · " + Sys.host : ""); size: 11; weight: 500; color: Theme.textSoft }
    }

    Row {
        id: stats
        x: 12
        y: 122
        spacing: 7
        Stat { label: "UPTIME"; value: Sys.uptime; fill: Theme.paper2 }
        Stat { label: "SHELL"; value: Sys.shell; fill: Theme.primary }
        Stat { label: "DESKTOP"; value: Sys.desktop; fill: Theme.paper2 }
    }

    Row {
        x: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 9
        Label { anchors.verticalCenter: parent.verticalCenter; text: "TODAY"; size: 10; weight: 700; color: Theme.textSoft; font.letterSpacing: 0.8 }
        Slide {
            anchors.verticalCenter: parent.verticalCenter
            width: root.width - 140
            height: 12
            value: Sys.dayProgress
            knob: false
            enabled: false
        }
        Tag {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Sys.dayProgress * 100) + "%"
            size: 11
        }
    }

    component Stat: Sticker {
        id: stat
        property string label: ""
        property string value: ""
        width: (root.width - 24 - 14) / 3
        height: 44
        radius: 11
        lift: 2
        Column {
            anchors.centerIn: parent
            spacing: -3
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: stat.label; size: 9; weight: 700; color: Theme.textSoft; font.letterSpacing: 0.6 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: stat.value; size: 15; weight: 700 }
        }
    }
}
