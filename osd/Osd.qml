import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/theme"
import "root:/ui"
import "root:/services"

// Volume, microphone and brightness, shown for a moment as a pill above the
// dock whenever they change — from a key, a scroll on the bar, or anything
// else that moves them.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tetoos-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true }
    margins.bottom: 96
    implicitWidth: 340
    implicitHeight: 70
    color: "transparent"
    mask: Region {}
    visible: shown > 0.01

    property real shown: 0
    Behavior on shown { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    property bool armed: false

    Timer { running: true; interval: 2500; onTriggered: win.armed = true }
    Timer { id: hide; interval: 1400; onTriggered: win.shown = 0 }

    function pop(kind) {
        if (!win.armed) return;
        Ui.osd = kind;
        win.shown = 1;
        hide.restart();
    }
    Connections {
        target: Audio
        function onVolumeChanged() { win.pop("volume"); }
        function onMutedChanged() { win.pop("volume"); }
        function onMicMutedChanged() { win.pop("mic"); }
    }
    Connections {
        target: Brightness
        function onValueChanged() { win.pop("brightness"); }
    }
    Connections {
        target: Ui
        function onOsdTickChanged() { win.pop(Ui.osd); }
    }

    readonly property real level: Ui.osd === "brightness" ? Brightness.value
        : Ui.osd === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume)
        : (Audio.muted ? 0 : Audio.volume)
    readonly property string icon: Ui.osd === "brightness" ? "brightness_6"
        : Ui.osd === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : (Audio.muted ? "volume_off" : Audio.volume > 0.5 ? "volume_up" : "volume_down")

    Sticker {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - win.shown) * 20
        opacity: win.shown
        width: 320
        height: 52
        radius: 26
        lift: 4
        fill: Theme.paper
        Sticker {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            radius: 18
            lift: 0
            fill: Theme.primary
            Icon { anchors.centerIn: parent; icon: win.icon; size: 20; filled: true }
        }
        Slide {
            x: 56
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            height: 14
            value: Math.min(1, win.level)
            knob: false
            enabled: false
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(win.level * 100)
            size: 17
            weight: 700
        }
    }
}
