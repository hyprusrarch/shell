import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Non-visual owner for the M3 windows and IPC endpoint. ShellRoot is not a
// visual item, so these objects are exposed as explicit properties rather
// than relying on an Item root's parent geometry.
QtObject {
    id: root

    property var panelWindow: PanelWindow {
        id: panelWindow
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        anchors { top: true; right: true; bottom: true; left: true }
        visible: Ui.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "m3-full-shell-panel"
        WlrLayershell.keyboardFocus: Ui.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: scene }
        onVisibleChanged: if (visible) requestActivate()

        Item {
            id: scene
            anchors.fill: parent
            visible: Ui.open
            focus: Ui.open
            Keys.onEscapePressed: {
                if (Ui.page === 3 && Ui.launcherEditing) Ui.launcherEditing = false;
                else if (Ui.page === 1 && !Ui.wifiFromBar) Ui.page = 0;
                else Ui.open = false;
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (Ui.page === 3 && Ui.launcherEditing) Ui.launcherEditing = false;
                    else Ui.open = false;
                }
            }
            Panel {
                z: 1
                id: mainPanel
                availableWidth: Math.max(1, scene.width - 29)
                y: 48
                // Right edge pinned 14px from the screen edge on every page, so
                // the Wi-Fi menu always sits in the same place and the left edge
                // slides with the animated width when switching pages (as in
                // the original transition). Launcher: top-left, growing out of
                // the left corner.
                x: Ui.page === 3 ? 14 : scene.width - width - 14
                originFrac: Ui.page === 3 ? 0 : 1
            }
        }
    }

    // The notification server and toast host exist once for the full shell.
    property var toastHost: Toasts { }

    property var ipc: IpcHandler {
        target: "m3-panel"
        function toggle(): void { Ui.toggle(); }
        function openNotifications(): void { Ui.openNotifications(); }
        function openWifi(): void { Ui.openWifi(); }
        function toggleClipboard(): void { Ui.toggleClipboard(); }
        function toggleLauncher(): void { Ui.toggleLauncher(); }
        function close(): void { Ui.open = false; }
    }
}
