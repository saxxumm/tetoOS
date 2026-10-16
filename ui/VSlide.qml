import QtQuick
import "root:/theme"

// A vertical inked slider for a value around zero — an equalizer band.
// `value` runs from `from` to `to`; the fill grows from the zero line.
Item {
    id: root

    property real value: 0
    property real from: -12
    property real to: 12
    property real step: 0.5
    property color fill: Theme.primaryStrong

    signal moved(real v)

    implicitWidth: 22
    implicitHeight: 180

    readonly property real span: root.to - root.from
    function yFor(v) { return root.height * (1 - (v - root.from) / root.span); }
    readonly property real zeroY: root.yFor(0)
    readonly property real valueY: root.yFor(Math.max(root.from, Math.min(root.to, root.value)))

    Sticker {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 12
        height: parent.height
        radius: 6
        lift: 0
        fill: Theme.paper3

        Rectangle {
            x: Theme.outline
            width: parent.width - Theme.outline * 2
            y: Math.min(root.zeroY, root.valueY)
            height: Math.max(2, Math.abs(root.zeroY - root.valueY))
            radius: width / 2
            color: root.fill
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.zeroY - 1
        width: parent.width + 6
        height: 2
        color: Theme.alpha(Theme.ink, 0.35)
    }
    Rectangle {
        width: root.width
        height: width
        radius: width / 2
        y: root.valueY - height / 2
        color: Theme.paper
        border.color: Theme.ink
        border.width: Theme.outline
        Behavior on y { enabled: !area.pressed; NumberAnimation { duration: Theme.quick } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        function at(y) {
            const v = root.to - (y - 6) / root.height * root.span;
            return Math.max(root.from, Math.min(root.to, Math.round(v / root.step) * root.step));
        }
        onPressed: event => root.moved(at(event.y))
        onPositionChanged: event => { if (pressed) root.moved(at(event.y)); }
        onDoubleClicked: root.moved(0)
        onWheel: event => root.moved(Math.max(root.from, Math.min(root.to, root.value + (event.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
