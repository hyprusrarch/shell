import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Heads-up notifications while the panel is closed (suppressed by DND).
PanelWindow {
    id: win
    // Keep toast cards at their 1.0-DPR physical size when QT_SCALE_FACTOR
    // is set. The transform is vector/text rendered, not a bitmap downscale.
    readonly property real displayCompensation: 1 / Math.max(1, Screen.devicePixelRatio)
    visible: Notifs.toasts.length > 0 && !Ui.open
    anchors { top: true; right: true }
    margins { top: 67; right: 19 }
    implicitWidth: Math.max(1, Math.min(392, (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 408) - 24))
    implicitHeight: Math.max(1, col.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-shell-toasts"
    WlrLayershell.keyboardFocus: Notifs.replyActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: if (visible && Notifs.replyActive) requestActivate()
    mask: Region { item: col }

    Connections {
        target: Notifs
        function onReplyActiveChanged() {
            if (Notifs.replyActive && win.visible) win.requestActivate()
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8
        transform: Scale { origin.x: col.width; origin.y: 0; xScale: win.displayCompensation; yScale: win.displayCompensation }
        Repeater {
            // ScriptModel performs incremental insert/remove operations. A raw
            // JavaScript-array model would destroy and recreate every toast card.
            model: ScriptModel {
                values: Notifs.toasts
                objectProp: "id"
            }
            delegate: NotifCard {
                id: toast
                required property var modelData
                notif: modelData
                Layout.fillWidth: true
                Timer {
                    interval: 6000
                    running: toast.modelData.urgency !== NotificationUrgency.Critical && !toast.hot
                    onTriggered: Notifs.dropToast(toast.modelData)
                }
            }
        }
    }
}
