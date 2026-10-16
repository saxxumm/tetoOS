import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// To-do: tick, strike, add, clear the done ones. Saved as you go.
Sticker {
    id: root

    property bool live: true
    implicitWidth: 300
    implicitHeight: 460
    fill: Theme.paper
    radius: 16
    lift: 4

    Row {
        id: head
        x: 14
        y: 14
        spacing: 10
        Sticker {
            width: 36; height: 36
            radius: 10
            lift: 2
            fill: Theme.primary
            Icon { anchors.centerIn: parent; icon: "checklist"; size: 21; filled: true }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -3
            Label { text: "To-Do"; size: 18; weight: 700 }
            Label { text: Todo.count + " left"; size: 11; weight: 500; color: Theme.textSoft }
        }
    }

    Scroll {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: entry.top
        anchors.bottomMargin: 10
        contentHeight: column.height
        interactive: root.live

        Column {
            id: column
            width: list.width - 8
            spacing: 6

            Repeater {
                model: Todo.entries
                Item {
                    id: row
                    required property var modelData
                    width: column.width
                    height: Math.max(26, text.implicitHeight + 6)

                    Sticker {
                        id: box
                        width: 20; height: 20
                        y: 3
                        radius: 6
                        lift: 0
                        edge: Theme.dark ? Theme.textSoft : Theme.ink
                        fill: row.modelData.done ? Theme.primary : Theme.paper
                        Icon { anchors.centerIn: parent; visible: row.modelData.done; icon: "check"; size: 15; weight: 800 }
                    }
                    Label {
                        id: text
                        anchors.left: box.right
                        anchors.leftMargin: 9
                        anchors.right: del.left
                        anchors.rightMargin: 4
                        y: 3
                        text: row.modelData.text
                        size: 13
                        weight: 550
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        maximumLineCount: 3
                        color: row.modelData.done ? Theme.alpha(Theme.textSoft, 0.85) : Theme.text
                        font.strikeout: row.modelData.done
                    }
                    Icon {
                        id: del
                        anchors.right: parent.right
                        y: 4
                        icon: "close"
                        size: 15
                        opacity: rowArea.containsMouse ? 0.75 : 0
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: root.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.remove(row.modelData.id)
                        }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        anchors.rightMargin: 22
                        enabled: root.live
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todo.toggle(row.modelData.id)
                    }
                }
            }

            Label {
                visible: Todo.entries.length === 0
                text: "Nothing to do. Suspicious."
                size: 13
                color: Theme.textSoft
            }
        }
    }

    Sticker {
        id: entry
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: clear.top
        anchors.bottomMargin: 10
        height: 34
        radius: 10
        lift: 2
        fill: Theme.paper2

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: add.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.live
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: 550
            selectByMouse: true
            selectionColor: Theme.primary
            clip: true
            onAccepted: { Todo.add(input.text); input.text = ""; }
            Label {
                visible: input.text === "" && !input.activeFocus
                text: "add a task..."
                size: 13
                weight: 500
                color: Theme.alpha(Theme.textSoft, 0.8)
            }
        }
        Tap {
            id: add
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            radius: 8
            icon: "add"
            iconSize: 18
            lift: 2
            fill: Theme.primary
            enabled: root.live
            onClicked: { Todo.add(input.text); input.text = ""; }
        }
    }

    Tap {
        id: clear
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        height: 26
        text: "clear done (" + Todo.done.length + ")"
        textSize: 11
        lift: 2
        enabled: root.live && Todo.done.length > 0
        onClicked: Todo.clearDone()
    }
}
