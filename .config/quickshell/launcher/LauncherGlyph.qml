import QtQuick
import "../" as Local

// Font-independent glyphs for the launcher (search, grid, list, close), drawn
// on a hi-dpi Canvas so they stay crisp and don't depend on an icon font.
Canvas {
    id: root

    property string kind: "search"        // search | grid | list | close
    property color color: Local.M3.surfaceText
    property real size: 18

    readonly property real dpr: Math.max(1, Screen.devicePixelRatio)

    width: size
    height: size
    antialiasing: true
    canvasSize: Qt.size(Math.ceil(width * dpr), Math.ceil(height * dpr))

    onCanvasSizeChanged: requestPaint()
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()

    function rrect(ctx, x, y, w, h, r) {
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
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.scale(dpr, dpr);
        const s = root.size;
        ctx.fillStyle = root.color;
        ctx.strokeStyle = root.color;
        ctx.lineCap = "round";
        ctx.lineWidth = Math.max(1.6, s * 0.11);

        if (root.kind === "search") {
            ctx.beginPath();
            ctx.arc(s * 0.43, s * 0.43, s * 0.27, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(s * 0.64, s * 0.64);
            ctx.lineTo(s * 0.86, s * 0.86);
            ctx.stroke();
        } else if (root.kind === "grid") {
            const c = s * 0.36, a = s * 0.1, b = s * 0.54, r = s * 0.1;
            root.rrect(ctx, a, a, c, c, r); ctx.fill();
            root.rrect(ctx, b, a, c, c, r); ctx.fill();
            root.rrect(ctx, a, b, c, c, r); ctx.fill();
            root.rrect(ctx, b, b, c, c, r); ctx.fill();
        } else if (root.kind === "list") {
            const h = s * 0.16, x = s * 0.1, w = s * 0.8;
            root.rrect(ctx, x, s * 0.14, w, h, h / 2); ctx.fill();
            root.rrect(ctx, x, s * 0.42, w, h, h / 2); ctx.fill();
            root.rrect(ctx, x, s * 0.70, w, h, h / 2); ctx.fill();
        } else if (root.kind === "close") {
            ctx.beginPath();
            ctx.moveTo(s * 0.24, s * 0.24); ctx.lineTo(s * 0.76, s * 0.76);
            ctx.moveTo(s * 0.76, s * 0.24); ctx.lineTo(s * 0.24, s * 0.76);
            ctx.stroke();
        }
    }
}
