//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: shell

    function execUI(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    SystemClock { id: mainClock; precision: SystemClock.Minutes }

    Timer {
        interval: 100; running: true; repeat: false
        onTriggered: {
            sysFetcher.running    = true;
            netFetcher.running    = true;
            dndSub.running        = true;
            hypridleCheck.running = true;
        }
    }

    Process {
        id: hypridleCheck
        running: false
        command: ["sh", "-c", "pgrep -x hypridle > /dev/null && echo on || echo off"]
        stdout: SplitParser { onRead: (d) => { root.autoSleepEnabled = (d.trim() === "on"); } }
    }

    PanelWindow {
        id: tooltipWindow
        visible: root.activeHoverItem !== null

        property real targetCenterX: root.activeHoverItem ? root.activeHoverItem.mapToItem(null, 0, 0).x + root.activeHoverItem.width / 2 : 0
        property real calculatedX: Math.max(10, Math.min(root.width - width - 10, targetCenterX - width / 2))

        anchors.top: true; anchors.left: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        margins.top: root.height + 4; margins.left: calculatedX
        color: "transparent"

        width: ttRect.width; height: ttRect.height

        Rectangle {
            id: ttRect
            width: ttText.implicitWidth + 24; height: ttText.implicitHeight + 16
            color: Theme.bgMain; radius: 4; border.color: Theme.border; border.width: 1

            Text {
                id: ttText
                anchors.centerIn: parent
                color: Theme.textMain
                font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
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
        anchors.top: true; anchors.left: true; anchors.right: true
        implicitHeight: 32
        WlrLayershell.layer: WlrLayer.Top
        color: Theme.bgMain

        property Item activeHoverItem: null
        property string hoverId: ""

        property string cpuUsage: "0"
        property string cpuCoreDetails: "Loading..."
        property string memUsage: "0.0G"
        property string ramTooltip: "Calculating..."

        property string wifiDisplay: "󰤨 Loading..."
        property string wifiTooltip: ""
        property bool isDND: false
        property bool autoSleepEnabled: true

        property string batPct: "100"
        property string batIcon: "󰁹"
        property string batTooltip: "Calculating..."
        property color batColor: Theme.info

        property QtObject sink: Pipewire.defaultAudioSink

        property QtObject _audio: root.sink ? root.sink.audio : null

        property int notifCount: NotificationServer.trackedNotifications ? NotificationServer.trackedNotifications.count : 0
        property string notifTooltip: `<b>Notifications</b><br>${root.isDND ? "Do Not Disturb is ON" : "You have " + root.notifCount + " active notifications."}`

        property int volPct: Math.round((root._audio ? root._audio.volume : 0) * 100)
        property bool overAmp: root._audio ? root._audio.volume > 1.0 : false
        property int focusedWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0

        function showLiveTooltip(item, idString) {
            root.hoverId = idString;
            root.activeHoverItem = item;
        }
        function hideTooltip() { root.activeHoverItem = null; root.hoverId = ""; }

        PwObjectTracker { objects: [ root.sink, root._audio ] }

        Process {
            id: sysFetcher; running: false
            command: ["bash", "-c", "trap 'exit 0' TERM; amd_u=$(find /sys/class/drm -name mem_info_vram_used 2>/dev/null | head -1); amd_t=$(find /sys/class/drm -name mem_info_vram_total 2>/dev/null | head -1); if [ -n \"$amd_u\" ]; then gpt=amd; elif command -v nvidia-smi &>/dev/null; then gpt=nv; else gpt=no; fi; tp=; for p in /sys/class/thermal/thermal_zone*/temp; do [ -f \"$p\" ] || continue; t=$(< \"${p%temp}type\") 2>/dev/null; case $t in x86_pkg_temp|cpu-thermal|coretemp) tp=$p; break;; esac; done; declare -A lt li; bat_p=\"/sys/class/power_supply/BAT0\"; while true; do  cores=\"\"; while read -r line; do [[ $line != cpu* ]] && break; arr=($line); id=${arr[0]}; idle=${arr[4]}; total=0; for x in \"${arr[@]:1}\"; do total=$((total + x)); done; dt=$((total - ${lt[$id]:-0})); di=$((idle - ${li[$id]:-0})); lt[$id]=$total; li[$id]=$idle; [ $dt -le 0 ] && u=0 || u=$(( 100 * (dt - di) / dt )); [ \"$id\" = \"cpu\" ] && cpu_main=$u || cores+=\"Core ${id#cpu}: ${u}%<br>\"; done < /proc/stat;  while read -r l v u; do case \"$l\" in MemTotal:) t=$v ;; MemAvailable:) a=$v ;; esac; done < /proc/meminfo; um=$(( (t - a) / 1024 )); [ $um -gt 1024 ] && mem=\"$((um/1024)).$(( (um%1024)*10/1024 ))G\" || mem=\"${um}M\"; case $gpt in amd) ug=$(( $(< \"$amd_u\") / 1048576 )); tg=$(( $(< \"$amd_t\") / 1048576 )); gpu=\"AMD: ${ug}/${tg} MiB\";; nv) nv=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,nounits,noheader 2>/dev/null); [ -n \"$nv\" ] && gpu=\"NVIDIA: ${nv%,*} / ${nv#*,} MiB\" || gpu=\"NVIDIA: N/A\";; *) gpu=\"No GPU\";; esac;  [ -n \"$tp\" ] && temp=\"$(( $(< \"$tp\") / 1000 ))°C\" || temp=\"N/A\"; if [ -d \"$bat_p\" ]; then pct=$(cat \"$bat_p/capacity\"); st=$(cat \"$bat_p/status\"); if [ \"$st\" = \"Charging\" ]; then icon=\"󰂄\"; elif [ \"$pct\" -ge 90 ]; then icon=\"󰁹\"; elif [ \"$pct\" -ge 65 ]; then icon=\"󰂁\"; elif [ \"$pct\" -ge 40 ]; then icon=\"󰁽\"; elif [ \"$pct\" -ge 15 ]; then icon=\"󰁻\"; else icon=\"󰁺\"; fi; else pct=100; icon=\"󰁹\"; st=\"Unknown\"; fi;  echo \"$cpu_main|$mem|$gpu|$cores|$temp|$pct|$icon|$st\"; sleep 5; done"]
            stdout: SplitParser {
                onRead: (d) => {
                    const p = d.trim().split('|');
                    if (p.length >= 8) {
                        root.cpuUsage = p[0]; root.memUsage = p[1];
                        root.cpuCoreDetails = `<b>Per-Core Usage</b><br>${p[3]}<b>Temp:</b> ${p[4]}`;
                        root.ramTooltip = `<b>Memory Usage</b><br>System: ${p[1]}<br>${p[2]}`;
                        root.batPct = p[5]; root.batIcon = p[6];
                        root.batTooltip = `<b>Battery: ${p[5]}%</b><br>Status: ${p[7]}`;
                        root.batColor = parseInt(p[5]) < 15 ? Theme.error : (parseInt(p[5]) < 30 ? Theme.warning : Theme.info);
                    }
                }
            }
        }

        Process {
            id: netFetcher; running: false
            command: ["bash", "-c", "trap 'exit 0' TERM; old_r=0; old_t=0; dev=; ssid=; ipad=; cnt=0; while true; do  if [ $((cnt % 10)) -eq 0 ]; then active=$(nmcli -t -f active,device,ssid dev wifi 2>/dev/null | grep '^yes:' | head -1); if [ -z \"$active\" ]; then dev=; ssid=; ipad=; else dev=$(echo \"$active\" | cut -d: -f2); ssid=$(echo \"$active\" | awk -F: '{for(i=3;i<=NF;i++) printf \"%s%s\",$i,(i<NF?\":\":\"\")}'); ipad=$(ip -4 -br addr show \"$dev\" 2>/dev/null | (read -r _ _ addr _; echo \"${addr%/*}\")); fi; fi; if [ -z \"$dev\" ]; then net_out=\"offline|0|0|N/A\"; else curr_r=$(< /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null || echo 0); curr_t=$(< /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null || echo 0); [ $old_r -gt 0 ] && down=$(( (curr_r - old_r) / 1024 )) || down=0; [ $old_t -gt 0 ] && up=$(( (curr_t - old_t) / 1024 )) || up=0; old_r=$curr_r; old_t=$curr_t; net_out=\"$ssid|$down|$up|${ipad:-N/A}\"; fi; echo \"$net_out\"; cnt=$((cnt+1)); sleep 5; done"]
            stdout: SplitParser {
                onRead: (d) => {
                    const p = d.trim().split('|');
                    if (p.length >= 4) {
                        if (p[0] === "offline") { root.wifiDisplay = "󰤮 Offline"; root.wifiTooltip = "No active connection"; }
                        else {
                            const dl = parseInt(p[1]), ul = parseInt(p[2]);
                            const ds = dl > 1024 ? (dl/1024).toFixed(1) + "MB/s" : dl + "KB/s";
                            const us = ul > 1024 ? (ul/1024).toFixed(1) + "MB/s" : ul + "KB/s";
                            root.wifiDisplay = `󰤨 ${p[0]}`;
                            root.wifiTooltip = `<b>IP: ${p[3]}</b><br>󰇚 Down: ${ds}<br>󰕒 Up: ${us}`;
                        }
                    }
                }
            }
        }

        Process {
            id: dndSub; running: false
            command: ["bash", "-c", "trap 'exit 0' TERM; swaync-client -D; swaync-client -swb 2>/dev/null | while IFS= read -r l; do case $l in *'\"dnd\":true'*) echo true;; *'\"dnd\":false'*) echo false;; esac; done"]
            stdout: SplitParser { onRead: (d) => { root.isDND = (d.trim() === "true"); } }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                Text {
                    text: ""; color: Theme.accent
                    font.family: "Symbols Nerd Font"; font.pixelSize: 16
                    renderType: Text.NativeRendering; textFormat: Text.PlainText

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                        onClicked: shell.execUI("~/.config/quickshell/scripts/launcher.sh")
                    }
                }
                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            readonly property bool isActive: root.focusedWsId === (index + 1)
                            width: isActive ? 24 : 8; height: 8; radius: 4
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
                color: Theme.textMain; font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
                renderType: Text.NativeRendering; textFormat: Text.PlainText
                text: Qt.formatDateTime(mainClock.date, "ddd dd MMM HH:mm")
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shell.execUI("~/.config/quickshell/scripts/toggle_dash.sh")
                }
            }

            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 20

                Text {
                    id: cpuM; text: `󰍛 ${root.cpuUsage}%`; color: Theme.warning
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(cpuM, "cpu")
                        onExited:  root.hideTooltip()
                    }
                }

                Text {
                    id: ramM; text: `󰍛 ${root.memUsage}`; color: Theme.success
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(ramM, "ram")
                        onExited: root.hideTooltip()
                    }
                }

                Text {
                    id: netM; text: root.wifiDisplay; color: Theme.info
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(netM, "net")
                        onExited:  root.hideTooltip()
                        onClicked: shell.execUI("~/.config/quickshell/scripts/wifi.sh")
                    }
                }

                Row {
                    id: volM; spacing: 6
                    property QtObject audio: root._audio
                    property bool showSlider: false
                    property bool _ignoreVolChange: false

                    function _resetIgnoreVol() { volM._ignoreVolChange = false; }
                    function setVolume(newVol) {
                        if (!volM.audio || volM._ignoreVolChange) return;
                        volM._ignoreVolChange = true;
                        volM.audio.volume = newVol;
                        Qt.callLater(volM._resetIgnoreVol);
                    }
                    function handleScroll(w) {
                        setVolume(Math.max(0, volM.audio.volume + (w.angleDelta.y > 0 ? 0.02 : -0.02)));
                    }

                    Timer { id: volTimer; interval: 800; onTriggered: volM.showSlider = false }

                    Text {
                        color: Theme.warning; font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                        renderType: Text.NativeRendering; textFormat: Text.PlainText
                        text: (!volM.audio || volM.audio.muted) ? "󰖁" : (volM.audio.volume < 0.33 ? "󰕿" : "󰕾")
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onEntered: { volTimer.stop(); volM.showSlider = true; }
                            onExited:  { if (!pressed) volTimer.restart(); }
                            onWheel:   (w) => { volM.handleScroll(w); }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) { if (volM.audio) volM.audio.muted = !volM.audio.muted; }
                            }
                        }
                    }

                    Loader {
                        width: volM.showSlider ? 70 : 0; height: 14
                        opacity: volM.showSlider ? 1.0 : 0.0
                        clip: true; asynchronous: true
                        active: volM.showSlider || width > 0
                        sourceComponent: volSliderComp
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    Text {
                        text: `${root.volPct}%`; color: root.overAmp ? Theme.error : Theme.warning
                        font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
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
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 12
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(batDisp, "bat")
                        onExited:  root.hideTooltip()
                    }
                }

                Text {
                    id: clipBtn; text: "󰅌"; color: Theme.textMain
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onEntered: root.showLiveTooltip(clipBtn, "clip")
                        onExited: root.hideTooltip()
                        onClicked: shell.execUI("~/.config/quickshell/scripts/clipboard.sh")
                    }
                }

                RowLayout {
                    spacing: 12
                    visible: SystemTray.items.values.length !== 0
                    Repeater {
                        model: SystemTray.items
                        delegate: Image {
                            id: trayIcon
                            Layout.preferredWidth: 16; Layout.preferredHeight: 16
                            required property var modelData
                            source: modelData.icon; sourceSize: Qt.size(16, 16)
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
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 14
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.showLiveTooltip(notifM, "notif")
                        onExited: root.hideTooltip()
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) shell.execUI("swaync-client -t -sw");
                            else if (mouse.button === Qt.RightButton) { shell.execUI("swaync-client -d"); root.isDND = !root.isDND; }
                        }
                    }
                }

                Text {
                    id: powerBtn; text: ""; color: root.autoSleepEnabled ? Theme.accent : Theme.textMuted
                    font.family: "CaskaydiaCove Nerd Font"; font.pixelSize: 15
                    renderType: Text.NativeRendering; textFormat: Text.PlainText
                    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: root.showLiveTooltip(powerBtn, "power")
                        onExited: root.hideTooltip()
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) shell.execUI("~/.config/quickshell/scripts/powerdrop.sh");
                            else if (mouse.button === Qt.RightButton) {
                                if (root.autoSleepEnabled) Quickshell.execDetached(["pkill", "-x", "hypridle"]);
                                else Quickshell.execDetached(["hypridle"]);
                                root.autoSleepEnabled = !root.autoSleepEnabled;
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
                width: 60; height: 4; radius: 2; color: Theme.border; anchors.centerIn: parent
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
