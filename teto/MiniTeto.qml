import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/theme"
import "root:/ui"
import "root:/services"

// Mini Teto, living in the bottom-right corner.
//
// Click her and she answers; right-click for her menu; scroll over her to pet
// her. Grab her and she dangles; let go with a flick and she flies, bounces
// off the edges, lands (dizzy, if you threw hard) and walks back to her
// corner. The surface is the whole screen but takes the pointer only over her
// and her bubble, so the canvas around her stays sxmwm's.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    visible: Teto.enabled && !Teto.hidden && !Ui.editing && !Teto.snoozed
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tetoos-teto"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {
        item: body
        Region { item: bubble.visible ? bubble : null }
    }

    readonly property real px: Config.ready ? Config.options.tetoScale : 4
    readonly property real bw: 29 * px
    readonly property real bh: 31 * px
    // the screen's size, not the surface's: the surface is 0×0 until the
    // compositor first configures it, and she would be placed off the top
    readonly property real sw: screen ? screen.width : width
    readonly property real sh: screen ? screen.height : height
    // she stands on the bottom edge, or on the bar when the bar is down there
    readonly property bool barBelow: Config.ready && Config.options.bar && Config.options.barPosition === "bottom"
    // a bottom bar sits above the dock's reserved strip, so she stands on top of both
    readonly property real floorY: sh - bh - (barBelow ? 48 + (Config.options.dock ? 66 : 0) : 2)
    readonly property real homeX: sw - bw - 26

    // --- her look: your own frames, if you have them --------------------------
    // Drop PNGs named like the built-in ones (idle, blink, talk, happy, sleep,
    // shock, dizzy, cheer, wink, eat, chew) into ~/.local/share/tetoos/teto/
    // and they replace the built-in pixels frame by frame. Any size; they are
    // fitted into her square and scaled without smoothing.
    readonly property string skinDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/tetoos/teto"
    property var skinFrames: []
    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null && ls *.png 2>/dev/null", "sh", win.skinDir]
        stdout: StdioCollector {
            onStreamFinished: win.skinFrames = text.split("\n").filter(f => f.endsWith(".png")).map(f => f.slice(0, -4))
        }
    }

    // --- where she is, and how she moves ----------------------------------------
    property real bx: 0
    property real by: 0
    property real vx: 0
    property real vy: 0
    property string phase: "home"          // home | held | fly | rest | walk
    property real facing: 1
    property real impact: 0

    function goHome() { win.bx = win.homeX; win.by = win.floorY; win.phase = "home"; }
    onHomeXChanged: if (win.phase === "home") goHome()
    onFloorYChanged: if (win.phase === "home") goHome()
    Component.onCompleted: goHome()

    FrameAnimation {
        running: win.visible && (win.phase === "fly" || win.phase === "walk")
        onTriggered: win.step(Math.min(0.033, frameTime))
    }

    function step(dt) {
        if (win.phase === "fly") {
            win.vy += 2600 * dt;
            win.bx += win.vx * dt;
            win.by += win.vy * dt;
            if (win.bx < 0) { win.bx = 0; win.vx = -win.vx * 0.55; Sfx.play("tap", 0.8); }
            if (win.bx > win.sw - win.bw) { win.bx = win.sw - win.bw; win.vx = -win.vx * 0.55; Sfx.play("tap", 0.8); }
            if (win.by < 0) { win.by = 0; win.vy = -win.vy * 0.4; }
            if (win.by >= win.floorY) {
                win.by = win.floorY;
                win.impact = Math.max(win.impact, Math.abs(win.vy));
                if (Math.abs(win.vy) > 650) {
                    win.vy = -win.vy * 0.42;
                    win.vx *= 0.75;
                    squash.restart();
                    Sfx.play("boing", 0.9 + Math.random() * 0.2);
                } else {
                    win.vy = 0;
                    win.vx = 0;
                    win.phase = "rest";
                    squash.restart();
                    Teto.landed(win.impact > 1500);
                    rest.interval = win.impact > 1500 ? 3400 : 1400;
                    rest.restart();
                }
            }
            if (Math.abs(win.vx) > 30) win.facing = win.vx > 0 ? 1 : -1;
        } else if (win.phase === "walk") {
            const d = win.homeX - win.bx;
            win.facing = d > 0 ? 1 : -1;
            const s = Math.min(Math.abs(d), 170 * dt);
            win.bx += Math.sign(d) * s;
            if (Math.abs(d) < 1) { win.goHome(); win.facing = 1; Teto.settle(); }
        }
    }
    Timer {
        id: rest
        onTriggered: if (win.phase === "rest") win.phase = Math.abs(win.bx - win.homeX) > 4 ? "walk" : "home"
    }

    // a quick squash when she lands
    property real squashY: 1
    SequentialAnimation {
        id: squash
        NumberAnimation { target: win; property: "squashY"; to: 0.82; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "squashY"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    // --- the 8 fps clock everything little runs on -----------------------------------
    property int tick: 0
    Timer {
        running: win.visible
        interval: 125
        repeat: true
        onTriggered: win.tick++
    }

    readonly property bool karaoke: Teto.sticky && Media.playing && Lyrics.line !== ""
    readonly property string frame: {
        const m = Teto.mood, t = win.tick;
        if (win.phase === "held" || win.phase === "fly") return "shock";
        if (m === "dizzy") return "dizzy";
        if (m === "sleep") return "sleep";
        if (m === "eat") return t % 6 < 3 ? "eat" : "chew";
        if (m === "sing" || win.karaoke) return t % 3 === 0 ? "talk" : (t % 3 === 1 ? "happy" : "talk");
        if (Teto.talking) return t % 2 ? "talk" : "idle";
        if (m === "dance") return t % 8 < 4 ? "cheer" : "happy";
        if (Teto.petting) return t % 6 < 3 ? "wink" : "happy";
        if (m === "happy") return "happy";
        if (m === "shock") return "shock";
        return t % 37 === 0 || t % 37 === 2 ? "blink" : "idle";
    }

    readonly property real bob: {
        const t = win.tick;
        if (Teto.mood === "sleep") return [0, 0, 1, 1, 1, 0][t % 6] * win.px * 0.5;
        if (Teto.mood === "dance" || Teto.mood === "sing") return [0, -2, -4, -2][t % 4] * win.px * 0.5;
        if (win.phase === "walk") return [0, -2][t % 2] * win.px;
        return [0, 0, 0, 0, -1, -1, -1, -1][t % 8] * win.px * 0.25;
    }
    property real sway: {
        if (win.phase === "held") return Math.max(-28, Math.min(28, -win.dragVx / 45));
        if (win.phase === "fly") return Math.max(-40, Math.min(40, win.vx / 30));
        if (Teto.mood === "dance") return [-8, 0, 8, 0][Math.floor(win.tick / 2) % 4];
        if (Teto.mood === "dizzy") return Math.sin(win.tick * 0.9) * 6;
        return 0;
    }
    Behavior on sway { NumberAnimation { duration: 120 } }

    // --- shadow, Teto, and the bits around her --------------------------------------
    Rectangle {
        readonly property real lift: Math.max(0, win.floorY - win.by)
        width: win.bw * 0.62 * Math.max(0.35, 1 - lift / 600)
        height: width * 0.22
        radius: height / 2
        x: win.bx + win.bw / 2 - width / 2
        y: win.floorY + win.bh - height * 0.7
        color: Theme.alpha(Theme.ink, 0.28 * Math.max(0.2, 1 - lift / 600))
    }

    Item {
        id: body
        x: win.bx
        y: win.by + win.bob
        width: win.bw
        height: win.bh

        Image {
            id: sprite
            anchors.fill: parent
            source: win.skinFrames.indexOf(win.frame) >= 0
                ? "file://" + win.skinDir + "/" + win.frame + ".png"
                : Quickshell.shellDir + "/assets/teto/" + win.frame + ".png"
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
            cache: true
            transform: [
                Scale { origin.x: win.bw / 2; xScale: win.facing },
                Scale { origin.y: win.bh; origin.x: win.bw / 2; yScale: win.squashY; xScale: 2 - win.squashY },
                Rotation { origin.x: win.bw / 2; origin.y: win.phase === "held" ? 0 : win.bh; angle: win.sway }
            ]
        }

        MouseArea {
            id: hand
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: win.phase === "held" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point grab
            property point start
            property bool moved: false
            property var trail: []

            onPressed: event => {
                const p = hand.mapToItem(null, event.x, event.y);
                hand.start = p;
                hand.grab = Qt.point(p.x - win.bx, p.y - win.by);
                hand.moved = false;
                hand.trail = [{ x: p.x, y: p.y, t: Date.now() }];
            }
            onPositionChanged: event => {
                if (!hand.pressed || !(hand.pressedButtons & Qt.LeftButton)) return;
                const p = hand.mapToItem(null, event.x, event.y);
                if (!hand.moved && Math.hypot(p.x - hand.start.x, p.y - hand.start.y) > 8) {
                    hand.moved = true;
                    win.phase = "held";
                    rest.stop();
                    Teto.grabbed();
                }
                if (!hand.moved) return;
                win.bx = Math.max(-win.bw / 2, Math.min(win.sw - win.bw / 2, p.x - hand.grab.x));
                win.by = Math.max(0, Math.min(win.floorY, p.y - hand.grab.y));
                const now = Date.now();
                hand.trail = hand.trail.concat([{ x: p.x, y: p.y, t: now }]).filter(s => now - s.t < 90);
                if (hand.trail.length > 1) {
                    const a = hand.trail[0], b = hand.trail[hand.trail.length - 1];
                    win.dragVx = (b.x - a.x) / Math.max(1, b.t - a.t) * 1000;
                }
            }
            onReleased: event => {
                if (hand.moved) {
                    const now = Date.now();
                    const s = hand.trail.filter(q => now - q.t < 90);
                    let vx = 0, vy = 0;
                    if (s.length > 1) {
                        const a = s[0], b = s[s.length - 1];
                        const dt = Math.max(1, b.t - a.t) / 1000;
                        vx = (b.x - a.x) / dt;
                        vy = (b.y - a.y) / dt;
                    }
                    win.vx = Math.max(-4000, Math.min(4000, vx));
                    win.vy = Math.max(-4000, Math.min(4000, vy));
                    win.impact = 0;
                    win.dragVx = 0;
                    win.phase = "fly";
                    if (Math.hypot(vx, vy) > 600) Teto.thrown();
                    return;
                }
                if (event.button === Qt.RightButton) Teto.toggleMenu();
                else Teto.poke();
            }
            onWheel: event => Teto.pet()
        }
    }
    property real dragVx: 0

    Connections {
        target: Teto
        function onFling(vx, vy) {
            if (win.phase === "held") return;
            win.vx = vx;
            win.vy = vy;
            win.impact = 0;
            win.phase = "fly";
            Teto.thrown();
        }
    }

    // notes while she dances or sings
    Repeater {
        model: 3
        Label {
            required property int index
            readonly property real t: ((win.tick + index * 6) % 18) / 18
            visible: Teto.mood === "dance" || Teto.mood === "sing" || win.karaoke
            x: win.bx + win.bw * (index === 1 ? 0.95 : 0.05 + index * 0.4) + Math.sin(t * 6 + index) * 6
            y: win.by + win.bh * 0.15 - t * 70
            opacity: 1 - t
            text: ["♪", "♫", "♬"][index]
            size: 18 + index * 2
            color: [Theme.primaryStrong, Theme.secondaryStrong, Theme.tertiaryStrong][index]
            style: Text.Outline
            styleColor: Theme.paper
        }
    }
    // Zzz while she sleeps
    Repeater {
        model: 3
        Label {
            required property int index
            readonly property real t: ((win.tick + index * 8) % 24) / 24
            visible: Teto.mood === "sleep"
            x: win.bx + win.bw * 0.7 + t * 30
            y: win.by + win.bh * 0.1 - t * 50
            opacity: Math.min(1, (1 - t) * 1.5)
            text: "z"
            size: 14 + t * 10
            color: Theme.secondaryStrong
            style: Text.Outline
            styleColor: Theme.paper
        }
    }
    // hearts while petted
    Repeater {
        model: 4
        Icon {
            required property int index
            readonly property real t: ((win.tick * 1.5 + index * 4) % 16) / 16
            visible: Teto.petting
            x: win.bx + win.bw * (0.15 + index * 0.22)
            y: win.by + win.bh * 0.2 - t * 60
            opacity: 1 - t
            icon: "favorite"
            filled: true
            size: 16 + (index % 2) * 6
            color: Theme.primaryStrong
        }
    }
    // stars round her head when dizzy
    Repeater {
        model: 3
        Icon {
            required property int index
            readonly property real a: win.tick * 0.5 + index * Math.PI * 2 / 3
            visible: Teto.mood === "dizzy"
            x: win.bx + win.bw / 2 + Math.cos(a) * win.bw * 0.42 - 9
            y: win.by + win.bh * 0.08 + Math.sin(a) * win.bw * 0.12
            icon: "star"
            filled: true
            size: 18
            color: Theme.warn
            style: Text.Outline
            styleColor: Theme.ink
        }
    }
    // crumbs while she eats
    Repeater {
        model: 4
        Rectangle {
            required property int index
            readonly property real t: ((win.tick + index * 3) % 10) / 10
            visible: Teto.mood === "eat"
            width: win.px; height: win.px
            color: index % 2 ? "#ecb862" : "#b97b2c"
            x: win.bx + win.bw * 0.66 + (index - 1.5) * win.px * 2 + t * 6
            y: win.by + win.bh * 0.5 + t * win.bh * 0.45
            opacity: 1 - t
        }
    }

    // --- the bubble: what she says, or her menu -------------------------------------------
    // The whole line, laid out unseen, sizes the bubble from the first letter so
    // it does not grow while she types.
    Label { id: measure; visible: false; text: Teto.text; size: 13; weight: 600 }
    Label { id: full; visible: false; width: bubble.width - 30; text: Teto.text; size: 13; weight: 600; wrapMode: Text.Wrap; elide: Text.ElideNone; maximumLineCount: 6 }

    Sticker {
        id: bubble
        visible: (Teto.bubble || Teto.menuOpen) && win.phase !== "fly"
        readonly property bool below: win.by < height + 60
        width: Teto.menuOpen ? 230 : Math.min(300, Math.max(70, measure.implicitWidth + 30))
        height: Teto.menuOpen ? menu.implicitHeight + 22 : Math.max(said.implicitHeight, full.implicitHeight) + 24
        x: Math.max(8, Math.min(win.sw - width - 8, win.bx + win.bw * 0.5 - width * 0.78))
        y: below ? win.by + win.bh + 14 : win.by + win.bob - height - 16
        radius: 16
        lift: 3
        fill: Theme.paper
        scale: visible ? 1 : 0.6
        transformOrigin: below ? Item.TopRight : Item.BottomRight
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        Rectangle {
            width: 16; height: 16
            rotation: 45
            color: Theme.paper
            border.color: Theme.ink
            border.width: Theme.outline
            x: Math.max(14, Math.min(bubble.width - 30, win.bx + win.bw * 0.5 - bubble.x - 8))
            y: bubble.below ? -8 : bubble.height - 9
            z: -1
        }
        Rectangle {
            // hides the half of the tail that sits inside the bubble
            x: Math.max(12, Math.min(bubble.width - 32, win.bx + win.bw * 0.5 - bubble.x - 10))
            y: bubble.below ? Theme.outline : bubble.height - 14
            width: 22; height: 12
            color: Theme.paper
        }

        Label {
            id: said
            visible: !Teto.menuOpen
            x: 15; y: 12
            width: bubble.width - 30
            text: Teto.text.slice(0, Teto.shown)
            size: 13
            weight: 600
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 6
        }
        MouseArea {
            anchors.fill: parent
            visible: !Teto.menuOpen
            onClicked: Teto.quiet()
        }

        Column {
            id: menu
            visible: Teto.menuOpen
            x: 11; y: 11
            width: parent.width - 22
            spacing: 5
            Row {
                spacing: 6
                Icon { anchors.verticalCenter: parent.verticalCenter; icon: "favorite"; filled: true; size: 15; color: Theme.primaryStrong }
                Label { text: "Тето · " + Config.options.tetoLove + " ❤"; size: 12; weight: 700 }
            }
            Repeater {
                model: [
                    { icon: "chat", text: "Поболтать", run: () => Teto.chat() },
                    { icon: "music_note", text: "Спой!", run: () => Teto.singSong() },
                    { icon: "celebration", text: "Потанцуй", run: () => Teto.dance() },
                    { icon: "bakery_dining", text: Bread.ready ? "Батон дня ✦" : "Батон дня (завтра)", hot: Bread.ready, run: () => { Bread.open(); Ui.togglePopup("bread", -1, null); Teto.eatBread(); } },
                    { icon: "lightbulb", text: "Подсказка", run: () => Teto.tip() },
                    { icon: "lyrics", text: Config.options.tetoKaraoke ? "Караоке: вкл" : "Караоке: выкл", run: () => { Config.toggle("tetoKaraoke"); Teto.toggleMenu(); } },
                    { icon: Config.options.tetoVoice ? "record_voice_over" : "voice_over_off", text: Config.options.tetoVoice ? "Голос: вкл" : "Голос: выкл", run: () => { Config.toggle("tetoVoice"); Teto.toggleMenu(); } },
                    { icon: "visibility_off", text: "Спрятаться на час", run: () => Teto.snooze(60) }
                ]
                Tap {
                    required property var modelData
                    width: menu.width
                    height: 30
                    radius: 10
                    lift: 2
                    icon: modelData.icon
                    iconSize: 16
                    text: modelData.text
                    textSize: 12
                    fill: modelData.hot ? Theme.primary : Theme.paper
                    onClicked: { Teto.menuOpen = false; modelData.run(); }
                }
            }
        }
    }
}
