import QtQuick
import "../" as Local

// "Copied from" label: the source app's icon and name. Replaces the fixed
// Google "G" + text. With `showName: false` it is just the icon (used as a
// small badge on image tiles).
Row {
    id: root

    property string source: ""
    property bool showName: true
    property real iconSize: 16
    property real maxTextWidth: 170

    readonly property var app: {
        Local.ClipboardSources.revision;           // re-resolve when the app list loads
        return Local.ClipboardSources.resolve(root.source);
    }
    readonly property bool hasIcon: app.icon !== ""
    readonly property bool known: root.source !== ""

    height: 20
    spacing: 6
    visible: showName ? true : hasIcon

    Image {
        visible: root.hasIcon
        width: root.iconSize
        height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        source: root.app.icon
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Local.M3Text {
        visible: root.showName
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.maxTextWidth)
        elide: Text.ElideRight
        text: root.known ? root.app.name : "Clipboard"
        color: root.known ? Local.ClipboardTheme.text : Local.ClipboardTheme.secondaryText
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
