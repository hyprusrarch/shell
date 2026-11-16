pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    property bool dnd: false
    property bool replyActive: false
    property var toasts: []
    // One shared minute tick replaces the timer previously created by every card.
    property int minutePulse: 0

    readonly property var list: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length

    function dropToast(n) { toasts = toasts.filter(t => t !== n) }
    // Notification ages only need minute ticks while their page is on screen.
    // This avoids periodic QML work when the panel is closed or the Wi-Fi page is open.
    Timer {
        interval: 60000
        repeat: true
        running: root.count > 0 && Ui.open && Ui.page === 0
        onTriggered: root.minutePulse += 1
    }

    // Refresh age labels when returning to the notifications page after a pause.
    Connections {
        target: Ui
        function onOpenChanged() {
            if (Ui.open) root.toasts = []
            if (root.count > 0 && Ui.open && Ui.page === 0) root.minutePulse += 1
        }
        function onPageChanged() {
            if (root.count > 0 && Ui.open && Ui.page === 0) root.minutePulse += 1
        }
    }

    function clearAll() {
        const all = server.trackedNotifications.values.slice()
        toasts = []
        for (const n of all) n.dismiss()
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        inlineReplySupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            n.closed.connect(() => root.dropToast(n))
            if (!n.lastGeneration && !root.dnd && !Ui.open) root.toasts = [n, ...root.toasts]
        }
    }
}
