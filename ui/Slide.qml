import QtQuick
import "root:/theme"

// A pill track with an inked fill and a round knob. `value` is 0..1; drag,
// click or scroll to change it, and `moved(v)` says where the hand put it.
Item {
    id: root

    property real value: 0
    property color fill: Theme.primaryStrong
    property color track: Theme.paper3
    property string icon: ""
    property bool knob: true
    property real step: 0.05

    signal moved(real v)

    implicitHeight: 18
    implicitWidth: 160

    readonly property real shown: drag.pressed ? drag.live : Math.max(0, Math.min(1, root.value))

    Sticker {
        anchors.fill: parent
        radius: height / 2
        fill: root.track
        lift: 0

        Rectangle {
            x: Theme.outline
            y: Theme.outline
            height: parent.height - Theme.outline * 2
            width: Math.max(height, (parent.width - Theme.outline * 2) * root.shown)
            radius: height / 2
            color: root.fill
            visible: root.shown > 0.005

            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.quick } }
        }

        Icon {
            visible: root.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: parent.height - 6
            filled: true
            color: root.shown > 0.12 ? Theme.strongText : Theme.text
        }
    }

    Rectangle {
        visible: root.knob
        width: root.height + 4
        height: width
        radius: width / 2
        y: -2
        x: Math.max(0, Math.min(root.width - width, root.width * root.shown - width / 2))
        color: Theme.paper
        border.color: Theme.ink
        border.width: Theme.outline
    }

    MouseArea {
        id: drag
        property real live: 0
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, (x - 4) / root.width)); }
        onPressed: event => { drag.live = drag.at(event.x); root.moved(drag.live); }
        onPositionChanged: event => { if (pressed) { drag.live = drag.at(event.x); root.moved(drag.live); } }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
