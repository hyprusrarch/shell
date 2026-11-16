import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "./launcher" as Launcher

// Launcher entry point. The launcher is split into small files under
// launcher/ (controller, search bar, tab bar, pages, panes, delegates) and
// uses the same container-transform panel style, springs and page
// transitions as the notification centre, Wi-Fi and clipboard.
Item {
    id: launcherRoot

    property int closeRequest: 0
    property bool closeNotified: false

    function notifyClosed() {
        if (launcherRoot.closeNotified) return;
        launcherRoot.closeNotified = true;
        Quickshell.execDetached(["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf \"closed launcher\\n\" >> \"$runtime/quickshell/control\""]);
    }

    // Listens for IPC commands from shell.qml / the bar's toggle button.
    // CLOSE -> every window plays its outro; the shell unloads the launcher afterwards.
    Process {
        running: true
        command: ["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; exec tail -n 0 -F \"$runtime/quickshell/launcher.cmd\""]
        stdout: SplitParser {
            onRead: function (msg) {
                if (msg.trim() === "CLOSE") launcherRoot.closeRequest++;
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property ShellScreen modelData
                screen: modelData

                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                color: "transparent"

                Launcher.LauncherScene {
                    anchors.fill: parent
                    closeRequest: launcherRoot.closeRequest
                    onClosed: launcherRoot.notifyClosed()
                }
            }
        }
    }
}
