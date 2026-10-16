import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// The wallpaper picker: the folder laid along an arc under a little bridge,
// the one in the middle large. Arrows or the wheel to browse, Enter to apply;
// the whole shell recolours itself to the picture.
Item {
    id: root

    focus: true
    property bool lockTarget: false
    property int idx: 0
    readonly property var list: Wallpaper.list
    readonly property var picked: root.list.length > 0 ? root.list[Math.max(0, Math.min(root.list.length - 1, root.idx))] : null
    readonly property bool isCurrent: root.picked !== null && root.picked.path === (root.lockTarget ? Config.options.lockWallpaper : Wallpaper.current)

    function sync() {
        const i = root.list.findIndex(w => w.path === Wallpaper.current);
        root.idx = i >= 0 ? i : 0;
    }
    onListChanged: sync()
    Component.onCompleted: { Wallpaper.rescan(); sync(); }

    function go(step) {
        if (root.list.length === 0) return;
        root.idx = (root.idx + step + root.list.length) % root.list.length;
    }
    function apply() {
        if (!root.picked) return;
        if (root.lockTarget) Config.options.lockWallpaper = root.picked.path;
        else Wallpaper.set(root.picked.path);
    }

    Keys.onLeftPressed: go(-1)
    Keys.onRightPressed: go(1)
    Keys.onReturnPressed: apply()
    Keys.onEnterPressed: apply()

    // --- header --------------------------------------------------------------
    Sticker {
        id: title
        x: 14; y: 16
        width: 280; height: 46
        radius: 16
        fill: Theme.primary
        gloss: true
        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Sticker {
                width: 30; height: 30
                radius: 9
                lift: 0
                Icon { anchors.centerIn: parent; icon: "wallpaper"; size: 18; filled: true }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4
                Label { text: "Wallpapers"; size: 18; weight: 700 }
                Label { text: "Pick the vibe — colours follow"; size: 10; weight: 500; color: Theme.textSoft }
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 20
        spacing: 9
        Sticker {
            width: 110; height: 38
            radius: 13
            lift: 2
            Column {
                anchors.centerIn: parent
                spacing: -4
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Sys.time(); size: 15; weight: 700 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(Sys.now, "ddd, d MMM"); size: 9; weight: 500; color: Theme.textSoft }
            }
        }
        Tap { width: 36; height: 36; icon: "close"; onClicked: Ui.closePhone() }
    }

    Row {
        id: tabs
        x: 18
        anchors.top: title.bottom
        anchors.topMargin: 14
        spacing: 8
        Tap { height: 30; icon: "desktop_windows"; text: "Desktop"; active: !root.lockTarget; textSize: 12; onClicked: root.lockTarget = false }
        Tap { height: 30; icon: "lock"; text: "Lockscreen"; active: root.lockTarget; textSize: 12; onClicked: root.lockTarget = true }
        Label { anchors.verticalCenter: parent.verticalCenter; leftPadding: 8; text: Config.options.wallpaperDir.replace(Config.home, "~") + " · " + root.list.length + " wallpapers"; size: 11; weight: 500; color: Theme.textSoft }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: tabs.verticalCenter
        spacing: 7
        Tap { height: 30; icon: "palette"; text: Config.options.palette === "wallpaper" ? "Colours: from wallpaper" : "Colours: " + Config.options.palette; textSize: 11; active: Config.options.palette === "wallpaper"; onClicked: Wallpaper.usePreset("wallpaper") }
        Tap { width: 32; height: 32; icon: "shuffle"; onClicked: root.idx = Math.floor(Math.random() * Math.max(1, root.list.length)) }
        Tap { width: 32; height: 32; icon: "refresh"; onClicked: Wallpaper.rescan() }
    }

    // --- the bridge ------------------------------------------------------------
    Canvas {
        id: bridge
        anchors.horizontalCenter: parent.horizontalCenter
        y: tabs.y + 34
        width: parent.width - 60
        height: 120
        renderStrategy: Canvas.Cooperative
        property color ink: Theme.ink
        property color a: Theme.primaryStrong
        property color b: Theme.secondaryStrong
        property color c: Theme.tertiaryStrong
        onInkChanged: requestPaint()
        onAChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const arc = (r, lw, col) => {
                ctx.beginPath();
                ctx.lineWidth = lw;
                ctx.strokeStyle = col;
                ctx.moveTo(10, h);
                ctx.quadraticCurveTo(w / 2, h * 0.05 - r, w - 10, h);
                ctx.stroke();
            };
            arc(0, 5, bridge.ink);
            arc(-16, 3, bridge.ink);
            // struts and nodes
            const cols = [bridge.a, bridge.b, bridge.c];
            for (let i = 1; i < 10; i++) {
                const t = i / 10;
                const x = (1 - t) * (1 - t) * 10 + 2 * (1 - t) * t * (w / 2) + t * t * (w - 10);
                const y = (1 - t) * (1 - t) * h + 2 * (1 - t) * t * (h * 0.05) + t * t * h;
                ctx.beginPath();
                ctx.lineWidth = 2;
                ctx.strokeStyle = bridge.ink;
                ctx.moveTo(x, y);
                ctx.lineTo(x, y + 16);
                ctx.stroke();
                ctx.beginPath();
                ctx.fillStyle = i === 5 ? cols[0] : "white";
                ctx.arc(x, y, i === 5 ? 7 : 5, 0, Math.PI * 2);
                ctx.fill();
                ctx.lineWidth = 2.5;
                ctx.stroke();
                ctx.fillStyle = cols[i % 3];
                ctx.fillRect(x + 8, y + 2, 14, 4);
            }
        }
    }

    // --- the carousel ------------------------------------------------------------
    Item {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        y: tabs.y + 70
        width: parent.width - 40
        height: 220

        WheelHandler { onWheel: event => root.go(event.angleDelta.y > 0 ? -1 : 1) }

        Repeater {
            model: root.list
            Item {
                id: card
                required property var modelData
                required property int index
                readonly property int off: {
                    const n = root.list.length;
                    let d = card.index - root.idx;
                    if (d > n / 2) d -= n;
                    if (d < -n / 2) d += n;
                    return d;
                }
                readonly property real a: Math.abs(card.off)
                visible: card.a <= 3
                z: 10 - card.a
                width: 320
                height: 180
                x: stage.width / 2 - width / 2 + card.off * 205 - Math.sign(card.off) * Math.max(0, card.a - 1) * 40
                y: 14 + card.a * card.a * 12
                scale: card.a === 0 ? 1 : card.a === 1 ? 0.74 : 0.56
                rotation: card.off * 4
                opacity: card.a >= 3 ? 0 : 1
                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 340 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Sticker {
                    anchors.fill: parent
                    radius: 18
                    lift: 6
                    outline: card.a === 0 ? 3 : 2.5
                    fill: Theme.paper3
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 14
                        color: Theme.paper3
                        Image {
                            anchors.fill: parent
                            source: card.a <= 3 ? "file://" + card.modelData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 480
                        }
                    }
                }
                Sticker {
                    visible: card.modelData.path === Wallpaper.current
                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.top: parent.top
                    anchors.topMargin: -8
                    width: 28; height: 28
                    radius: 14
                    lift: 2
                    fill: Theme.primary
                    Icon { anchors.centerIn: parent; icon: "check"; size: 17; weight: 800 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.off === 0 ? root.apply() : root.idx = card.index
                }
            }
        }

        Column {
            visible: root.list.length === 0
            anchors.centerIn: parent
            spacing: 6
            Icon { anchors.horizontalCenter: parent.horizontalCenter; icon: "image_not_supported"; size: 46; color: Theme.textSoft }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Wallpaper.scanning ? "Looking for pictures…" : "No pictures in " + Config.options.wallpaperDir; size: 14; color: Theme.textSoft }
        }
    }

    // --- name, counter, buttons ------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: buttons.top
        anchors.bottomMargin: 12
        spacing: 6
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.picked ? root.picked.name.replace(/\.[^.]+$/, "") : ""
            size: 17
            weight: 700
            style: Text.Outline
            styleColor: Theme.paper
            width: Math.min(implicitWidth, root.width - 200)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Tag { text: (root.idx + 1) + " / " + root.list.length; size: 11; fill: Theme.paper }
            Tag { visible: root.picked !== null && root.picked.path === Wallpaper.current; text: "On your desktop"; icon: "desktop_windows"; size: 11; fill: Theme.secondary }
            Tag { visible: root.picked !== null && root.picked.path === Config.options.lockWallpaper; text: "On your lockscreen"; icon: "lock"; size: 11; fill: Theme.tertiary }
        }
    }

    Row {
        id: buttons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 12
        Tap { height: 40; icon: "chevron_left"; text: "Previous"; onClicked: root.go(-1) }
        Tap {
            height: 44
            width: 210
            icon: root.isCurrent ? "check" : "format_paint"
            text: root.isCurrent ? "Applied" : (root.lockTarget ? "Set for lock" : "Set as desktop")
            textSize: 15
            fill: Theme.primary
            gloss: true
            onClicked: root.apply()
        }
        Tap {
            height: 44
            width: 210
            icon: "lock"
            text: "Set as lockscreen"
            textSize: 15
            fill: Theme.secondary
            onClicked: if (root.picked) Config.options.lockWallpaper = root.picked.path
        }
        Tap { height: 40; icon: "chevron_right"; text: "Next"; onClicked: root.go(1) }
    }
}
