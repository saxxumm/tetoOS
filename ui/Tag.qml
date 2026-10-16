import QtQuick
import "root:/theme"

// A small inked label chip: section headers ("Bar", "Desktop widgets"),
// greetings ("GOOD EVENING") and counters.
Sticker {
    id: root

    property string icon: ""
    property string text: ""
    property real size: 12
    property color fg: Theme.text
    property bool caps: false

    fill: Theme.primary
    radius: height / 2
    lift: 2
    implicitHeight: root.size + 12
    implicitWidth: row.implicitWidth + 18

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: root.size + 3
            filled: true
            color: root.fg
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.caps ? root.text.toUpperCase() : root.text
            size: root.size
            weight: 700
            color: root.fg
            font.letterSpacing: root.caps ? 0.8 : 0
        }
    }
}
