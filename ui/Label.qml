import QtQuick
import "root:/theme"

// Type in the shell's face. `size` in pixels, `weight` as a CSS weight.
Text {
    id: root

    property real size: 13
    property int weight: 600

    color: Theme.text
    // Fredoka has no Cyrillic; Russian text is set in Fira Sans a step lighter
    // so it does not shout next to the rounded face.
    readonly property bool cyrillic: /[\u0400-\u04FF]/.test(root.text)
    font.family: root.cyrillic ? Theme.fontAlt : Theme.font
    font.pixelSize: root.cyrillic ? root.size * 0.95 : root.size
    font.weight: root.cyrillic ? Math.max(400, root.weight - 100) : root.weight
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
