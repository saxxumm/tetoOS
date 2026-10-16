import QtQuick
import QtQuick.Effects
import "root:/theme"

// Display type with a fat ink outline, a hard drop and a two-colour fill — the
// bubbly desktop clock. The outline is the same glyphs stamped in a ring,
// which is cheap for the handful of characters it is used on.
Item {
    id: root

    property string text: ""
    property real size: 96
    property int weight: 700
    property real stroke: 5
    property real drop: 6
    property color edge: Theme.ink
    property color fillTop: Theme.paper
    property color fillBottom: Theme.primary
    property real spacing: 0

    implicitWidth: face.implicitWidth + root.stroke * 2
    implicitHeight: face.implicitHeight + root.stroke * 2 + root.drop

    readonly property var ring: {
        const pts = [];
        const n = 12;
        for (let i = 0; i < n; i++) {
            const a = i / n * Math.PI * 2;
            pts.push([Math.cos(a) * root.stroke, Math.sin(a) * root.stroke]);
        }
        return pts;
    }

    // the drop, then the ring, then the fill
    Repeater {
        model: root.ring
        Text {
            required property var modelData
            x: root.stroke + modelData[0]
            y: root.stroke + modelData[1] + root.drop
            text: root.text
            font: face.font
            color: root.edge
        }
    }
    Repeater {
        model: root.ring
        Text {
            required property var modelData
            x: root.stroke + modelData[0]
            y: root.stroke + modelData[1]
            text: root.text
            font: face.font
            color: root.edge
        }
    }

    Text {
        id: face
        x: root.stroke
        y: root.stroke
        text: root.text
        font.family: Theme.font
        font.pixelSize: root.size
        font.weight: root.weight
        font.letterSpacing: root.spacing
        color: "white"
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: tint
        x: face.x
        y: face.y
        width: face.width
        height: face.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.15; color: root.fillTop }
            GradientStop { position: 0.85; color: root.fillBottom }
        }
    }

    MultiEffect {
        x: face.x
        y: face.y
        width: face.width
        height: face.height
        source: tint
        maskEnabled: true
        maskSource: face
        maskThresholdMin: 0.4
        maskSpreadAtMin: 0.2
    }
}
