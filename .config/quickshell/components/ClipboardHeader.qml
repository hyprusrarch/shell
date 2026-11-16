import QtQuick
import QtQuick.Layouts
import "../" as Local

RowLayout {
    id: root
    property bool clipboardOn: true
    property bool feedback: false
    signal toggleRequested(bool value)
    signal removeAllRequested()
    spacing: 8

    Local.M3Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: "Clipboard"
        color: root.feedback ? Local.ClipboardTheme.accent : Local.ClipboardTheme.text
        font.pixelSize: 22
        font.weight: Font.Medium
    }

    // Same 28px Material 3 clear-all affordance used by the notification header.
    Local.M3IconButton {
        Layout.alignment: Qt.AlignVCenter
        buttonSize: 28
        iconSize: 24
        iconName: "clear_all"
        accessibleName: "Remove all clipboard items"
        iconColor: Local.ClipboardTheme.text
        containerColor: Local.ClipboardTheme.selected
        onClicked: root.removeAllRequested()
    }

    Local.M3Switch {
        Layout.alignment: Qt.AlignVCenter
        Layout.rightMargin: 5
        unit: 0.55
        checked: root.clipboardOn
        activeTrack: Local.ClipboardTheme.accent
        inactiveTrack: Local.ClipboardTheme.selected
        activeThumb: Local.ClipboardTheme.accentThumb
        inactiveThumb: Local.ClipboardTheme.secondaryText
        inactiveOutline: Local.ClipboardTheme.secondaryText
        onToggled: value => root.toggleRequested(value)
    }
}
