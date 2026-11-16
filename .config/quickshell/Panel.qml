import QtQuick

// Container-transform style panel: one surface whose size springs between pages.
Item {
    id: panel
    property real availableWidth: 440
    // Where the open/close scale grows from, as a fraction of the width
    // (1 = top-right corner, as in the notification centre).
    property real originFrac: 1
    // Compensate for QT_SCALE_FACTOR at the final scene-graph transform.
    // Text and vector icons are re-rasterized at the target size; no bitmap
    // assets are resized or substituted. At DPR 1.0 this is exactly 1.0.
    readonly property real displayCompensation: 1 / Math.max(1, Screen.devicePixelRatio)
    // Build the Wi-Fi page only on first entry, then keep it cached so returning
    // to it does not repeat QML construction or interrupt its page transition.
    property bool wifiPageVisited: Ui.page === 1
    property bool clipboardPageVisited: Ui.page === 2
    property bool launcherPageVisited: Ui.page === 3
    property bool resident: true

    Timer {
        id: evictTimer
        interval: 45000
        onTriggered: {
            panel.resident = false;
            panel.wifiPageVisited = false;
            panel.clipboardPageVisited = false;
            panel.launcherPageVisited = false;
        }
    }

    Connections {
        target: Ui
        function onOpenChanged() {
            if (!Ui.open) {
                evictTimer.restart();
                return;
            }
            evictTimer.stop();
            panel.resident = true;
            // Opening from closed: the page slide and width springs still hold
            // the previous session's values (e.g. Wi-Fi last time, notifications
            // now) and would otherwise play that transition as the panel
            // appears. Start every open already on the requested page.
            // (Switching pages while the panel is open still animates.)
            pageP.value = pageP.target;
            pageP.velocity = 0;
            wSpring.value = wSpring.target;
            wSpring.velocity = 0;
        }
        function onPageChanged() {
            if (Ui.page === 1) panel.wifiPageVisited = true
            if (Ui.page === 2) panel.clipboardPageVisited = true
            if (Ui.page === 3) panel.launcherPageVisited = true
        }
    }
    width: Math.max(1, wSpring.value)
    height: Math.max(96, hSpring.value)
    opacity: Math.max(0, Math.min(1, openP.value * 1.6))
    enabled: Ui.open
    transform: Scale {
        origin.x: panel.width * panel.originFrac
        origin.y: 0
        xScale: (0.9 + 0.1 * openP.value) * panel.displayCompensation
        yScale: (0.9 + 0.1 * openP.value) * panel.displayCompensation
    }

    SpringValue { id: openP; spring: M3.spatialDefault; target: Ui.open ? 1 : 0 }
    SpringValue { id: pageP; spring: M3.spatialDefault; target: Ui.page }
    SpringValue {
        id: wSpring
        spring: M3.spatialDefault
        target: Math.min(Ui.page === 0 ? 440 : Ui.page === 3 ? 768 : 352, panel.availableWidth)
    }
    SpringValue {
        id: hSpring
        spring: M3.spatialDefault
        target: Ui.open ? (Ui.page === 3 ? 518 : 474) : 96
    }

    MouseArea { anchors.fill: parent }   // swallow clicks so the backdrop doesn't close us

    Rectangle {
        anchors.fill: parent
        radius: M3.shapeLgInc
        color: M3.surfaceContainer
    }

    Item {
        anchors.fill: parent
        clip: true

        QuickPage {
            id: quick
            x: 18 - 48 * pageP.value
            y: 18
            width: panel.width - 36
            height: panel.height - 36
            opacity: Math.max(0, Math.min(1, 1 - Math.abs(pageP.value) * 1.4))
            enabled: Ui.page === 0
            onOpenWifi: Ui.page = 1
        }
        Loader {
            id: wifiPageLoader
            active: panel.resident && (panel.wifiPageVisited || Ui.page === 1)
            asynchronous: true
            x: 18 - 48 * (pageP.value - 1)
            y: 18
            width: panel.width - 36
            height: panel.height - 36
            opacity: Math.max(0, Math.min(1, 1 - Math.abs(pageP.value - 1) * 1.4))
            visible: opacity > 0.001
            enabled: Ui.page === 1
            sourceComponent: Component {
                WifiPage {
                    menuVisible: Ui.open && Ui.page === 1
                    onBack: { if (Ui.wifiFromBar) Ui.open = false; else Ui.page = 0; }
                }
            }
        }
        Loader {
            id: clipboardPageLoader
            active: panel.resident && (panel.clipboardPageVisited || Ui.page === 2)
            asynchronous: true
            x: 18 - 48 * (pageP.value - 2)
            y: 18
            width: panel.width - 36
            height: panel.height - 36
            opacity: Math.max(0, Math.min(1, 1 - Math.abs(pageP.value - 2) * 1.4))
            visible: opacity > 0.001
            enabled: Ui.page === 2
            sourceComponent: Component {
                ClipboardPage {
                    menuVisible: Ui.open && Ui.page === 2
                }
            }
        }
        Loader {
            id: launcherPageLoader
            active: panel.resident && (panel.launcherPageVisited || Ui.page === 3)
            asynchronous: true
            x: 18 - 48 * (pageP.value - 3)
            y: 18
            width: panel.width - 36
            height: panel.height - 36
            opacity: Math.max(0, Math.min(1, 1 - Math.abs(pageP.value - 3) * 1.4))
            visible: opacity > 0.001
            enabled: Ui.page === 3
            sourceComponent: Component {
                LauncherPage {
                    menuVisible: Ui.open && Ui.page === 3
                }
            }
        }
    }
}
