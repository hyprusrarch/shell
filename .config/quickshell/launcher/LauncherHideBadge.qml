import QtQuick
import "../" as Local
import "." as Parts

// Small red "x" shown on items in edit mode. Springs in and out.
Item {
    id: root
    property bool shown: false
    signal clicked()

    width: 22
    height: 22
    z: 20
    scale: root.shown ? 1 : 0
    opacity: root.shown ? 1 : 0
    visible: scale > 0.01
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Local.Theme.error
    }
    Parts.LauncherGlyph {
        anchors.centerIn: parent
        kind: "close"
        size: 10
        color: Local.M3.surface
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
