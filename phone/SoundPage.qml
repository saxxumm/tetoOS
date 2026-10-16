import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "root:/theme"
import "root:/ui"
import "root:/services"

// Sound, with the phone on its side: where it plays, how loud each
// application is, and the ten-band equalizer.
Item {
    id: root

    // --- header --------------------------------------------------------------
    Sticker {
        id: title
        x: 14; y: 16
        width: 300; height: 46
        radius: 16
        fill: Theme.tertiary
        gloss: true
        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Sticker {
                width: 30; height: 30; radius: 9; lift: 0
                Icon { anchors.centerIn: parent; icon: "graphic_eq"; size: 18; filled: true }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4
                Label { text: "Sound"; size: 18; weight: 700 }
                Label { text: "Equalizer, outputs and apps"; size: 10; weight: 500; color: Theme.textSoft }
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 20
        spacing: 9
        Tap { height: 34; icon: "tune"; text: "pavucontrol"; textSize: 11; onClicked: { Ui.closePhone(); Quickshell.execDetached(["pavucontrol"]); } }
        Tap { width: 36; height: 36; icon: "close"; onClicked: Ui.closePhone() }
    }

    // --- left: outputs and applications ---------------------------------------
    Sticker {
        id: mixer
        x: 14
        anchors.top: title.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: 360
        radius: 20
        lift: 4
        fill: Theme.paper

        Scroll {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: mixCol.height
            Column {
                id: mixCol
                width: parent.width - 6
                spacing: 8

                Label { text: "OUTPUT"; size: 10; weight: 700; color: Theme.textSoft; font.letterSpacing: 0.8 }
                Row {
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; icon: Audio.muted ? "volume_off" : "volume_up"; size: 18; filled: true
                        MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() } }
                    Slide { anchors.verticalCenter: parent.verticalCenter; width: mixCol.width - 70; height: 14; value: Math.min(1, Audio.volume); onMoved: v => Audio.setVolume(v) }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Audio.volume * 100); size: 12; weight: 700 }
                }
                Repeater {
                    model: Audio.sinks
                    Tap {
                        required property var modelData
                        width: mixCol.width
                        height: 34
                        radius: 12
                        lift: 2
                        icon: modelData.name.indexOf("eq10") >= 0 ? "graphic_eq" : modelData.name.indexOf("bluez") >= 0 ? "headphones" : "speaker"
                        iconSize: 16
                        text: Audio.label(modelData)
                        textSize: 12
                        maxText: mixCol.width - 70
                        active: Audio.defaultSinkName === modelData.name
                        fill: active ? Theme.primary : Theme.paper
                        onClicked: Audio.setSink(modelData)
                    }
                }

                Item { width: 1; height: 4 }
                Label { text: "APPS"; size: 10; weight: 700; color: Theme.textSoft; font.letterSpacing: 0.8 }
                Repeater {
                    // the equalizer's own output is a stream too; it is not an app
                    model: Audio.streams.filter(n => (n.name || "").indexOf("effect_output") !== 0)
                    Column {
                        id: app
                        required property var modelData
                        readonly property var props: modelData.properties || {}
                        readonly property string name: props["application.name"] || modelData.description || modelData.name
                        readonly property string iconName: props["application.icon-name"] || props["application.process.binary"] || ""
                        width: mixCol.width
                        spacing: 3
                        Row {
                            spacing: 7
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: app.iconName !== "" ? Quickshell.iconPath(app.iconName, "audio-x-generic") : Quickshell.iconPath("audio-x-generic", true)
                            }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: app.name; size: 12; weight: 650; width: mixCol.width - 60 }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: app.modelData.audio && app.modelData.audio.muted ? "volume_off" : "volume_up"
                                size: 16
                                MouseArea { anchors.fill: parent; onClicked: if (app.modelData.audio) app.modelData.audio.muted = !app.modelData.audio.muted }
                            }
                        }
                        Slide {
                            width: mixCol.width
                            height: 12
                            fill: Theme.secondaryStrong
                            value: app.modelData.audio ? Math.min(1, app.modelData.audio.volume) : 0
                            onMoved: v => { if (app.modelData.audio && !Sfx.nested) app.modelData.audio.volume = v; }
                        }
                    }
                }
                Label { visible: Audio.streams.length === 0; text: "Nothing is playing"; size: 12; color: Theme.textSoft }
            }
        }
    }

    // --- right: the equalizer -----------------------------------------------------
    Sticker {
        id: eq
        anchors.left: mixer.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: mixer.top
        anchors.bottom: mixer.bottom
        radius: 20
        lift: 4
        fill: Theme.paper

        Row {
            id: eqHead
            x: 16; y: 14
            spacing: 10
            Label { anchors.verticalCenter: parent.verticalCenter; text: "EQUALIZER"; size: 13; weight: 700; font.letterSpacing: 0.8 }
            Switch { anchors.verticalCenter: parent.verticalCenter; checked: Eq.active; onToggled: Eq.toggle() }
            Tag {
                anchors.verticalCenter: parent.verticalCenter
                text: !Eq.available ? "no EQ sink" : Eq.routed ? "in the path" : "not in the path"
                size: 10
                fill: Eq.routed ? Theme.good : Theme.paper2
            }
        }
        Tap {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: eqHead.verticalCenter
            height: 30
            icon: Eq.routed ? "link_off" : "link"
            text: Eq.routed ? "Bypass" : "Play through EQ"
            textSize: 11
            enabled: Eq.available
            fill: Eq.routed ? Theme.paper : Theme.primary
            onClicked: Eq.route()
        }

        Row {
            id: presets
            x: 16
            anchors.top: eqHead.bottom
            anchors.topMargin: 12
            spacing: 6
            Repeater {
                model: Eq.presets
                Tap {
                    required property var modelData
                    height: 28
                    radius: 9
                    lift: 2
                    text: modelData.name
                    textSize: 11
                    active: Eq.preset === modelData.id
                    fill: active ? (modelData.id === "teto" ? Theme.primaryStrong : Theme.primary) : Theme.paper
                    fg: active && modelData.id === "teto" ? Theme.strongText : Theme.text
                    onClicked: Eq.usePreset(modelData.id)
                }
            }
            Tag { anchors.verticalCenter: parent.verticalCenter; visible: Eq.preset === "custom"; text: "CUSTOM"; size: 10; fill: Theme.secondary }
        }

        // the bands, with the curve drawn through their knobs
        Item {
            id: bands
            anchors.top: presets.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 38
            readonly property real slot: width / Eq.bands.length

            Canvas {
                id: curve
                anchors.fill: parent
                property var g: Eq.gains
                property color c: Theme.primaryStrong
                onGChanged: requestPaint()
                onCChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const pts = g.map((v, i) => [bands.slot * (i + 0.5), height * (1 - (v + 12) / 24)]);
                    ctx.beginPath();
                    ctx.moveTo(pts[0][0], pts[0][1]);
                    for (let i = 1; i < pts.length; i++) {
                        const mx = (pts[i - 1][0] + pts[i][0]) / 2;
                        ctx.bezierCurveTo(mx, pts[i - 1][1], mx, pts[i][1], pts[i][0], pts[i][1]);
                    }
                    ctx.lineTo(pts[pts.length - 1][0], height / 2);
                    ctx.lineTo(pts[0][0], height / 2);
                    ctx.closePath();
                    ctx.fillStyle = Theme.alpha(c, 0.14);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.moveTo(pts[0][0], pts[0][1]);
                    for (let i = 1; i < pts.length; i++) {
                        const mx = (pts[i - 1][0] + pts[i][0]) / 2;
                        ctx.bezierCurveTo(mx, pts[i - 1][1], mx, pts[i][1], pts[i][0], pts[i][1]);
                    }
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = Theme.alpha(c, 0.7);
                    ctx.stroke();
                }
            }

            Repeater {
                model: Eq.bands
                Item {
                    id: band
                    required property var modelData
                    required property int index
                    x: bands.slot * index
                    width: bands.slot
                    height: bands.height
                    VSlide {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: parent.height
                        value: Eq.gains[band.index]
                        fill: band.index < 3 ? Theme.secondaryStrong : band.index < 7 ? Theme.primaryStrong : Theme.tertiaryStrong
                        onMoved: v => Eq.setBand(band.index, v)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        text: band.modelData.label
                        size: 11
                        weight: 700
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 2
                        text: Eq.formatDb(Eq.gains[band.index])
                        size: 9
                        weight: 600
                        color: Theme.textSoft
                    }
                }
            }
        }
    }
}
