import QtQuick
import "root:/theme"
import "root:/services"

// A horizontal battery drawn in ink, filled to the charge, with a bolt while
// it charges.
Item {
    id: root

    property real level: Power.level
    property bool charging: Power.charging
    property color color: Theme.text

    implicitWidth: 22
    implicitHeight: 12

    Rectangle {
        id: shell
        width: parent.width - 3
        height: parent.height
        radius: 3.5
        color: "transparent"
        border.color: root.color
        border.width: 1.8

        Rectangle {
            x: 2.5
            y: 2.5
            height: parent.height - 5
            width: Math.max(1.5, (parent.width - 5) * Math.max(0, Math.min(1, root.level)))
            radius: 1.5
            color: root.level < 0.15 && !root.charging ? Theme.bad : root.color
        }
    }
    Rectangle {
        anchors.left: shell.right
        anchors.leftMargin: 0.5
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 5
        radius: 1
        color: root.color
    }
    Icon {
        visible: root.charging
        anchors.centerIn: shell
        icon: "bolt"
        size: 12
        filled: true
        color: Theme.paper
        style: Text.Outline
        styleColor: root.color
    }
}
