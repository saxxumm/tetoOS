import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// Every desktop widget, placed by the fractions saved in the config. The same
// item draws the live desktop and the edit mode's miniature, where `editing`
// makes each one draggable inside a handle frame.
Item {
    id: root

    property bool editing: false
    property bool live: !root.editing
    property real uiScale: 1

    readonly property var items: [clock, todo, user, weather, calendar, system]
    readonly property alias clockItem: clock
    readonly property alias todoItem: todo
    readonly property alias userItem: user
    readonly property alias weatherItem: weather
    readonly property alias calendarItem: calendar
    readonly property alias systemItem: system

    Visualizer {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        height: 190
        visible: Config.ready && Config.options.visualizer && Config.widget("visualizer").on
    }

    Placer { id: clock; name: "clock"; ClockWidget {} }
    Placer { id: user; name: "user"; UserWidget {} }
    Placer { id: weather; name: "weather"; WeatherWidget { live: root.live } }
    Placer { id: calendar; name: "calendar"; CalendarWidget {} }
    Placer { id: todo; name: "todo"; TodoWidget { live: root.live } }
    Placer { id: system; name: "system"; SystemWidget {} }

    component Placer: Item {
        id: placer
        property string name: ""
        default property alias content: holder.data
        readonly property var spot: Config.ready ? Config.widget(placer.name) : ({ x: 0, y: 0, on: false })
        readonly property Item widget: holder.children.length > 0 ? holder.children[0] : null

        visible: placer.spot.on
        x: placer.spot.x * root.width
        y: placer.spot.y * root.height
        width: placer.spot.on && placer.widget ? placer.widget.implicitWidth : 0
        height: placer.spot.on && placer.widget ? placer.widget.implicitHeight : 0

        Item {
            id: holder
            anchors.fill: parent
            Component.onCompleted: {
                for (const c of holder.children) {
                    c.width = Qt.binding(() => c.implicitWidth);
                    c.height = Qt.binding(() => c.implicitHeight);
                }
            }
        }

        // the edit frame: a dashed box with square handles, like a drawing app
        Item {
            visible: root.editing
            anchors.fill: parent
            anchors.margins: -8
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property bool horizontal: index < 2
                    x: horizontal ? 0 : (index === 2 ? 0 : parent.width - 2)
                    y: horizontal ? (index === 0 ? 0 : parent.height - 2) : 0
                    width: horizontal ? parent.width : 2
                    height: horizontal ? 2 : parent.height
                    color: Theme.alpha(Theme.ink, 0.6)
                }
            }
            Repeater {
                model: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]
                Rectangle {
                    required property var modelData
                    width: 10; height: 10
                    radius: 2
                    x: modelData[0] * parent.width - 5
                    y: modelData[1] * parent.height - 5
                    color: Theme.paper
                    border.color: Theme.ink
                    border.width: 2
                }
            }
            Tag {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                visible: dragArea.containsMouse || dragArea.drag.active
                text: "drag to move"
                icon: "drag_pan"
                size: 10
                fill: Theme.paper
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            visible: root.editing
            hoverEnabled: true
            cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: Config.ready && Config.options.widgetsLocked ? null : placer
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: root.width - placer.width
            drag.maximumY: root.height - placer.height
            drag.threshold: 2
            onClicked: event => {
                if (event.button === Qt.RightButton) Config.setWidget(placer.name, { on: false });
            }
            onReleased: {
                if (!dragArea.drag.active && Math.abs(placer.x - placer.spot.x * root.width) < 1) return;
                Config.setWidget(placer.name, { x: placer.x / root.width, y: placer.y / root.height });
                placer.x = Qt.binding(() => placer.spot.x * root.width);
                placer.y = Qt.binding(() => placer.spot.y * root.height);
            }
        }
    }
}
