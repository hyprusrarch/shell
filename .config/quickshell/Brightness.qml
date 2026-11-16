pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Optional brightness control. Poll only while the quick-settings page is visible.
Singleton {
    id: root
    property real value: 0.5
    property bool available: false
    property bool commandMissing: false
    property real pending: -1

    readonly property string icon: value < 0.34 ? "brightness_low" : value < 0.67 ? "brightness_medium" : "brightness_high"

    function set(v) {
        if (!available || commandMissing) return
        value = Math.max(0.01, Math.min(1, v))
        pending = value
    }

    Process {
        id: getProc
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && exec brightnessctl -m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                if (p.length >= 5 && p[3].length > 0) {
                    root.available = true
                    if (root.pending < 0) root.value = Math.max(0, Math.min(1, parseInt(p[3]) / 100))
                }
            }
        }
        stderr: StdioCollector {}
        Component.onCompleted: getProc.running = true
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.available = false
                root.commandMissing = true
            }
        }
    }

    Process {
        id: setProc
        stderr: StdioCollector {}
    }

    Timer {
        interval: 50
        repeat: true
        running: root.available && root.pending >= 0
        onTriggered: {
            if (setProc.running) return
            const percent = Math.round(root.pending * 100) + "%"
            root.pending = -1
            setProc.command = ["brightnessctl", "-q", "set", percent]
            setProc.running = true
        }
    }

    Timer {
        // Slider changes update the value immediately; background device reads can be slower.
        interval: 30000
        repeat: true
        running: Ui.open && Ui.page === 0 && !root.commandMissing
        onTriggered: if (root.pending < 0 && !getProc.running) getProc.running = true
    }

    Connections {
        target: Ui
        function onOpenChanged() {
            if (Ui.open && Ui.page === 0 && root.available && !getProc.running)
                getProc.running = true
        }
        function onPageChanged() {
            if (Ui.open && Ui.page === 0 && root.available && !getProc.running)
                getProc.running = true
        }
    }
}
