import QtQuick

// Font-independent Material-style icon set used by the Wi-Fi, Bluetooth,
// audio, brightness, notification and settings controls in this shell.
// Canvas repaints only when the icon name, size or color changes.
// PDF icon states swap immediately: do not animate/crossfade source geometry.
Item {
    id: root
    property string name: ""
    property real size: 24
    property color color: M3.surfaceText

    implicitWidth: size
    implicitHeight: size

    readonly property var pdfAssets: ({
        wifi_off: "wifi_off.png",
        wifi_1_bar: "wifi_1_bar.png",
        network_wifi_1_bar: "wifi_1_bar.png",
        wifi_2_bar: "wifi_2_bar.png",
        network_wifi_2_bar: "wifi_2_bar.png",
        wifi: "wifi_3_bars.png",
        network_wifi: "wifi_3_bars.png",
        wifi_open: "wifi_3_bars.png",
        wifi_filled: "wifi_filled.png",
        bluetooth: "bluetooth.png",
        bluetooth_disabled: "bluetooth_disabled.png",
        brightness_low: "brightness_low.png",
        brightness_medium: "brightness_medium.png",
        brightness_high: "brightness_high.png",
        volume_off: "volume_off.png",
        volume_mute: "volume_mute.png",
        volume_down: "volume_down.png",
        volume_up: "volume_up.png",
        chat_bubble_outline: "chat_bubble_outline.png",
        visibility: "visibility.png",
        visibility_off: "visibility_off.png",
        clear_all: "history_clear.png",
        history_clear: "history_clear.png"
    })
    readonly property string pdfAsset: pdfAssets[name] || ""
    readonly property bool preservePdfColors: name === "clear_all" || name === "history_clear"
    readonly property string pdfUrl: pdfAsset.length > 0
        ? Qt.resolvedUrl("assets/pdf-icons-png/" + pdfAsset) : ""

    Canvas {
        id: canvas
        anchors.fill: parent
        // Canvas raster compositing works with Qt Quick's software backend too.
        // Avoid MultiEffect here: shader-based tinting can disappear with
        // QT_QUICK_BACKEND=software, especially when disk caching is disabled.
        antialiasing: true

        Component.onCompleted: {
            if (root.pdfUrl.length > 0) loadImage(root.pdfUrl);
            requestPaint();
        }

        onImageLoaded: requestPaint()

        onPaint: {
            const c = getContext("2d");
            c.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0) return;

            // Draw the original PDF-derived raster when available. Tint monochrome
            // artwork with source-in compositing, preserving the icon's alpha edges.
            // Multi-colour artwork (the clear/history illustration) is drawn untouched.
            if (root.pdfUrl.length > 0 && isImageLoaded(root.pdfUrl)) {
                c.save();
                c.drawImage(root.pdfUrl, 0, 0, width, height);
                if (!root.preservePdfColors) {
                    c.globalCompositeOperation = "source-in";
                    c.fillStyle = root.color;
                    c.fillRect(0, 0, width, height);
                }
                c.restore();
                return;
            }

            // If a supplied asset is missing or fails to load, use the vector fallback.
            c.save();
            c.scale(width / 24, height / 24);
            c.strokeStyle = root.color;
            c.fillStyle = root.color;
            c.lineWidth = 2;
            c.lineCap = "round";
            c.lineJoin = "round";

            function line(points) {
                c.beginPath();
                c.moveTo(points[0][0], points[0][1]);
                for (let i = 1; i < points.length; ++i)
                    c.lineTo(points[i][0], points[i][1]);
                c.stroke();
            }
            function circle(x, y, r, fill) {
                c.beginPath();
                c.arc(x, y, r, 0, Math.PI * 2);
                if (fill) c.fill(); else c.stroke();
            }
            function slash() { line([[4, 20], [20, 4]]); }
            function wifi(levels, disabled, openCenter) {
                for (let i = 1; i <= levels; ++i) {
                    c.beginPath();
                    c.arc(12, 19, 4 + i * 3.2, Math.PI * 1.25, Math.PI * 1.75);
                    c.stroke();
                }
                circle(12, 19, 1.5, !openCenter);
                if (disabled) slash();
            }
            function bluetooth(disabled) {
                line([[12, 3], [18, 8], [12, 12], [18, 16], [12, 21], [12, 3]]);
                line([[6, 7], [17, 17]]);
                line([[6, 17], [17, 7]]);
                if (disabled) slash();
            }
            function speaker(mode) {
                c.beginPath();
                c.moveTo(3, 9); c.lineTo(7, 9); c.lineTo(12, 5);
                c.lineTo(12, 19); c.lineTo(7, 15); c.lineTo(3, 15);
                c.closePath(); c.fill();
                if (mode === "up" || mode === "down") {
                    c.beginPath(); c.moveTo(15, 9);
                    c.quadraticCurveTo(mode === "up" ? 20 : 18, 12, 15, 15);
                    c.stroke();
                }
                if (mode === "up") {
                    c.beginPath(); c.moveTo(17, 6);
                    c.quadraticCurveTo(23, 12, 17, 18); c.stroke();
                }
                if (mode === "mute") line([[16, 9], [21, 15], [16, 15], [21, 9]]);
                if (mode === "off") slash();
            }
            function bell(off, active) {
                c.beginPath();
                c.moveTo(5, 17); c.lineTo(7, 15); c.lineTo(7, 10);
                c.quadraticCurveTo(7, 5, 12, 5);
                c.quadraticCurveTo(17, 5, 17, 10);
                c.lineTo(17, 15); c.lineTo(19, 17); c.closePath(); c.stroke();
                c.beginPath(); c.arc(12, 19, 1.5, 0, Math.PI * 2); c.fill();
                if (active) circle(19, 5, 2, true);
                if (off) slash();
            }
            function gear(centerMode) {
                circle(12, 12, 4, false);
                for (let i = 0; i < 8; ++i) {
                    const a = i * Math.PI / 4;
                    line([
                        [12 + Math.cos(a) * 6, 12 + Math.sin(a) * 6],
                        [12 + Math.cos(a) * 9, 12 + Math.sin(a) * 9]
                    ]);
                }
                if (centerMode === "brightness") {
                    circle(12, 12, 1.5, true);
                    for (let i = 0; i < 8; ++i) {
                        const a = i * Math.PI / 4;
                        line([
                            [12 + Math.cos(a) * 1.8, 12 + Math.sin(a) * 1.8],
                            [12 + Math.cos(a) * 2.8, 12 + Math.sin(a) * 2.8]
                        ]);
                    }
                } else if (centerMode === "suggest") {
                    line([[12, 8.5], [12, 15.5]]);
                    line([[8.5, 12], [15.5, 12]]);
                }
            }
            function closeX() { line([[6, 6], [18, 18]]); line([[18, 6], [6, 18]]); }
            function visibility(hidden) {
                c.beginPath();
                c.moveTo(2, 12);
                c.quadraticCurveTo(6, 5, 12, 5);
                c.quadraticCurveTo(18, 5, 22, 12);
                c.quadraticCurveTo(18, 19, 12, 19);
                c.quadraticCurveTo(6, 19, 2, 12);
                c.stroke();
                circle(12, 12, 3, false);
                if (hidden) slash();
            }

            switch (root.name) {
            case "wifi":
            case "network_wifi": wifi(3, false, false); break;
            case "wifi_2_bar":
            case "network_wifi_2_bar": wifi(2, false, false); break;
            case "wifi_1_bar":
            case "network_wifi_1_bar": wifi(1, false, false); break;
            case "wifi_open": wifi(3, false, true); break;
            case "wifi_lock":
            case "wifi_locked":
                wifi(3, false, false);
                c.beginPath(); c.moveTo(15, 13); c.arc(17.5, 13, 2, Math.PI, 0); c.stroke();
                c.beginPath(); c.moveTo(14, 13); c.lineTo(21, 13); c.lineTo(21, 19);
                c.lineTo(14, 19); c.closePath(); c.stroke();
                break;
            case "wifi_off": wifi(3, true, false); break;
            case "bluetooth": bluetooth(false); break;
            case "bluetooth_connected": bluetooth(false); circle(19, 18, 2, true); break;
            case "bluetooth_disabled": bluetooth(true); break;
            case "volume_up": speaker("up"); break;
            case "volume_down": speaker("down"); break;
            case "volume_mute": speaker("mute"); break;
            case "volume_off": speaker("off"); break;
            case "notifications": bell(false, false); break;
            case "notifications_active": bell(false, true); break;
            case "notifications_off": bell(true, false); break;
            case "notifications_paused":
                bell(false, false);
                line([[10, 9], [10, 14]]); line([[14, 9], [14, 14]]);
                break;
            case "do_not_disturb":
            case "do_not_disturb_on": circle(12, 12, 9, false); line([[7, 12], [17, 12]]); break;
            case "brightness_low":
            case "brightness_medium":
            case "brightness_high": {
                const rays = root.name === "brightness_low" ? 4 : root.name === "brightness_medium" ? 6 : 8;
                circle(12, 12, root.name === "brightness_low" ? 3 : 4, root.name === "brightness_medium");
                for (let i = 0; i < rays; ++i) {
                    const a = i * Math.PI * 2 / rays;
                    line([[12 + Math.cos(a) * 7, 12 + Math.sin(a) * 7],
                          [12 + Math.cos(a) * 10, 12 + Math.sin(a) * 10]]);
                }
                break;
            }
            case "settings": gear(""); break;
            case "settings_brightness": gear("brightness"); break;
            case "settings_suggest": gear("suggest"); break;
            case "tune":
                line([[4, 6], [20, 6]]); line([[4, 12], [20, 12]]); line([[4, 18], [20, 18]]);
                circle(9, 6, 2, true); circle(15, 12, 2, true); circle(11, 18, 2, true);
                break;
            case "chevron_right": line([[9, 5], [16, 12], [9, 19]]); break;
            case "chevron_left": line([[15, 5], [8, 12], [15, 19]]); break;
            case "arrow_back": line([[19, 12], [5, 12], [11, 6]]); line([[5, 12], [11, 18]]); break;
            case "arrow_forward": line([[5, 12], [19, 12], [13, 6]]); line([[19, 12], [13, 18]]); break;
            case "clear_all":
                line([[4, 6], [16, 6]]); line([[4, 11], [13, 11]]); line([[4, 16], [11, 16]]);
                closeX();
                break;
            case "close":
            case "cancel": closeX(); break;
            case "remove_circle_outline": circle(12, 12, 9, false); line([[7, 12], [17, 12]]); break;
            case "history":
                c.beginPath(); c.arc(12, 12, 8, 0, Math.PI * 2); c.stroke();
                line([[12, 7], [12, 12], [16, 14]]);
                line([[4, 5], [4, 10], [9, 10]]);
                break;
            case "chat_bubble_outline":
                c.beginPath(); c.moveTo(5, 4); c.lineTo(19, 4);
                c.quadraticCurveTo(21, 4, 21, 6); c.lineTo(21, 15);
                c.quadraticCurveTo(21, 17, 19, 17); c.lineTo(10, 17);
                c.lineTo(5, 21); c.lineTo(6, 17); c.lineTo(5, 17);
                c.quadraticCurveTo(3, 17, 3, 15); c.lineTo(3, 6);
                c.quadraticCurveTo(3, 4, 5, 4); c.stroke();
                break;
            case "speaker_notes_off":
                c.beginPath(); c.moveTo(4, 5); c.lineTo(20, 5); c.lineTo(20, 17);
                c.lineTo(10, 17); c.lineTo(6, 20); c.lineTo(6, 17); c.lineTo(4, 17);
                c.closePath(); c.stroke();
                line([[8, 9], [16, 9]]); line([[8, 13], [13, 13]]); slash();
                break;
            case "visibility": visibility(false); break;
            case "visibility_off": visibility(true); break;
            case "send":
                c.beginPath(); c.moveTo(3, 4); c.lineTo(22, 12); c.lineTo(3, 20);
                c.lineTo(7, 12); c.closePath(); c.stroke(); line([[7, 12], [22, 12]]);
                break;
            case "reply":
                c.beginPath(); c.moveTo(10, 5); c.lineTo(3, 12); c.lineTo(10, 19); c.stroke();
                line([[4, 12], [13, 12]]);
                c.beginPath(); c.moveTo(13, 8); c.quadraticCurveTo(21, 8, 21, 17); c.stroke();
                break;
            default:
                circle(12, 12, 8, false);
                line([[9, 9], [11, 7], [14, 8], [14, 10], [12, 12], [12, 14]]);
                circle(12, 17, 0.7, true);
                break;
            }
            c.restore();
        }
    }

    onPdfUrlChanged: {
        if (pdfUrl.length > 0) canvas.loadImage(pdfUrl);
        canvas.requestPaint();
    }
    onNameChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
}
