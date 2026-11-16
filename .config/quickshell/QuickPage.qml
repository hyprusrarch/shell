import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page
    spacing: 16
    signal openWifi()

    // Two 193x88 connectivity cards, 18px apart (PDF reference).
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 88
        spacing: 18
        Tile {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            on: !!Wifi.active
            icon: Wifi.active ? Wifi.iconFor(Wifi.active.signalStrength) : "wifi_off"
            label: Wifi.active ? Wifi.active.name : Wifi.enabled ? "Not connected" : "Wi-Fi off"
            onClicked: Wifi.setEnabled(!Wifi.enabled)
            onChevronClicked: page.openWifi()
        }
        Tile {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            on: !!Bt.device
            icon: Bt.device ? "bluetooth" : "bluetooth_disabled"
            label: !Bt.adapter ? "No adapter" : !Bt.enabled ? "Bluetooth off" : Bt.device ? Bt.deviceName : "Not connected"
            onClicked: Bt.toggle()
            onChevronClicked: Quickshell.execDetached(M3.bluetoothSettingsCommand)
        }
    }

    // Slider centers align with the reference's 224px and 275px coordinates.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        Layout.topMargin: 20
        spacing: 11
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Icon { anchors.centerIn: parent; name: Audio.icon; size: 24 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleMute() }
        }
        M3Slider { Layout.fillWidth: true; Layout.preferredHeight: 28; value: Audio.muted ? 0 : Audio.volume; onMoved: v => Audio.setVolume(v) }
    }
    RowLayout {
        visible: Brightness.available
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        Layout.topMargin: 7
        spacing: 11
        Icon { Layout.preferredWidth: 24; Layout.preferredHeight: 24; size: 24; name: Brightness.icon }
        M3Slider { Layout.fillWidth: true; Layout.preferredHeight: 28; value: Brightness.value; onMoved: v => Brightness.set(v) }
    }

    // Notification header aligns with the PDF title and compact DND switch.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            M3Text { text: "Notifications"; font.pixelSize: 22 }
            RowLayout {
                spacing: 5
                M3Text { text: "Do not disturb"; font.pixelSize: 12; color: M3.surfaceVariantText }
                M3Switch { Layout.alignment: Qt.AlignVCenter; Layout.fillWidth: false; Layout.fillHeight: false; unit: 0.55; checked: Notifs.dnd; onToggled: v => Notifs.dnd = v }
            }
        }
        Surface {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignTop
            restRadius: 14
            pressedRadius: 9
            color: M3.secondaryContainer
            content: M3.secondaryContainerText
            onClicked: Notifs.clearAll()
            Accessible.role: Accessible.Button
            Accessible.name: "Clear all notifications"
            Icon { anchors.centerIn: parent; name: "clear_all"; size: 24; color: M3.secondaryContainerText }
        }
    }

    // Bottom 155px is the notification area in the 440x474 reference panel.
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 155

        ColumnLayout {
            visible: Notifs.count === 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -4
            spacing: 19
            Icon { Layout.alignment: Qt.AlignHCenter; name: "chat_bubble_outline"; size: 96; color: M3.surfaceVariantText }
            M3Text { Layout.alignment: Qt.AlignHCenter; text: "No notifications"; color: M3.surfaceVariantText; font.pixelSize: 12 }
        }

        ListView {
            id: notificationList
            visible: Notifs.count > 0
            anchors.fill: parent
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { property: "scale"; to: 0.96; duration: 150; easing.type: Easing.InCubic }
                }
            }
            model: ScriptModel {
                // Keep notification delegates matched by their stable D-Bus id
                // when a new notification arrives at the head of the list.
                values: Notifs.list ? [...Notifs.list.values].reverse() : []
                objectProp: "id"
            }
            reuseItems: true
            delegate: NotifCard {
                required property var modelData
                width: notificationList.width
                notif: modelData
            }
        }
    }
}
