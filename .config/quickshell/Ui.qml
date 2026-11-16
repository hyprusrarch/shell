pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool open: false
    property int page: 0      // 0 = quick settings + notifications, 1 = Wi-Fi, 2 = clipboard, 3 = launcher

    // True when the Wi-Fi menu was opened from the bar's Wi-Fi button: the panel
    // then drops down under that button (centre x in `wifiAnchorX`) instead of
    // sitting top-right as part of the notification centre.
    property bool wifiFromBar: false
    property real wifiAnchorX: 0

    // Launcher edit mode (long-press): lets Esc / a backdrop click leave edit
    // mode first instead of closing the panel.
    property bool launcherEditing: false

    function openPanel() {
        wifiFromBar = false;
        page = 0;
        open = true;
    }

    // Open the M3 Wi-Fi view directly in this shell process. This avoids an
    // external `qs ipc call` subprocess and cannot target a different instance.
    function openWifi() {
        wifiFromBar = false;
        page = 1;
        open = true;
    }

    function openNotifications() {
        wifiFromBar = false;
        page = 0;
        open = true;
    }

    function openClipboard() {
        wifiFromBar = false;
        page = 2;
        open = true;
    }

    // Wi-Fi button in the bar: open (or close) the menu right under the button.
    function toggleWifiAt(centerX) {
        if (open && page === 1 && wifiFromBar) {
            open = false;
            return;
        }
        wifiFromBar = true;
        wifiAnchorX = centerX;
        page = 1;
        open = true;
    }

    function openLauncher() {
        wifiFromBar = false;
        page = 3;
        open = true;
    }

    function toggleLauncher() {
        if (open && page === 3) open = false;
        else openLauncher();
    }

    function toggleClipboard() {
        if (open && page === 2) open = false;
        else openClipboard();
    }

    function toggle() {
        if (open) open = false;
        else openPanel();
    }
}
