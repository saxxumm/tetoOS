import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/theme"
import "root:/services"

// The desktop layer: the widgets, over the wallpaper and under every window.
//
// It takes the pointer only over the widgets — the rest of the empty canvas is
// sxmwm's to pan and zoom. A right click on the canvas comes through sxmwm's
// binding (`tetoos deskMenuHere`): for a moment this layer takes the whole
// screen, sxmwm re-picks the surface under the pointer, the enter event says
// where it is, and the menu opens there.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "tetoos-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: !Ui.editing

    // On Hyprland the empty desktop is ours: a right click on it opens the menu
    // directly. On sxmwm it is the canvas, and the click comes through a binding.
    mask: Region {
        item: Ui.deskCatch || Compositor.hypr ? catcher : null
        Region { item: widgets.clockItem }
        Region { item: widgets.todoItem }
        Region { item: widgets.userItem }
        Region { item: widgets.weatherItem }
        Region { item: widgets.calendarItem }
        Region { item: widgets.systemItem }
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        visible: Ui.deskCatch || Compositor.hypr
        hoverEnabled: Ui.deskCatch
        acceptedButtons: Ui.deskCatch ? Qt.AllButtons : Qt.RightButton
        onEntered: if (Ui.deskCatch) Ui.openDeskMenu(catcher.mouseX, catcher.mouseY)
        onPositionChanged: if (Ui.deskCatch) Ui.openDeskMenu(catcher.mouseX, catcher.mouseY)
        onPressed: event => Ui.openDeskMenu(event.x, event.y)
    }

    Widgets {
        id: widgets
        anchors.fill: parent
    }
}
