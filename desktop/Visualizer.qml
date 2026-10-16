import QtQuick
import "root:/theme"
import "root:/services"

// Ribbons along the bottom of the desk that move with the music: three
// smoothed curves drawn off cava's bands, in the scheme's colours, over a few
// still speed lines. With nothing playing it is a quiet still wave and costs
// nothing — cava is only asked to run while there is sound.
Canvas {
    id: root

    property bool active: Media.playing
    property var levels: Spectrum.levels
    property real phase: 0

    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative

    onLevelsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
        target: Theme
        function onPrimaryStrongChanged() { root.requestPaint(); }
        function onSecondaryStrongChanged() { root.requestPaint(); }
    }

    onActiveChanged: active ? Spectrum.watch() : Spectrum.unwatch()
    Component.onCompleted: if (active) Spectrum.watch()
    Component.onDestruction: if (active) Spectrum.unwatch()

    // smoothed copy so the ribbons glide between cava frames
    property var smooth: []

    function sample(arr, t) {
        if (!arr || arr.length === 0) return 0;
        const x = t * (arr.length - 1);
        const i = Math.floor(x), f = x - i;
        const a = arr[i], b = arr[Math.min(arr.length - 1, i + 1)];
        return a + (b - a) * (f * f * (3 - 2 * f));
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height, mid = h * 0.58;

        const src = root.levels && root.levels.length ? root.levels : [];
        const next = [];
        for (let i = 0; i < src.length; i++) {
            const prev = root.smooth[i] || 0;
            next.push(prev + (src[i] - prev) * 0.45);
        }
        root.smooth = next;

        // speed lines
        ctx.lineWidth = 1.2;
        for (let k = 0; k < 7; k++) {
            const y = mid - 26 + k * 9;
            ctx.strokeStyle = Theme.alpha(Theme.ink, 0.10 + (k % 3) * 0.03);
            ctx.beginPath();
            ctx.moveTo(w * (0.02 + (k * 0.13) % 0.3), y);
            ctx.lineTo(w * (0.7 + (k * 0.07) % 0.28), y + (k - 3) * 1.5);
            ctx.stroke();
        }

        const ribbons = [
            { color: Theme.alpha(Theme.tertiaryStrong, 0.55), amp: 0.55, freq: 2.2, off: 0.0, width: 10 },
            { color: Theme.alpha(Theme.secondaryStrong, 0.6), amp: 0.75, freq: 1.6, off: 1.7, width: 6 },
            { color: Theme.alpha(Theme.primaryStrong, 0.9), amp: 1.0, freq: 1.2, off: 3.1, width: 4 },
            { color: Theme.alpha(Theme.paper, 0.95), amp: 0.9, freq: 1.2, off: 3.1, width: 1.6 }
        ];
        for (const r of ribbons) {
            ctx.strokeStyle = r.color;
            ctx.lineWidth = r.width;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            const steps = 96;
            for (let s = 0; s <= steps; s++) {
                const t = s / steps;
                const env = Math.sin(Math.PI * t);
                const level = root.sample(root.smooth, (t * 0.85 + r.off * 0.03) % 1);
                const base = Math.sin(t * Math.PI * 2 * r.freq + r.off) * 0.32;
                const y = mid - (base + level * 0.9 * Math.sin(t * Math.PI * 6 + r.off)) * h * 0.42 * r.amp * (0.35 + env * 0.65);
                if (s === 0) ctx.moveTo(t * w, y); else ctx.lineTo(t * w, y);
            }
            ctx.stroke();
        }
    }
}
