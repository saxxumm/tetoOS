import QtQuick
import "root:/theme"

// An inked on/off switch.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 44
    implicitHeight: 24

    Sticker {
        anchors.fill: parent
        radius: height / 2
        lift: 2
        fill: root.checked ? Theme.primaryStrong : Theme.paper3
        Behavior on fill { ColorAnimation { duration: Theme.quick } }

        Rectangle {
            width: parent.height - 8
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 4
            color: root.checked ? Theme.strongText : Theme.paper
            border.color: Theme.ink
            border.width: Theme.outline
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
