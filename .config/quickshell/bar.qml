import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Item {
    id: shell
    property var targetScreen: null

    function execUI(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    SystemClock { id: mainClock; precision: SystemClock.Minutes }


    PanelWindow {
        id: tooltipWindow
        screen: shell.targetScreen
        visible: root.activeHoverItem !== null

        property real targetCenterX: root.activeHoverItem ? root.activeHoverItem.mapToItem(null, 0, 0).x + root.activeHoverItem.width / 2 : 0
        property real calculatedX: Math.max(12, Math.min(root.width - width - 12, targetCenterX - width / 2))

        anchors.top: true; anchors.left: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        margins.top: root.height + 5; margins.left: calculatedX
        color: "transparent"

        width: ttRect.width; height: ttRect.height

        Rectangle {
            id: ttRect
            width: ttText.implicitWidth + 29; height: ttText.implicitHeight + 19
            color: Theme.bgMain; radius: 5; border.color: Theme.border; border.width: 1

            Text {
                id: ttText
                anchors.centerIn: parent
                color: Theme.textMain
                font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                textFormat: Text.StyledText; renderType: Text.NativeRendering

                text: root.hoverId === "cpu" ? root.cpuCoreDetails :
                root.hoverId === "ram" ? root.ramTooltip :
                root.hoverId === "net" ? root.wifiTooltip :
                root.hoverId === "bat" ? root.batTooltip :
                root.hoverId === "notif" ? root.notifTooltip :
                root.hoverId === "power" ? `Right-click: Auto-sleep (${root.autoSleepEnabled ? "ON" : "OFF"})` :
                root.hoverId === "clip" ? "Clipboard History" : ""
            }
        }
    }

    Loader {
        id: globalTrayMenuLoader
        active: false
        asynchronous: true
        property var currentMenuHandle: null

        Connections {
            target: globalTrayMenuLoader.item

            ignoreUnknownSignals: true
            function onCloseRequested() {
                globalTrayMenuLoader.active = false;
                globalTrayMenuLoader.currentMenuHandle = null;
            }
        }
    }

    PanelWindow {
        id: root
        screen: shell.targetScreen
        anchors.top: true; anchors.left: true; anchors.right: true
        implicitHeight: 38
        WlrLayershell.layer: WlrLayer.Top
        color: Theme.bgMain

        property Item activeHoverItem: null
        property string hoverId: ""

        property string cpuUsage: SystemStatus.cpuUsage
        property string cpuCoreDetails: SystemStatus.cpuCoreDetails
        property string memUsage: SystemStatus.memUsage
        property string ramTooltip: SystemStatus.ramTooltip

        property string wifiDisplay: Wifi.active ? `󰤨 ${Wifi.active.name}` : (!Wifi.stateKnown ? "󰤨 Checking…" : (Wifi.enabled ? "󰤮 Not connected" : "󰤮 Offline"))
        property string wifiTooltip: Wifi.active ? `<b>Connected:</b> ${Wifi.active.name}<br>Click to manage Wi-Fi` : (Wifi.enabled ? "Wi-Fi is enabled but not connected" : "Wi-Fi is disabled")
        property bool isDND: Notifs.dnd
        property bool autoSleepEnabled: SystemStatus.autoSleepEnabled

        property string batPct: SystemStatus.batPct
        property string batIcon: SystemStatus.batIcon
        property string batTooltip: SystemStatus.batTooltip
        property color batColor: parseInt(SystemStatus.batPct) < 15 ? Theme.error : (parseInt(SystemStatus.batPct) < 30 ? Theme.warning : Theme.info)

        property int notifCount: Notifs.count
        property string notifTooltip: `<b>Notifications</b><br>${root.isDND ? "Do Not Disturb is ON" : "You have " + root.notifCount + " active notifications."}`

        property int volPct: Math.round(Audio.volume * 100)
        property bool overAmp: Audio.volume > 1.0
        property int focusedWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0

        function showLiveTooltip(item, idString) {
            if (idString === "ram") SystemStatus.refreshGpu();
            root.hoverId = idString;
            root.activeHoverItem = item;
        }
        function hideTooltip() { root.activeHoverItem = null; root.hoverId = ""; }



        Item {
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 14

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 17
                Text {
                    text: ""; color: Theme.accent
                    font.family: "Symbols Nerd Font"; font.pixelSize: 19
                    renderType: Text.NativeRendering; textFormat: Text.PlainText

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                        onClicked: shell.execUI("~/.config/quickshell/scripts/launcher.sh")
                    }
                }
                Row {
                    spacing: 10; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            readonly property bool isActive: root.focusedWsId === (index + 1)
                            width: isActive ? 29 : 10; height: 10; radius: 5
                            color: isActive ? Theme.accent : Theme.textMuted
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: shell.execUI(`hyprctl dispatch workspace ${index + 1}`)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                color: Theme.textMain; font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                renderType: Text.NativeRendering; textFormat: Text.PlainText
                text: Qt.formatDateTime(mainClock.date, "ddd dd MMM HH:mm")
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shell.execUI("~/.config/quickshell/scripts/toggle_dash.sh")
                }
            }

            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 24

                Text {
                    id: cpuM; text: `󰍛 ${root.cpuUsage}%`; color: Theme.warning
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(cpuM, "cpu")
                        onExited:  root.hideTooltip()
                    }
                }

                Text {
                    id: ramM; text: `󰍛 ${root.memUsage}`; color: Theme.success
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(ramM, "ram")
                        onExited: root.hideTooltip()
                    }
                }

                Text {
                    id: netM; text: root.wifiDisplay; color: Theme.info
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(netM, "net")
                        onExited:  root.hideTooltip()
                        onClicked: Ui.toggleWifiAt(netM.mapToItem(null, netM.width / 2, 0).x)
                    }
                }

                Row {
                    id: volM; spacing: 7
                    property var audio: Audio.audio
                    property bool showSlider: false
                    property bool _ignoreVolChange: false

                    function _resetIgnoreVol() { volM._ignoreVolChange = false; }
                    function setVolume(newVol) {
                        if (!volM.audio || volM._ignoreVolChange) return;
                        volM._ignoreVolChange = true;
                        Audio.setVolume(newVol);
                        Qt.callLater(volM._resetIgnoreVol);
                    }
                    function handleScroll(w) {
                        if (!volM.audio) return;
                        setVolume(Math.max(0, volM.audio.volume + (w.angleDelta.y > 0 ? 0.02 : -0.02)));
                    }

                    Timer { id: volTimer; interval: 800; onTriggered: volM.showSlider = false }

                    Text {
                        color: Theme.warning; font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 17
                        renderType: Text.NativeRendering; textFormat: Text.PlainText
                        text: (!volM.audio || volM.audio.muted) ? "󰖁" : (volM.audio.volume < 0.33 ? "󰕿" : "󰕾")
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onEntered: { volTimer.stop(); volM.showSlider = true; }
                            onExited:  { if (!pressed) volTimer.restart(); }
                            onWheel:   (w) => { volM.handleScroll(w); }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) Audio.toggleMute();
                            }
                        }
                    }

                    Loader {
                        width: volM.showSlider ? 84 : 0; height: 17
                        opacity: volM.showSlider ? 1.0 : 0.0
                        clip: true; asynchronous: true
                        active: volM.showSlider || width > 0
                        sourceComponent: volSliderComp
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    Text {
                        text: `${root.volPct}%`; color: root.overAmp ? Theme.error : Theme.warning
                        font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                        renderType: Text.NativeRendering; textFormat: Text.PlainText
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onEntered: { volTimer.stop(); volM.showSlider = true; }
                            onExited:  { if (!pressed) volTimer.restart(); }
                            onWheel: (w) => { volM.handleScroll(w); }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) shell.execUI("~/.config/quickshell/scripts/media.sh");
                            }
                        }
                    }
                }

                Text {
                    id: batDisp; text: `${root.batIcon} ${root.batPct}%`; color: root.batColor
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(batDisp, "bat")
                        onExited:  root.hideTooltip()
                    }
                }

                Text {
                    id: clipBtn; text: "󰅌"; color: Theme.textMain
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 17
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(clipBtn, "clip")
                        onExited: root.hideTooltip()
                        onClicked: shell.execUI("~/.config/quickshell/scripts/clipboard.sh")
                    }
                }

                RowLayout {
                    spacing: 14
                    visible: SystemTray.items.values.length !== 0
                    Repeater {
                        model: SystemTray.items
                        delegate: Image {
                            id: trayIcon
                            Layout.preferredWidth: 19; Layout.preferredHeight: 19
                            required property var modelData
                            source: modelData.icon; sourceSize: Qt.size(19, 19)
                            asynchronous: true; smooth: false; mipmap: false; cache: false
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                function toggleMenu() {
                                    if (globalTrayMenuLoader.active && globalTrayMenuLoader.currentMenuHandle === modelData.menu) {
                                        if (globalTrayMenuLoader.item) globalTrayMenuLoader.item.closeMenu();
                                    } else {
                                        let iconGlobalX = trayIcon.mapToItem(null, 0, 0).x;
                                        globalTrayMenuLoader.currentMenuHandle = modelData.menu;
                                        globalTrayMenuLoader.setSource("TrayMenu.qml", {
                                            "menuHandle": modelData.menu,
                                            "anchorX": iconGlobalX,
                                            "anchorY": 32
                                        });
                                        globalTrayMenuLoader.active = true;
                                    }
                                }
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) { if (modelData.onlyMenu) toggleMenu(); else modelData.activate(); }
                                    else if (mouse.button === Qt.RightButton) { if (modelData.hasMenu) toggleMenu(); else modelData.activate(); }
                                    else if (mouse.button === Qt.MiddleButton) { modelData.secondaryActivate(); }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: notifM; text: root.isDND ? "󰂛" : (root.notifCount > 0 ? `󰂚 ${root.notifCount}` : "󰂜")
                    color: root.isDND ? Theme.textMuted : (root.notifCount > 0 ? Theme.error : Theme.accentAlt)
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 17
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.showLiveTooltip(notifM, "notif")
                        onExited: root.hideTooltip()
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) Ui.openNotifications();
                            else if (mouse.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd;
                        }
                    }
                }

                Text {
                    id: powerBtn; text: ""; color: root.autoSleepEnabled ? Theme.accent : Theme.textMuted
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 18
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.showLiveTooltip(powerBtn, "power")
                        onExited: root.hideTooltip()
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) shell.execUI("~/.config/quickshell/scripts/powerdrop.sh");
                            else if (mouse.button === Qt.RightButton) {
                                SystemStatus.toggleIdle();
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: volSliderComp
        Item {
            Rectangle {
                width: 72; height: 5; radius: 2; color: Theme.border; anchors.centerIn: parent
                Rectangle {
                    width: volM.audio ? Math.min(parent.width, volM.audio.volume * parent.width) : 0
                    height: parent.height; radius: 2; color: Theme.warning
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                onEntered:         { volTimer.stop(); volM.showSlider = true; }
                onExited:          { if (!pressed) volTimer.restart(); }
                onWheel:           (w) => { volM.handleScroll(w); }
                onPositionChanged: (m) => { if (pressed && volM.audio) volM.setVolume(Math.max(0, m.x / width)); }
                onClicked:         (m) => { if (volM.audio) volM.setVolume(Math.max(0, m.x / width)); }
            }
        }
    }
}
