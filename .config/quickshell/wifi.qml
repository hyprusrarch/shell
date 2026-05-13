import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "themes.js" as ThemeDb

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay

    focusable: true
    color: "transparent"

    property string expandedSsid: ""
    property string fetchedPassword: ""

    property bool isUpdating: false

    property string vpnState: "disconnected"

    Process {
        id: closeWatcher
        running: true
        command: ["tail", "-n", "0", "-F", "/tmp/qs_wifi_cmd"]
        stdout: SplitParser {
            onRead: (data) => {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

    Process {
        id: actionCmd
        command: []
    }

    Timer {
        id: rootInitTimer
        interval: 400
        running: true
        repeat: false
        onTriggered: {
            vpnScanner.running = true;
            scannerLoop.running = true;
        }
    }

    Process {
        id: vpnCmd
        command: []
        onRunningChanged: {
            if (!running) {
                root.WlrLayershell.layer = WlrLayer.Overlay;
                root.focusable = true;
                root.requestActivate();
            }
        }
    }

    Process {
        id: passFetcher
        command: []
        stdout: SplitParser {
            onRead: (data) => {
                const p = data.trim();
                if (p === "") {
                    root.fetchedPassword = "No password saved / Open network";
                } else {
                    root.fetchedPassword = p;
                }
            }
        }
    }

    Process {
        id: vpnScanner
        running: false
        command: [
            "sh",
            "-c",
            "while true; do s=$(warp-cli status 2>&1); if echo \"$s\" | grep -qi 'registration'; then echo 'unregistered'; elif echo \"$s\" | grep -qi 'connected'; then echo 'connected'; else echo 'disconnected'; fi; sleep 4; done"
        ]
        stdout: SplitParser {
            onRead: (data) => {
                const state = data.trim();
                if (state !== "") root.vpnState = state;
            }
        }
    }

    Process {
        id: scannerLoop
        running: false
        command: [
            "sh",
            "-c",
            "while true; do nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi; echo '---'; sleep 8; done"
        ]

        stdout: SplitParser {
            property var tempNetworks: []
            property var uniqueSsids: ({})

            onRead: (data) => {
                if (data.trim() === "---") {
                    root.isUpdating = true;
                    wifiModel.clear();
                    if (tempNetworks.length > 0) {
                        wifiModel.append(tempNetworks);
                    }
                    tempNetworks.length = 0;
                    uniqueSsids = {};

                    Qt.callLater(function() {
                        root.isUpdating = false;
                    });
                } else {
                    const safeStr = data.trim().replace(/\\:/g, "@@@");
                    const parts = safeStr.split(":");

                    if (parts.length >= 4) {
                        const ssid = parts[1].replace(/@@@/g, ":");
                        if (ssid === "" || uniqueSsids[ssid]) return;
                        uniqueSsids[ssid] = true;

                        const inUse = (parts[0] === "*");
                        const sec = parts[2];
                        const sig = parseInt(parts[3]);

                        let sigIcon = "󰤨";
                        if (sig < 30) sigIcon = "󰤯";
                        else if (sig < 50) sigIcon = "󰤟";
                        else if (sig < 80) sigIcon = "󰤢";
                        tempNetworks.push({
                            inUse: inUse,
                            ssid: ssid,
                            isSecure: (sec !== "" && sec !== "--"),
                                          signalIcon: sigIcon
                        });
                    }
                }
            }
        }
    }

    function closeAndPurge() {
        wifiModel.clear();
        gc(); // Added: Instantly frees memory from the Javascript V4 engine
        Qt.callLater(Qt.quit);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { if (!outroAnim.running) outroAnim.start(); }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: { if (!outroAnim.running) outroAnim.start(); }
        }
    }

    Item {
        id: swoopContainer
        width: 310
        height: 350
        x: root.width - width - 125
        y: -height - 15

        Timer {
            id: initTimer
            interval: 20
            running: true
            onTriggered: introAnim.start()
        }

        ParallelAnimation {
            id: introAnim
            NumberAnimation {
                target: swoopContainer;
                property: "y";
                to: 0; duration: 350; easing.type: Easing.OutQuart
            }
            onFinished: {
                listView.forceActiveFocus();
            }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation {
                target: swoopContainer;
                property: "y";
                to: -swoopContainer.height - 160; duration: 250; easing.type: Easing.InQuart
            }
            onFinished: root.closeAndPurge()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(m) { m.accepted = true; }
        }

        Rectangle {
            id: mainBox
            width: 280
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.bgMain
            radius: 12

            Rectangle {
                width: parent.width
                height: 12
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.bgMain
            }

            ListModel { id: wifiModel }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰤨"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: Theme.accent
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Wi-Fi Networks"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textMain
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 6
                        color: refreshArea.containsMouse ? Theme.bgDark : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: Theme.textMain
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent;
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionCmd.command = ["nmcli", "dev", "wifi", "rescan"];
                                actionCmd.running = true;
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: wifiModel
                    cacheBuffer: 0
                    reuseItems: true

                    focus: true
                    Keys.onReturnPressed: toggleCurrent()
                    Keys.onEnterPressed: toggleCurrent()

                    function toggleCurrent() {
                        if (currentIndex >= 0 && currentIndex < wifiModel.count) {
                            const selectedSsid = wifiModel.get(currentIndex).ssid;
                            if (root.expandedSsid === selectedSsid) {
                                root.expandedSsid = "";
                            } else {
                                root.expandedSsid = selectedSsid;
                                root.fetchedPassword = "";
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRect
                        width: listView.width

                        property bool isExpanded: root.expandedSsid === model.ssid
                        property bool isCurrent: ListView.isCurrentItem

                        // Safe property mapping so the lazy Loader doesn't lose access to the data
                        property string netSsid: model.ssid
                        property bool netInUse: model.inUse
                        property bool netIsSecure: model.isSecure
                        property string netSignalIcon: model.signalIcon

                        // Dynamically adjust height
                        height: isExpanded ? 30 + expandedLoader.implicitHeight + 12 : 30

                        radius: 8
                        color: netInUse ? Theme.bgDark : (itemArea.containsMouse || isCurrent ? Theme.bgDark : "transparent")
                        border.color: netInUse ? Theme.accent : (itemArea.containsMouse || isCurrent ? Theme.border : "transparent")
                        border.width: 1

                        Behavior on height {
                            enabled: !root.isUpdating
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
                        }
                        Behavior on color {
                            enabled: !root.isUpdating
                            ColorAnimation { duration: 150 }
                        }
                        Behavior on border.color {
                            enabled: !root.isUpdating
                            ColorAnimation { duration: 150 }
                        }

                        // 1. ALWAYS VISIBLE HEADER (Icon, SSID, Lock)
                        RowLayout {
                            id: headerRow
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            height: 14
                            spacing: 8

                            Text {
                                text: delegateRect.netSignalIcon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: delegateRect.netInUse ? Theme.accent : Theme.textMain
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: delegateRect.netSsid
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.bold: delegateRect.netInUse
                                color: delegateRect.netInUse ? Theme.accent : Theme.textMain
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: ""
                                visible: delegateRect.netIsSecure
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 10
                                color: Theme.textMuted
                                renderType: Text.NativeRendering
                            }
                        }

                        // Click area limited to the top 30px so it doesn't interfere with buttons
                        MouseArea {
                            id: itemArea
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 30
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index;
                                if (root.expandedSsid === delegateRect.netSsid) {
                                    root.expandedSsid = "";
                                } else {
                                    root.expandedSsid = delegateRect.netSsid;
                                    root.fetchedPassword = "";
                                }
                            }
                        }

                        // 2. LAZY LOADED: Expanded Buttons & Inputs
                        Loader {
                            id: expandedLoader
                            anchors.top: headerRow.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            anchors.topMargin: 12

                            active: delegateRect.isExpanded
                            sourceComponent: delegateRect.isExpanded ? expandedComp : undefined
                        }

                        Component {
                            id: expandedComp
                            ColumnLayout {
                                spacing: 6

                                RowLayout {
                                    visible: delegateRect.netInUse
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true; height: 24; radius: 4
                                        color: forgetArea.containsMouse ? Theme.error : Theme.bgMain
                                        border.color: Theme.error; border.width: 1
                                        Text {
                                            anchors.centerIn: parent; text: "Forget"
                                            font.family: "Noto Sans"; font.pixelSize: 10; color: Theme.textMain
                                            renderType: Text.NativeRendering
                                        }
                                        MouseArea {
                                            id: forgetArea
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                actionCmd.command = ["nmcli", "connection", "delete", delegateRect.netSsid];
                                                actionCmd.running = true;
                                                root.expandedSsid = "";
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: 24; radius: 4
                                        color: showPassArea.containsMouse ? Theme.bgDark : Theme.bgMain
                                        border.color: Theme.info; border.width: 1
                                        Text {
                                            anchors.centerIn: parent; text: "Password"
                                            font.family: "Noto Sans"; font.pixelSize: 10; color: Theme.info
                                            renderType: Text.NativeRendering
                                        }
                                        MouseArea {
                                            id: showPassArea
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.fetchedPassword = "Fetching...";
                                                passFetcher.command = [
                                                    "nmcli", "-s", "-g", "802-11-wireless-security.psk",
                                                    "connection", "show", delegateRect.netSsid
                                                ];
                                                passFetcher.running = true;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: delegateRect.netInUse && root.fetchedPassword !== ""
                                    Layout.fillWidth: true
                                    text: "> " + root.fetchedPassword
                                    font.family: "Noto Sans"
                                    font.pixelSize: 10
                                    color: Theme.warning
                                    wrapMode: Text.Wrap
                                    renderType: Text.NativeRendering
                                }

                                RowLayout {
                                    visible: !delegateRect.netInUse
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        visible: delegateRect.netIsSecure
                                        Layout.fillWidth: true; height: 24; radius: 4
                                        color: Theme.bgMain
                                        border.color: Theme.border; border.width: 1

                                        TextInput {
                                            id: passInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 6; anchors.rightMargin: 6
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: "Noto Sans"; font.pixelSize: 10
                                            color: Theme.textMain
                                            echoMode: TextInput.Password
                                            clip: true

                                            Component.onCompleted: {
                                                if (visible) forceActiveFocus();
                                            }

                                            onAccepted: {
                                                actionCmd.command = [
                                                    "nmcli", "dev", "wifi", "connect",
                                                    delegateRect.netSsid, "password", passInput.text
                                                ];
                                                actionCmd.running = true;
                                                root.expandedSsid = "";
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; height: 24; radius: 4
                                        color: connectArea.containsMouse ? Theme.accent : Theme.bgMain
                                        border.color: Theme.accent; border.width: 1
                                        Text {
                                            anchors.centerIn: parent; text: "Connect"
                                            font.family: "Noto Sans"; font.pixelSize: 10;
                                            color: connectArea.containsMouse ? Theme.bgMain : Theme.accent
                                            renderType: Text.NativeRendering
                                        }
                                        MouseArea {
                                            id: connectArea
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (delegateRect.netIsSecure) {
                                                    actionCmd.command = [
                                                        "nmcli", "dev", "wifi", "connect",
                                                        delegateRect.netSsid, "password", passInput.text
                                                    ];
                                                } else {
                                                    actionCmd.command = [
                                                        "nmcli", "dev", "wifi", "connect", delegateRect.netSsid
                                                    ];
                                                }
                                                actionCmd.running = true;
                                                root.expandedSsid = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: vpnRow.implicitWidth + 20
                        height: 26
                        radius: 6
                        color: root.vpnState === "connected" ? Theme.accent : (vpnArea.containsMouse ? Theme.bgDark : "transparent")
                        border.color: root.vpnState === "connected" ? Theme.accent : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: vpnRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.vpnState === "connected" ? "󰒄" : "󰒃"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: root.vpnState === "connected" ? Theme.bgMain : Theme.textMain
                                renderType: Text.NativeRendering
                            }

                            Text {
                                text: root.vpnState === "connected" ? "VPN ON" : (root.vpnState === "unregistered" ? "Register VPN" : "VPN OFF")
                                font.family: "Noto Sans"
                                font.pixelSize: 10
                                font.bold: true
                                color: root.vpnState === "connected" ? Theme.bgMain : Theme.textMain
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: vpnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.focusable = false;
                                root.WlrLayershell.layer = WlrLayer.Bottom;

                                if (root.vpnState === "unregistered") {
                                    vpnCmd.command = ["sh", "-c", "pkexec systemctl start warp-svc.service && sleep 1 && warp-cli --accept-tos register && warp-cli connect"];
                                    vpnCmd.running = true;
                                } else if (root.vpnState === "connected") {
                                    root.vpnState = "disconnected";
                                    vpnCmd.command = ["sh", "-c", "warp-cli disconnect; pkexec systemctl stop warp-svc.service"];
                                    vpnCmd.running = true;
                                } else {
                                    root.vpnState = "connected";
                                    vpnCmd.command = ["sh", "-c", "pkexec systemctl start warp-svc.service && sleep 1 && warp-cli connect"];
                                    vpnCmd.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.top: mainBox.top
            anchors.right: mainBox.left
            width: 15; height: 15; clip: true
            Rectangle {
                width: 60; height: 60; radius: 30
                color: "transparent"
                border.color: Theme.bgMain; border.width: 15
                x: -30; y: -15
            }
        }

        Item {
            anchors.top: mainBox.top
            anchors.left: mainBox.right
            width: 15; height: 15; clip: true
            Rectangle {
                width: 60; height: 60; radius: 30
                color: "transparent"
                border.color: Theme.bgMain; border.width: 15
                x: -15; y: -15
            }
        }
    }
}
