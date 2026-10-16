import QtQuick
import "root:/theme"

// A Material Symbols glyph, by ligature name ("wifi", "volume_up").
Text {
    id: root

    property string icon: ""
    property real size: 18
    property bool filled: false
    property int weight: 600

    text: root.icon
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: root.size
    font.weight: root.weight
    font.variableAxes: { "FILL": root.filled ? 1 : 0, "wght": root.weight, "opsz": 24 }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
