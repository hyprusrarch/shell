import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "themes.js" as ThemeDb

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    focusable: true
    color: "transparent"

    property string greeting: "Good day"
    property string userName: ""

    readonly property var btnModel: [
        { icon: "󰌾", colorType: "accent" },
        { icon: "󰗽", colorType: "info" },
        { icon: "󰜉", colorType: "warning" },
        { icon: "󰐥", colorType: "error" }
    ]

    readonly property var cmds: [
        "hyprlock",
        "loginctl terminate-user $USER",
        "systemctl reboot",
        "systemctl poweroff"
    ]

    function updateGreeting() {
        const h = new Date().getHours();
        if (h >= 5 && h < 12) root.greeting = "Good morning";
        else if (h >= 12 && h < 18) root.greeting = "Good afternoon";
        else if (h >= 18 && h < 22) root.greeting = "Good evening";
        else root.greeting = "Good night";
    }

    Process {
        id: userFetcher
        command: ["sh", "-c", "echo $USER"]
        running: true
        stdout: SplitParser {
            onRead: function(d) {
                const u = d.trim();
                if (u.length > 0) {
                    root.userName = u.charAt(0).toUpperCase() + u.slice(1);
                }
            }
        }
        onRunningChanged: {
            if (!running) userFetcher.command = [];
        }
    }

    Process {
        id: closeWatcher
        running: true
        command: ["tail", "-n", "0", "-F", "/tmp/qs_power_cmd"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

    Rectangle {
        id: bgDimmer
        anchors.fill: parent
        color: "#99000000"
        opacity: 0.0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!outroAnim.running) outroAnim.start();
            }
        }
    }

    Item {
        id: mainBox
        width: 800
        height: 280

        anchors.centerIn: parent

        scale: 0.95
        opacity: 0.0

        layer.enabled: introAnim.running || outroAnim.running

        focus: true
        property int activeIndex: 0

        Keys.onRightPressed: {
            if (activeIndex < 3) activeIndex++;
        }
        Keys.onLeftPressed: {
            if (activeIndex > 0) activeIndex--;
        }
        Keys.onEscapePressed: {
            if (!outroAnim.running) outroAnim.start();
        }
        Keys.onReturnPressed: {
            triggerCommand(activeIndex);
        }

        function triggerCommand(index) {
            if (index >= 0 && index < root.cmds.length) {
                Quickshell.execDetached(["sh", "-c", root.cmds[index]]);
                if (!outroAnim.running) outroAnim.start();
            }
        }

        Component.onCompleted: {
            updateGreeting();
            introAnim.start();
            mainBox.forceActiveFocus();
        }

        ParallelAnimation {
            id: introAnim
            NumberAnimation { target: mainBox; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutQuart }
            NumberAnimation { target: mainBox; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuart }
            NumberAnimation { target: bgDimmer; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuart }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation { target: mainBox; property: "scale"; to: 0.95; duration: 200; easing.type: Easing.InQuart }
            NumberAnimation { target: mainBox; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
            NumberAnimation { target: bgDimmer; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
            onFinished: {
                gc();
                Qt.callLater(Qt.quit);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 25

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 40

                Repeater {
                    model: root.btnModel

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20

                        property bool isActive: mainBox.activeIndex === index || btnArea.containsMouse

                        color: isActive ? Theme.bgDark : Theme.bgMain
                        border.color: isActive ? Theme[modelData.colorType] : Theme.border
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 64
                            color: parent.isActive ? Theme[modelData.colorType] : Theme.textMain
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: mainBox.activeIndex = index
                            onClicked: mainBox.triggerCommand(index)
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.greeting + (root.userName !== "" ? ", " + root.userName : "!")
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 26
                font.bold: true
                color: Theme.textMain
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }
        }
    }
}
