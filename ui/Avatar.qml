import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/theme"
import "root:/services"

// The user's face, from AccountsService, in an inked rounded frame. Falls back
// to an initial when there is no picture.
Item {
    id: root

    property real radius: width * 0.3
    property string source: Demo.on ? "file://" + Demo.avatar : "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER")
    property color fill: Theme.secondary

    implicitWidth: 56
    implicitHeight: 56

    Sticker {
        anchors.fill: parent
        radius: root.radius
        fill: root.fill
        lift: 2

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: Theme.outline
            radius: Math.max(0, root.radius - Theme.outline)
            color: "transparent"

            Image {
                id: pic
                anchors.fill: parent
                source: root.source
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 256
                sourceSize.height: 256
                asynchronous: true
                cache: true
                smooth: !Demo.on
            }
        }

        Label {
            anchors.centerIn: parent
            visible: pic.status !== Image.Ready
            text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
            size: root.height * 0.45
            weight: 700
        }
    }
}
