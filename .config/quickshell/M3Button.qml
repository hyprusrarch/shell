import QtQuick

Surface {
    id: btn
    property string text: ""
    property string iconName: ""
    property color fill: M3.secondaryContainer
    property color labelColor: M3.secondaryContainerText

    implicitHeight: 40
    implicitWidth: label.implicitWidth + 32 + (iconName.length > 0 ? 26 : 0)
    color: fill
    content: labelColor
    restRadius: implicitHeight / 2
    pressedRadius: 12

    Row {
        anchors.centerIn: parent
        spacing: btn.iconName.length > 0 ? 8 : 0
        Icon {
            visible: btn.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: btn.iconName
            size: 18
            color: btn.labelColor
        }
        M3Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.labelColor
            font.weight: Font.Medium
        }
    }
}
