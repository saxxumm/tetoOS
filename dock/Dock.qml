import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/theme"
import "root:/services"

// The dock window, along the bottom edge. It reserves its height so that
// sxmwm's fit and fill frame windows above it.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    visible: Config.ready && Config.options.dock && !Ui.editing
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tetoos-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 72
    exclusiveZone: 66
    color: "transparent"
    mask: Region { item: dock }

    DockContent {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: implicitWidth
        height: implicitHeight
    }
}
