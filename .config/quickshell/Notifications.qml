import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    readonly property color c_bg: (typeof Theme !== 'undefined') ? Theme.bgMain : "#111111"
    readonly property color c_text: (typeof Theme !== 'undefined') ? Theme.textMain : "#ffffff"
    readonly property color c_muted: (typeof Theme !== 'undefined') ? Theme.textMuted : "#aaaaaa"
    readonly property color c_border: (typeof Theme !== 'undefined') ? Theme.border : "#333333"

    implicitWidth: mainLayout.width > 0 ? mainLayout.width + 40 : 0
    implicitHeight: mainLayout.height > 0 ? mainLayout.height + 40 : 0

    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"

    Timer { interval: 30000; running: true; repeat: true; onTriggered: gc() }

    NotificationServer {
        id: notifServer
        onNotification: (notif) => { notif.tracked = true; }
    }

    Process {
        id: closeWatcher
        running: true
        command: ["tail", "-n", "0", "-F", "/tmp/qs_notif_cmd"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE") {
                    const values = notifServer.trackedNotifications.values;
                    for (let i = 0; i < values.length; i++) values[i].dismiss();
                    gc();
                }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        spacing: 12
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 360

        Repeater {
            model: notifServer.trackedNotifications

            delegate: Item {
                id: delegateRoot

                required property QtObject modelData

                Layout.fillWidth: true
                implicitHeight: card.height

                Rectangle {
                    id: card
                    width: parent.width
                    implicitHeight: contentCol.implicitHeight + 24
                    radius: 12

                    color: root.c_bg
                    border.color: modelData.urgency === 2 ? "#ff4444" : root.c_border
                    border.width: 1

                    Component.onCompleted: entryAnim.start()

                    NumberAnimation on x {
                        id: entryAnim
                        from: 400; to: 0
                        duration: 400
                        easing.type: Easing.OutExpo
                    }

                    NumberAnimation on x {
                        id: exitAnim
                        to: 500; duration: 300
                        easing.type: Easing.InBack
                        running: false
                        onFinished: {
                            modelData.dismiss();
                            gc();
                        }
                    }

                    Timer {
                        id: dismissTimer
                        interval: 10000
                        running: true
                        onTriggered: exitAnim.start()
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: dismissTimer.stop()
                        onExited: { if (!replyLoader.active) dismissTimer.restart() }
                        onClicked: { if (!replyLoader.active) exitAnim.start() }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Image {
                                source: Quickshell.iconPath(modelData.appIcon, true)
                                sourceSize: Qt.size(32, 32)
                                visible: modelData.appIcon !== ""
                                Layout.alignment: Qt.AlignTop
                                asynchronous: true
                                cache: false
                                mipmap: false
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.summary
                                    color: root.c_text
                                    font.bold: true; font.pixelSize: 14
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    text: modelData.body
                                    color: root.c_muted
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 15
                                    Layout.fillWidth: true
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 8

                                Text {
                                    text: "󰍡"
                                    font.family: "Symbols Nerd Font"
                                    color: root.c_muted
                                    font.pixelSize: 14
                                    opacity: replyArea.containsMouse ? 1.0 : 0.5
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText

                                    MouseArea {
                                        id: replyArea
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            replyLoader.active = !replyLoader.active;
                                            if (replyLoader.active) dismissTimer.stop();
                                            else dismissTimer.restart();
                                        }
                                    }
                                }

                                Text {
                                    text: "✕"
                                    color: root.c_muted
                                    font.pixelSize: 14
                                    opacity: closeArea.containsMouse ? 1.0 : 0.5
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText

                                    MouseArea {
                                        id: closeArea
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: exitAnim.start()
                                    }
                                }
                            }
                        }

                        Loader {
                            id: replyLoader
                            Layout.fillWidth: true
                            active: false
                            asynchronous: true
                            sourceComponent: Component {
                                Rectangle {
                                    height: 32
                                    color: root.c_bg
                                    border.color: root.c_border
                                    border.width: 1
                                    radius: 6

                                    TextInput {
                                        id: replyInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        color: root.c_text
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 12
                                        focus: true
                                        clip: true
                                        renderType: Text.NativeRendering

                                        onAccepted: {
                                            if (typeof modelData.reply === "function") {
                                                modelData.reply(text);
                                            } else if (typeof modelData.invokeAction === "function") {
                                                modelData.invokeAction("reply", text);
                                            }
                                            exitAnim.start();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
