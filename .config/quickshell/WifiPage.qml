import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page
    spacing: 4
    property bool menuVisible: false
    property string expandedName: ""
    signal back()

    onMenuVisibleChanged: Wifi.setMenuOpen(menuVisible)

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 10
        Surface {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 32
            restRadius: 16
            pressedRadius: 8
            color: "transparent"
            hoverHighlight: false
            onClicked: page.back()
            Icon { anchors.centerIn: parent; name: "arrow_back"; size: 24 }
        }
        M3Text { Layout.fillWidth: true; text: "Wi-Fi"; font.pixelSize: 22 }
        M3IconButton {
            Layout.alignment: Qt.AlignVCenter
            buttonSize: 32
            iconName: "refresh"
            accessibleName: "Scan for Wi-Fi networks"
            enabled: Wifi.enabled && !Wifi.scanning
            onClicked: Wifi.refresh(true)
        }
        M3Switch { Layout.alignment: Qt.AlignVCenter; Layout.fillWidth: false; Layout.fillHeight: false; unit: 0.55; checked: Wifi.enabled; onToggled: v => Wifi.setEnabled(v) }
    }

    Repeater {
        model: Wifi.active ? [Wifi.active] : []
        delegate: WifiRow {
            required property var modelData
            net: modelData
            hero: true
            Layout.fillWidth: true
            expanded: page.expandedName === modelData.name
            onToggle: page.expandedName = expanded ? "" : modelData.name
        }
    }
    Surface {
        visible: Wifi.enabled && !Wifi.active
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        interactive: false
        restRadius: M3.shapeXl
        color: M3.surfaceContainerHighest
        RowLayout {
            anchors { fill: parent; leftMargin: 16 }
            spacing: 12
            Icon { name: "wifi_off" }
            M3Text { text: "Not connected" }
        }
    }

    M3Text {
        visible: Wifi.errorMessage.length > 0
        Layout.fillWidth: true
        color: M3.errorContainerText
        wrapMode: Text.Wrap
        text: Wifi.errorMessage
    }
    M3Text {
        visible: Wifi.enabled && Wifi.scanning
        Layout.fillWidth: true
        text: "Scanning for networks…"
        color: M3.surfaceVariantText
    }
    M3Text {
        visible: Wifi.enabled && !Wifi.scanning && Wifi.errorMessage.length === 0 && networkModel.values.length === 0
        Layout.fillWidth: true
        text: "No networks found. Reopen Wi-Fi to scan again."
        color: M3.surfaceVariantText
    }

    M3Text {
        visible: Wifi.enabled
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.preferredHeight: 20
        text: "Available networks"
        font.pixelSize: 16
        font.weight: Font.Medium
    }

    ListView {
        id: networkList
        visible: Wifi.enabled
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: 140
        Layout.topMargin: 5
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            id: networkModel
            values: Wifi.networks ? Wifi.networks.filter(n => !n.connected) : []
        }
        delegate: WifiRow {
            required property var modelData
            width: networkList.width
            net: modelData
            expanded: page.expandedName === modelData.name
            onToggle: page.expandedName = expanded ? "" : modelData.name
        }
    }

    M3Button {
        Layout.fillWidth: true
        Layout.topMargin: 5
        text: "Wi-Fi settings"
        onClicked: Quickshell.execDetached(M3.wifiSettingsCommand)
    }
}
