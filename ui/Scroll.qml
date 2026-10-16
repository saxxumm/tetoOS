import QtQuick
import "root:/theme"

// A Flickable with a slim inked thumb that shows while it moves.
Flickable {
    id: root

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2600
    maximumFlickVelocity: 3200

    Rectangle {
        parent: root
        visible: root.contentHeight > root.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 1
        width: 4
        radius: 2
        color: Theme.alpha(Theme.ink, root.moving ? 0.55 : 0.25)
        y: root.height * (root.contentY / Math.max(1, root.contentHeight))
        height: Math.max(24, root.height * root.height / Math.max(1, root.contentHeight))
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
}
