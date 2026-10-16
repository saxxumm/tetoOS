import QtQuick
import "root:/theme"
import "root:/services"

// A sticker you can press. It sinks onto its shadow under the finger and
// brightens under the pointer; everything else about it is a Sticker.
//
//     Tap { icon: "wifi"; text: "Wi-Fi"; active: Net.wifiEnabled; onClicked: … }
//
// With only `icon` set it is round; with text it is a pill.
Item {
    id: root

    property string icon: ""
    property string text: ""
    property string sub: ""
    property bool active: false
    property bool round: root.text === "" && root.sub === ""
    property bool enabled: true

    property color fill: root.active ? Theme.primary : Theme.paper
    property color activeFill: Theme.primary
    property color fg: root.active ? Theme.text : Theme.text
    property color edge: Theme.ink
    property real radius: root.round ? Math.min(width, height) / 2 : Theme.pill
    property real lift: Theme.lift
    property real iconSize: root.round ? Math.min(width, height) * 0.5 : 17
    property real textSize: 13
    property bool iconFilled: root.active
    property bool gloss: false
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property string tip: ""
    property real maxText: 0               // elide the label past this width
    property bool sound: true
    default property alias extra: face.content

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int delta)

    implicitHeight: 32
    implicitWidth: root.round ? root.implicitHeight : row.implicitWidth + 26
    opacity: root.enabled ? 1 : 0.45

    readonly property real sink: mouse.pressed && root.enabled ? root.lift : 0

    Sticker {
        id: face
        y: root.sink
        width: root.width
        height: root.height
        radius: root.radius
        lift: root.lift - root.sink
        edge: root.edge
        gloss: root.gloss
        fill: mouse.containsMouse && root.enabled ? Theme.mix(root.fill, Theme.paper, 0.35) : root.fill

        Behavior on fill { ColorAnimation { duration: Theme.quick } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7

            Icon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                icon: root.icon
                size: root.iconSize
                filled: root.iconFilled
                color: root.fg
            }

            Column {
                visible: root.text !== "" || root.sub !== ""
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Label {
                    visible: root.text !== ""
                    text: root.text
                    size: root.textSize
                    weight: 650
                    color: root.fg
                    width: root.maxText > 0 ? Math.min(implicitWidth, root.maxText) : implicitWidth
                }
                Label {
                    visible: root.sub !== ""
                    text: root.sub
                    size: root.textSize - 3
                    weight: 500
                    color: Theme.alpha(root.fg, 0.7)
                    width: root.maxText > 0 ? Math.min(implicitWidth, root.maxText) : implicitWidth
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: -root.lift
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.RightButton) root.rightClicked();
            else if (event.button === Qt.MiddleButton) root.middleClicked();
            else {
                if (root.sound) Sfx.play("tap", root.active ? 0.9 : 1.1);
                root.clicked();
            }
        }
        onWheel: event => root.wheel(event.angleDelta.y)
    }
}
