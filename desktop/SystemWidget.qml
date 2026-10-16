import QtQuick
import "root:/theme"
import "root:/ui"
import "root:/services"

// The machine at a glance: four inked dials and a tiny CPU history.
Sticker {
    id: root

    implicitWidth: 300
    implicitHeight: 214
    fill: Theme.paper
    radius: 16
    lift: 4

    // the last minute of CPU, one sample every two seconds
    property var history: []
    Connections {
        target: Resources
        function onCpuChanged() { root.history = root.history.concat([Resources.cpu]).slice(-30); }
    }

    Row {
        id: head
        x: 14; y: 12
        spacing: 9
        Sticker {
            width: 34; height: 34; radius: 10; lift: 2; fill: Theme.tertiary
            Icon { anchors.centerIn: parent; icon: "memory"; size: 20; filled: true }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -4
            Label { text: "System"; size: 17; weight: 700 }
            Label { text: Resources.memUsedMb > 0 ? (Resources.memUsedMb / 1024).toFixed(1) + " / " + (Resources.memTotalMb / 1024).toFixed(1) + " GB · up " + Sys.uptime : "reading…"; size: 10; weight: 500; color: Theme.textSoft }
        }
    }

    Row {
        id: dials
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: head.bottom
        anchors.topMargin: 10
        spacing: 10
        Dial { label: "CPU"; value: Resources.cpu; text: Math.round(Resources.cpu * 100) + "%"; tint: Theme.primaryStrong }
        Dial { label: "RAM"; value: Resources.memory; text: Math.round(Resources.memory * 100) + "%"; tint: Theme.secondaryStrong }
        Dial { label: "TEMP"; value: Math.min(1, Resources.temperature / 100); text: Math.round(Resources.temperature) + "°"; tint: Resources.temperature > 80 ? Theme.bad : Theme.tertiaryStrong }
        Dial { label: "DISK"; value: Resources.disk; text: Math.round(Resources.disk * 100) + "%"; tint: Theme.warn }
    }

    Sticker {
        x: 12
        anchors.top: dials.bottom
        anchors.topMargin: 10
        width: parent.width - 24
        height: 34
        radius: 10
        lift: 0
        fill: Theme.paper2
        Row {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            Repeater {
                model: 30
                Item {
                    required property int index
                    readonly property real v: root.history.length > index - (30 - root.history.length) && index >= 30 - root.history.length ? root.history[index - (30 - root.history.length)] : 0
                    width: (root.width - 24 - 12 - 29 * 2) / 30
                    height: parent.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * parent.v)
                        radius: 1.5
                        color: parent.v > 0.85 ? Theme.bad : Theme.primaryStrong
                    }
                }
            }
        }
    }

    component Dial: Item {
        id: dial
        property string label: ""
        property string text: ""
        property real value: 0
        property color tint: Theme.primaryStrong
        width: 60
        height: 82
        Canvas {
            id: ring
            width: 60; height: 60
            property real v: dial.value
            property color c: dial.tint
            property color track: Theme.paper3
            property color ink: Theme.ink
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            onTrackChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = 24, cx = 30, cy = 30, a0 = Math.PI * 0.75, a1 = Math.PI * 2.25;
                ctx.lineCap = "round";
                ctx.lineWidth = 11;
                ctx.strokeStyle = ink;
                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a1); ctx.stroke();
                ctx.lineWidth = 7;
                ctx.strokeStyle = track;
                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a1); ctx.stroke();
                if (v > 0.01) {
                    ctx.strokeStyle = c;
                    ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + (a1 - a0) * Math.min(1, v)); ctx.stroke();
                }
            }
        }
        Label { anchors.centerIn: ring; text: dial.text; size: 13; weight: 700 }
        Label { anchors.horizontalCenter: ring.horizontalCenter; anchors.top: ring.bottom; anchors.topMargin: 2; text: dial.label; size: 9; weight: 700; color: Theme.textSoft; font.letterSpacing: 0.6 }
    }
}
