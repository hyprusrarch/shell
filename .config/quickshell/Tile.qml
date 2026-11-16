import QtQuick
import QtQuick.Layouts

// Connectivity tile (Wi-Fi / Bluetooth). Body toggles, chevron opens details.
Surface {
    id: t
    property string icon: ""
    property string label: ""
    property bool on: false
    signal chevronClicked()

    implicitHeight: 88
    restRadius: 24
    pressedRadius: 16
    color: on ? M3.primaryContainer : M3.surfaceContainerHighest
    content: on ? M3.primaryContainerText : M3.surfaceText

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(1, parent.width - 64)
        spacing: 4
        Icon { Layout.alignment: Qt.AlignHCenter; name: t.icon; size: 24; color: t.content }
        M3Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: t.label
            color: t.content
            font.pixelSize: 12
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
    Item {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: parent.height
        Icon { anchors.centerIn: parent; name: "chevron_right"; color: t.content }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: t.chevronClicked()
        }
    }
}
