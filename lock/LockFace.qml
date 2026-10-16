import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/theme"
import "root:/ui"
import "root:/services"

// What the lock screen looks like. It knows nothing about PAM: it reports
// keystrokes and a submit, and is told whether it is busy or was wrong.
// The same face draws the real lock and the preview.
Item {
    id: root

    property string entry: ""
    property bool busy: false
    property string status: ""            // "" | wrong
    property int attempts: 0
    property date since: new Date()

    signal typed(string text)
    signal backspaced()
    signal submitted()
    signal cleared()

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.submitted();
        else if (event.key === Qt.Key_Backspace) (event.modifiers & Qt.ControlModifier) ? root.cleared() : root.backspaced();
        else if (event.key === Qt.Key_Escape) root.cleared();
        else if (event.text !== "" && event.text.charCodeAt(0) >= 32) root.typed(event.text);
        event.accepted = true;
    }

    onAttemptsChanged: if (root.attempts > 0) shake.restart()

    // --- the picture ------------------------------------------------------------
    Rectangle { anchors.fill: parent; color: Theme.night }
    Image {
        anchors.fill: parent
        source: {
            const p = Config.ready && Config.options.lockWallpaper !== "" ? Config.options.lockWallpaper : Wallpaper.current;
            return p ? "file://" + p : "";
        }
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 3840
        sourceSize.height: 2160
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.night, 0.35) }
            GradientStop { position: 0.35; color: Theme.alpha(Theme.night, 0.0) }
            GradientStop { position: 0.75; color: Theme.alpha(Theme.night, 0.0) }
            GradientStop { position: 1; color: Theme.alpha(Theme.night, 0.55) }
        }
    }

    // --- date and the big clock ------------------------------------------------------
    Label {
        x: 480
        y: 56
        text: Qt.formatDate(Sys.now, "dddd, MMMM d")
        size: 34
        weight: 700
        color: "white"
        style: Text.Raised
        styleColor: Theme.alpha(Theme.ink, 0.6)
    }
    Item {
        id: clock
        x: 470
        y: 104
        width: big.implicitWidth
        height: big.implicitHeight
        StrokeText {
            id: big
            text: Sys.hours() + ":" + Sys.minutes()
            size: 230
            weight: 700
            stroke: 7
            drop: 9
            edge: Theme.ink
            fillTop: "white"
            fillBottom: Theme.mix(Theme.paper, Theme.primary, 0.5)
        }
        Tag {
            anchors.left: big.right
            anchors.leftMargin: 6
            anchors.bottom: big.bottom
            anchors.bottomMargin: 50
            text: Config.ready && Config.options.clock24 ? Qt.formatDate(Sys.now, "ddd").toUpperCase() : Sys.ampm()
            size: 26
            fill: Theme.secondary
        }
    }

    // --- who, and what is playing -----------------------------------------------------
    Sticker {
        x: 52; y: 130
        width: 340
        height: Media.has ? 196 : 112
        radius: 20
        lift: 5
        fill: Theme.night
        Sticker {
            id: who
            x: 10; y: 10
            width: parent.width - 20
            height: 92
            radius: 14
            lift: 2
            fill: Theme.secondary
            gloss: true
            Avatar { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; radius: 18 }
            Column {
                x: 88
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3
                Label { text: Sys.name; size: 24; weight: 700 }
                Label { text: "Screen locked"; size: 13; weight: 600; color: Theme.textSoft }
            }
            Sticker {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20; lift: 2; fill: Theme.paper
                Icon { anchors.centerIn: parent; icon: "lock"; size: 20; filled: true }
            }
        }
        Row {
            visible: Media.has
            x: 22
            anchors.top: who.bottom
            anchors.topMargin: 18
            spacing: 14
            ClippingRectangle {
                width: 52; height: 52; radius: 12
                color: Theme.night2
                Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; sourceSize.width: 128; asynchronous: true }
                Icon { anchors.centerIn: parent; visible: Media.art === ""; icon: "music_note"; size: 24; color: Theme.nightText }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3
                Label { text: Media.title; size: 17; weight: 700; color: Theme.nightText; width: 200 }
                Label { text: Media.artist; size: 12; weight: 500; color: Theme.nightSoft; width: 200 }
            }
        }
    }

    Sticker {
        anchors.right: parent.right
        anchors.rightMargin: 52
        y: 56
        visible: Power.hasBattery
        width: 120; height: 46
        radius: 23
        lift: 3
        fill: Theme.night
        Row {
            anchors.centerIn: parent
            spacing: 8
            BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; color: Theme.nightText }
            Label { text: Math.round(Power.level * 100) + "%"; size: 18; weight: 700; color: Theme.nightText }
        }
    }

    Sticker {
        x: 470
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: sinceRow.implicitWidth + 32
        height: 42
        radius: 21
        lift: 3
        fill: Theme.night
        Row {
            id: sinceRow
            anchors.centerIn: parent
            spacing: 8
            Icon { icon: "lock_clock"; size: 18; color: Theme.nightText; filled: true }
            Label { text: "Locked since " + Sys.time(root.since); size: 15; weight: 700; color: Theme.nightText }
        }
    }

    // --- password and unlock ----------------------------------------------------------
    Row {
        id: auth
        anchors.right: parent.right
        anchors.rightMargin: 52
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        spacing: 22
        transform: Translate { id: nudge; x: 0 }

        Sticker {
            width: 520; height: 112
            radius: 30
            lift: 6
            fill: Theme.paper
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                text: root.status === "wrong" ? "Wrong password" : root.busy ? "Checking…" : "Password"
                size: 30
                weight: 700
                color: root.status === "wrong" ? Theme.bad : Theme.text
            }
            Sticker {
                x: 30
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: parent.width - 60
                height: 42
                radius: 21
                lift: 0
                fill: Theme.night
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: Math.min(root.entry.length, 22)
                        Rectangle {
                            required property int index
                            width: 14; height: 14; radius: 7
                            color: [Theme.tertiary, Theme.primary, Theme.warn, Theme.secondary, Theme.good, Theme.tertiaryStrong][index % 6]
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: root.entry.length === 0
                    text: "type to unlock"
                    size: 14
                    weight: 600
                    color: Theme.alpha(Theme.nightText, 0.5)
                }
            }
        }

        Sticker {
            width: 220; height: 112
            radius: 30
            lift: 6
            fill: Theme.secondary
            gloss: true
            Tag { x: 18; y: -10; text: "Enter"; size: 12; fill: Theme.tertiary }
            Label { anchors.horizontalCenter: parent.horizontalCenter; y: 12; text: "Unlock"; size: 30; weight: 700 }
            Sticker {
                x: 22
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: parent.width - 44
                height: 42
                radius: 21
                lift: 0
                fill: Theme.night
                Icon { anchors.centerIn: parent; icon: root.busy ? "hourglass_top" : "arrow_forward"; size: 22; color: Theme.nightText }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submitted() }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: nudge; property: "x"; to: -18; duration: 50 }
        NumberAnimation { target: nudge; property: "x"; to: 16; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: -10; duration: 60 }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 80; easing.type: Easing.OutBack }
    }

    // --- the way in: rings in the scheme's colours open from the middle ---------------------
    Item {
        id: rings
        anchors.fill: parent
        property real t: 0
        readonly property real far: Math.hypot(width, height)
        visible: t < 1
        opacity: t < 0.75 ? 1 : (1 - t) * 4
        Rectangle { anchors.fill: parent; color: Theme.tertiary; opacity: rings.t < 0.75 ? 1 : 0 }
        Repeater {
            model: [Theme.secondary, Theme.paper, Theme.tertiary, Theme.primary, Theme.paper]
            Rectangle {
                required property color modelData
                required property int index
                readonly property real r: Math.max(0, rings.t * 2.2 - index * 0.22) * rings.far * 0.6
                width: r * 2; height: r * 2
                radius: r
                x: rings.width / 2 - r
                y: rings.height / 2 - r
                color: modelData
            }
        }
        NumberAnimation on t { id: intro; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutQuad; running: false }
    }
    function playIntro() { intro.restart(); }
}
