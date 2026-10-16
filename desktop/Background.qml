import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/theme"
import "root:/services"

// The wallpaper, on the background layer. It takes no input at all: the empty
// canvas belongs to sxmwm (a drag pans it, the wheel zooms).
//
// A new picture arrives as a circle opening from the middle of the screen with
// an inked rim, while the colours ease underneath it.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "tetoos-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.paper
    mask: Region {}

    WallImage {
        id: under
        anchors.fill: parent
        path: ""
        retainWhileLoading: true
    }

    property string shown: ""
    property real reveal: 0
    readonly property real far: Math.hypot(width, height) / 2 + 40

    ClippingRectangle {
        id: hole
        readonly property real r: win.reveal * win.far
        x: win.width / 2 - r
        y: win.height / 2 - r
        width: r * 2
        height: r * 2
        radius: r
        color: "transparent"

        WallImage {
            id: over
            x: -hole.x
            y: -hole.y
            width: win.width
            height: win.height
            path: win.shown
        }
    }

    Rectangle {
        visible: win.reveal > 0 && win.reveal < 1
        x: hole.x - 4
        y: hole.y - 4
        width: hole.width + 8
        height: hole.height + 8
        radius: width / 2
        color: "transparent"
        border.color: Theme.ink
        border.width: 6
        opacity: 1 - win.reveal * 0.6
    }

    NumberAnimation {
        id: open
        target: win
        property: "reveal"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutCubic
        onFinished: under.path = win.shown
    }

    function show(path) {
        if (path === "" || path === win.shown) return;
        if (win.shown === "") {
            // first picture: no ceremony
            win.shown = path;
            under.path = path;
            win.reveal = 1;
            return;
        }
        under.path = win.shown;
        win.reveal = 0;
        win.shown = path;
        over.waitThen(() => open.restart());
    }

    Connections {
        target: Wallpaper
        function onCurrentChanged() { win.show(Wallpaper.current); }
    }
    Component.onCompleted: win.show(Wallpaper.current)

    component WallImage: Image {
        id: img
        property string path: ""
        property var pending: null
        source: img.path === "" ? "" : "file://" + img.path
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 3840
        sourceSize.height: 2160
        asynchronous: true
        cache: false
        smooth: true

        // Run `fn` once the picture now asked for has actually decoded — a
        // 4K PNG takes most of a second, and the circle should open on it, not
        // on the one before.
        function waitThen(fn) {
            if (img.status === Image.Ready) fn();
            else img.pending = fn;
        }
        onStatusChanged: if (img.status !== Image.Loading && img.status !== Image.Null && img.pending) {
            const fn = img.pending;
            img.pending = null;
            fn();
        }
    }
}
