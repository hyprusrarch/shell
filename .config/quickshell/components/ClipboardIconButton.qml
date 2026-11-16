import QtQuick
import "../" as Local

Local.Surface {
    id: root
    property url iconSource
    property real iconSize: 15
    property color hoverColor: Qt.alpha(Local.ClipboardTheme.text, 0.10)
    property color iconColor: Local.ClipboardTheme.text
    signal activated()

    implicitWidth: 26
    implicitHeight: 26
    restRadius: 13
    pressedRadius: 8
    color: hovered ? root.hoverColor : "transparent"
    hoverHighlight: false
    onClicked: root.activated()

    Image {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
    }
}
