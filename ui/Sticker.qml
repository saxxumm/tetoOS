import QtQuick
import "root:/theme"

// The one surface everything is made of: a pale fill inside a thick ink line,
// with a hard shadow dropped straight down. Children go inside the fill.
Item {
    id: root

    property color fill: Theme.paper
    property color edge: Theme.ink
    property color shade: Theme.shadow
    property real radius: Theme.radius
    property real outline: Theme.outline
    property real lift: Theme.lift
    // A soft top-light, the glossy look the stickers on the video have.
    property bool gloss: false
    property alias body: face
    default property alias content: face.data

    Rectangle {
        id: drop
        visible: root.lift > 0
        x: 0
        y: root.lift
        width: root.width
        height: root.height
        radius: root.radius
        color: root.shade
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.color: root.edge
        border.width: root.outline

        // in the dark a hairline of light inside the ink, or the card sinks
        // into a dark wallpaper
        Rectangle {
            visible: Theme.dark && root.outline > 0 && root.radius >= 0
            anchors.fill: parent
            anchors.margins: root.outline
            radius: Math.max(0, root.radius - root.outline)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.075)
        }

        Rectangle {
            visible: root.gloss
            anchors.fill: parent
            anchors.margins: root.outline
            radius: Math.max(0, root.radius - root.outline)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.13 : 0.55) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }
}
