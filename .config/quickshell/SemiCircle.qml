import QtQuick

// Semicircle ("dome") from the shape-morphing practice, brought into the shell.
//
// Same construction as the practice component: a flat edge with softly rounded
// corners and a continuous half-ellipse built from cubic Beziers (kappa 0.5523),
// drawn directly on a Canvas. The practice 1.6:1 silhouette is
//   width 1.6, height 1.0, corner radius 0.1, curved part 0.5
// so with the defaults below (cornerFrac 0.1, curveFrac 0.5) a 1.6:1 item
// reproduces it exactly. `curveFrac` / `cornerFrac` are fractions of the height
// and can be driven by a SpringValue to morph the silhouette.
Canvas {
    id: root

    property color fill: "#D0BCFF"
    property real curveFrac: 0.5      // height of the curved half / total height
    property real cornerFrac: 0.1     // flat-edge corner radius / total height
    property real angle: 0            // degrees, rotates about the item centre

    readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
    readonly property real kappa: 0.5522847498

    antialiasing: true
    // Rasterise at device resolution so the curve stays crisp at any UI scale.
    canvasSize: Qt.size(Math.max(1, Math.ceil(width * dpr)), Math.max(1, Math.ceil(height * dpr)))

    onCanvasSizeChanged: requestPaint()
    onFillChanged: requestPaint()
    onCurveFracChanged: requestPaint()
    onCornerFracChanged: requestPaint()
    onAngleChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0) return;

        const k = root.kappa;
        const w = width, h = height;
        const ry = Math.min(h, h * Math.max(0.05, root.curveFrac));
        const rx = w / 2;
        const r = Math.max(0, Math.min(h * root.cornerFrac, h - ry, rx));
        const sideEnd = h - ry;                 // where the straight sides stop

        ctx.save();
        ctx.scale(root.dpr, root.dpr);
        ctx.translate(w / 2, h / 2);
        ctx.rotate(root.angle * Math.PI / 180);
        ctx.translate(-w / 2, -h / 2);

        ctx.beginPath();
        ctx.moveTo(r, 0);
        ctx.lineTo(w - r, 0);
        ctx.bezierCurveTo(w - r + r * k, 0, w, r - r * k, w, r);
        ctx.lineTo(w, sideEnd);
        ctx.bezierCurveTo(w, sideEnd + ry * k, w - rx + rx * k, h, w / 2, h);
        ctx.bezierCurveTo(w / 2 - rx * k, h, 0, sideEnd + ry * k, 0, sideEnd);
        ctx.lineTo(0, r);
        ctx.bezierCurveTo(0, r - r * k, r - r * k, 0, r, 0);
        ctx.closePath();
        ctx.fillStyle = root.fill;
        ctx.fill();
        ctx.restore();
    }
}
