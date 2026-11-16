import QtQuick

// Compact M3 Expressive icon button with a full pointer target and a clear
// accessible action name. Used for actions that do not need a visible label.
Surface {
    id: button

    property string iconName: "close"
    property string accessibleName: "Action"
    property real buttonSize: 36
    property real iconSize: 18
    property color iconColor: M3.surfaceVariantText
    property color containerColor: "transparent"

    implicitWidth: buttonSize
    implicitHeight: buttonSize
    color: hovered ? Qt.alpha(M3.surfaceText, 0.08) : containerColor
    content: M3.surfaceText
    restRadius: buttonSize / 2
    pressedRadius: buttonSize * 0.3
    hoverHighlight: false

    Accessible.role: Accessible.Button
    Accessible.name: button.accessibleName

    Icon {
        anchors.centerIn: parent
        name: button.iconName
        size: button.iconSize
        color: button.iconColor
    }
}
