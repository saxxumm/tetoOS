import QtQuick
import "root:/theme"

// A dot grid, the paper texture behind the edit mode and inside the phone.
// Painted once per size or colour change, never per frame.
Canvas {
    id: root

    property color dot: Theme.alpha(Theme.ink, 0.12)
    property real spacing: 18
    property real radius: 1.4

    renderStrategy: Canvas.Cooperative
    onDotChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = root.dot;
        for (let y = root.spacing / 2; y < height; y += root.spacing) {
            for (let x = root.spacing / 2; x < width; x += root.spacing) {
                ctx.beginPath();
                ctx.arc(x, y, root.radius, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
