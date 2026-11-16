import QtQuick

// Rounds anything underneath it. QtQuick's `clip: true` is rectangular, so an
// Image inside a rounded Rectangle keeps square corners. Lay this over the
// content with `color` set to what is behind it: it paints that colour
// everywhere except a rounded rectangle, which is cut out with
// destination-out. Pure Canvas, so it works on the software backend too (no
// shaders / MultiEffect). `bleed` hides the hairline at the straight edges.
Canvas {
    id: root

    property color color: "#000000"
    property real radius: 16
    property real bleed: 1

    readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

    anchors.margins: -bleed
    antialiasing: true
    canvasSize: Qt.size(Math.max(1, Math.ceil(width * dpr)), Math.max(1, Math.ceil(height * dpr)))

    onCanvasSizeChanged: requestPaint()
    onColorChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onBleedChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0) return;
        const b = root.bleed;
        const x = b, y = b, w = width - 2 * b, h = height - 2 * b;
        const r = Math.max(0, Math.min(root.radius, w / 2, h / 2));

        ctx.save();
        ctx.scale(root.dpr, root.dpr);
        ctx.fillStyle = root.color;
        ctx.fillRect(0, 0, width, height);
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
    }
}
