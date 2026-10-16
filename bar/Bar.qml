import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/theme"
import "root:/services"

// The bar window: a strip at the top (or bottom) that reserves its height, so
// sxmwm's camera frames windows below it.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property bool bottom: Config.ready && Config.options.barPosition === "bottom"

    visible: Config.ready && Config.options.bar && !Ui.editing
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tetoos-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: !win.bottom
        bottom: win.bottom
        left: true
        right: true
    }
    implicitHeight: 46
    exclusiveZone: 42
    color: "transparent"

    BarContent {
        anchors.fill: parent
        anchors.topMargin: win.bottom ? 6 : 6
        anchors.bottomMargin: win.bottom ? 8 : 6
        screen: win.modelData
    }
}
