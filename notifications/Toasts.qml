import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// Notification toasts: night-ink stickers stacked under the bar on the right,
// each with an accent edge, that leave on their own unless they are urgent.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    visible: Notifs.popups.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tetoos-toasts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: Config.ready && Config.options.barPosition === "bottom" ? 12 : 50
    margins.right: 12
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.height + 12)
    color: "transparent"
    mask: Region { item: stack }

    Column {
        id: stack
        width: 360
        x: 4
        spacing: 10

        Repeater {
            model: Notifs.popups.slice(-4)
            Item {
                id: toast
                required property var modelData
                readonly property bool urgent: modelData.urgency === 2
                width: stack.width
                height: body.height + 4
                property real enter: 0
                Component.onCompleted: enter = 1
                Behavior on enter { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                opacity: enter
                transform: Translate { x: (1 - toast.enter) * 80 }

                Timer {
                    running: !toast.urgent && !hover.hovered
                    interval: toast.modelData.urgency === 0 ? Notifs.lowTimeout : Notifs.ordinaryTimeout
                    onTriggered: toast.modelData.expire ? toast.modelData.expire() : toast.modelData.dismiss()
                }

                Sticker {
                    id: body
                    width: parent.width
                    height: Math.max(64, content.implicitHeight + 22)
                    radius: 14
                    lift: 4
                    fill: Theme.night

                    Rectangle {
                        x: 6; y: 8
                        width: 5
                        height: parent.height - 16
                        radius: 2.5
                        color: toast.urgent ? Theme.bad : Theme.primary
                    }
                    ClippingRectangle {
                        id: pic
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40
                        radius: 12
                        color: Theme.night2
                        border.color: Theme.alpha(Theme.nightText, 0.25)
                        border.width: 1
                        readonly property string src: toast.modelData.image || (toast.modelData.appIcon ? Quickshell.iconPath(toast.modelData.appIcon, true) : "")
                        Image { anchors.fill: parent; source: pic.src; fillMode: Image.PreserveAspectCrop; sourceSize.width: 96; asynchronous: true; visible: pic.src !== "" }
                        Icon { anchors.centerIn: parent; visible: pic.src === ""; icon: "notifications"; size: 22; filled: true; color: Theme.primary }
                    }
                    Column {
                        id: content
                        anchors.left: pic.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 30
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Label { width: parent.width; text: toast.modelData.appName || "Notification"; size: 10; weight: 700; color: Theme.nightSoft }
                        Label { width: parent.width; text: toast.modelData.summary || ""; size: 14; weight: 700; color: Theme.nightText }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: toast.modelData.body || ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            color: Theme.nightSoft
                            font.family: /[Ѐ-ӿ]/.test(text) ? Theme.fontAlt : Theme.font
                            font.pixelSize: 12
                            font.weight: 500
                        }
                    }
                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        y: 10
                        icon: "close"
                        size: 15
                        color: Theme.nightSoft
                        opacity: hover.hovered ? 1 : 0.4
                    }
                }
                HoverHandler { id: hover }
                MouseArea {
                    anchors.fill: body
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = toast.modelData;
                        const def = n.actions ? n.actions.find(a => a.identifier === "default") : null;
                        if (def) def.invoke();
                        n.dismiss();
                    }
                }
            }
        }
    }
}
