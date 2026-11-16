import QtQuick
import "../" as Local

// Expand / collapse handle. The notch is the practice semicircle (1.6:1 dome,
// cubic-Bezier half-ellipse) from the shell's SemiCircle component; a spring
// morphs it from the resting 1.6:1 dome to a wider, shallower one.
Item {
    id: root
    property bool expanded: false
    property color cutoutColor: Local.ClipboardTheme.panel
    property color arrowColor: Local.ClipboardTheme.text
    signal clicked()

    Local.SpringValue {
        id: morph
        spring: Local.M3.spatialFast
        target: root.expanded ? 1 : 0
    }

    readonly property real m: morph.value
    width: 28 + 16 * m
    height: 17.5 - 1.5 * m        // 28 x 17.5 is exactly 1.6:1

    Local.SemiCircle {
        anchors.fill: parent
        fill: root.cutoutColor
        curveFrac: 0.5 - 0.08 * Math.max(0, Math.min(1, root.m))
        cornerFrac: 0.1
    }

    Canvas {
        id: arrow
        width: 9
        height: 6
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3 + root.m
        rotation: root.expanded ? 180 : 0
        antialiasing: true
        readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
        canvasSize: Qt.size(Math.ceil(width * dpr), Math.ceil(height * dpr))
        onCanvasSizeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(dpr, dpr);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fillStyle = root.arrowColor;
            ctx.fill();
        }
        Behavior on rotation { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        Connections {
            target: root
            function onArrowColorChanged() { arrow.requestPaint(); }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
