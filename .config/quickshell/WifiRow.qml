import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// One network "pill". Collapsed: icon / name / Secured|Open. Expanded (spring):
//   unknown + PSK   -> password field with eye toggle
//   known/connected -> [Connect] Show password / Forget
Item {
    id: row
    required property var net
    property bool hero: false          // the purple "connected" card
    property bool expanded: false
    signal toggle()

    readonly property string securityText: String(net.security || "").toUpperCase()
    readonly property bool isOpen: securityText.length === 0 || securityText === "--"
    readonly property bool enterprise: securityText.indexOf("802.1X") >= 0 || securityText.indexOf("EAP") >= 0
    readonly property bool needsPsk: !isOpen && !enterprise && (securityText.indexOf("WPA") >= 0 || securityText.indexOf("WEP") >= 0 || securityText.indexOf("SAE") >= 0)
    readonly property bool manage: !!net.connected || !!net.known
    readonly property real bodyH: bodyCol.implicitHeight + 28

    property string psk: ""
    property bool pskShown: false
    property bool typedVisible: false

    implicitHeight: card.height
    height: implicitHeight
    // One hover scope for the full row. It stays on the outer item while the
    // card grows, so entering through the header cannot create a partial state.
    readonly property bool hovered: wholeRowHover.hovered

    HoverHandler {
        id: wholeRowHover
        acceptedDevices: PointerDevice.Mouse
        target: null
    }

    function headerClicked() {
        if (manage) { toggle(); return }
        if (isOpen) { Wifi.connect(net.name, "", net.bssid); return }
        toggle()
    }
    function submit() {
        if (pw.text.length === 0) return
        Wifi.connect(net.name, pw.text, net.bssid)
        pw.text = ""
        toggle()
    }
    function togglePsk() {
        if (pskShown) { pskShown = false; psk = "" }
        else pskProc.running = true
    }
    onExpandedChanged: if (!expanded) { pskShown = false; psk = ""; pw.text = ""; typedVisible = false }

    Process {
        id: pskProc
        command: ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "id", row.net.profileName || row.net.name]
        stdout: StdioCollector {
            onStreamFinished: { row.psk = text.trim(); row.pskShown = true }
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) { row.psk = "No saved password"; row.pskShown = true }
        }
    }

    SpringValue { id: ex; spring: M3.spatialDefault; target: row.expanded ? 1 : 0 }

    Rectangle {
        id: card
        width: row.width
        height: header.height + row.bodyH * Math.max(0, ex.value)
        radius: row.hero ? 22 : 23
        color: row.hero
            ? (row.hovered ? Qt.tint(M3.primaryContainer, Qt.alpha(M3.primaryContainerText, 0.08)) : M3.primaryContainer)
            : row.hovered ? M3.surfaceContainerHighest : M3.surfaceContainerHigh
        clip: true
        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Surface {
            id: header
            width: parent.width
            height: row.hero ? (row.expanded ? 56 : 88) : 46
            color: "transparent"
            hoverHighlight: false
            content: row.hero ? M3.primaryContainerText : M3.surfaceText
            restRadius: card.radius
            pressedRadius: 14
            onClicked: row.headerClicked()

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 12
                Icon { name: row.isOpen ? "wifi_open" : Wifi.iconFor(row.net.signalStrength); color: header.content }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    M3Text {
                        Layout.fillWidth: true
                        text: row.net.name
                        color: header.content
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    M3Text {
                        visible: row.hero
                        text: row.net.stateChanging || Wifi.connectingSsid === row.net.name ? "Connecting…" : "Connected"
                        color: header.content
                        font.pixelSize: 12
                    }
                }
                M3Text {
                    visible: !row.hero
                    text: row.net.stateChanging || Wifi.connectingSsid === row.net.name ? "Connecting…" : row.isOpen ? "Open" : row.enterprise ? "Enterprise" : "Secured"
                    color: M3.surfaceVariantText
                    font.pixelSize: 12
                }
                Icon { visible: row.hero; name: "chevron_right"; color: header.content }
            }
        }

        Item {
            y: header.height
            width: parent.width
            height: row.bodyH
            opacity: Math.min(1, Math.max(0, ex.value))
            enabled: row.expanded

            ColumnLayout {
                id: bodyCol
                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                // — password entry (unknown secured network) —
                M3Text { visible: !row.manage && row.needsPsk; text: "Password"; color: M3.surfaceVariantText; font.pixelSize: 12 }
                M3Text {
                    visible: !row.manage && row.enterprise
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: "This enterprise network requires additional authentication. Open Wi-Fi settings to connect."
                    color: M3.surfaceVariantText
                    font.pixelSize: 12
                }
                M3Button {
                    visible: !row.manage && row.enterprise
                    Layout.fillWidth: true
                    text: "Open Wi-Fi settings"
                    iconName: "settings"
                    onClicked: Quickshell.execDetached(M3.wifiSettingsCommand)
                }
                Rectangle {
                    visible: !row.manage && row.needsPsk
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: M3.surfaceContainerHighest
                    TextInput {
                        id: pw
                        anchors { left: parent.left; right: eye.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                        echoMode: row.typedVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: M3.surfaceText
                        font.family: M3.font
                        font.pixelSize: 14
                        clip: true
                        selectByMouse: true
                        onAccepted: row.submit()
                    }
                    Item {
                        id: eye
                        anchors.right: parent.right
                        width: 44
                        height: parent.height
                        Icon { anchors.centerIn: parent; size: 20; color: M3.surfaceVariantText; name: row.typedVisible ? "visibility_off" : "visibility" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.typedVisible = !row.typedVisible }
                    }
                }

                // — known / connected network actions —
                RowLayout {
                    visible: row.manage
                    Layout.fillWidth: true
                    spacing: 8
                    M3Button {
                        visible: !row.net.connected
                        Layout.fillWidth: true
                        text: "Connect"
                        fill: M3.primary
                        labelColor: M3.primaryText
                        onClicked: Wifi.connect(row.net.name, "", row.net.bssid)
                    }
                    M3Button {
                        Layout.fillWidth: true
                        text: row.pskShown ? "Hide password" : "Show password"
                        fill: row.hero ? M3.primary : M3.secondaryContainer
                        labelColor: row.hero ? M3.primaryText : M3.secondaryContainerText
                        onClicked: row.togglePsk()
                    }
                    M3Button {
                        Layout.fillWidth: true
                        text: "Forget"
                        fill: row.hero ? Qt.alpha(M3.primaryContainerText, 0.16) : M3.errorContainer
                        labelColor: row.hero ? M3.primaryContainerText : M3.errorContainerText
                        onClicked: { Wifi.forget(row.net.profileName || row.net.name); row.toggle() }
                    }
                }
                TextEdit {
                    visible: row.manage && row.pskShown
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    readOnly: true
                    selectByMouse: true
                    text: row.psk.length ? row.psk : "No saved password"
                    color: row.hero ? M3.primaryContainerText : M3.surfaceText
                    font.family: M3.font
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                }
            }
        }
    }
}
