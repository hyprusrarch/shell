import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool checked: false
    property real unit: 1
    property color activeTrack: M3.primary
    property color inactiveTrack: M3.surfaceContainerHighest
    property color activeThumb: M3.primaryText
    property color inactiveThumb: M3.outline
    property color inactiveOutline: M3.outline
    signal toggled(bool value)

    readonly property real switchWidth: 52 * unit
    readonly property real switchHeight: 32 * unit

    // Keep the switch at its design size in layouts. The visual track is also
    // centered below, so it remains correctly placed if a parent assigns a
    // larger allocation than the component's implicit size.
    implicitWidth: switchWidth
    implicitHeight: switchHeight
    Layout.fillWidth: false
    Layout.fillHeight: false
    Layout.minimumWidth: switchWidth
    Layout.maximumWidth: switchWidth
    Layout.preferredWidth: switchWidth
    Layout.minimumHeight: switchHeight
    Layout.maximumHeight: switchHeight
    Layout.preferredHeight: switchHeight

    SpringValue { id: pos; spring: M3.spatialFast; target: root.checked ? 1 : 0 }
    SpringValue { id: grow; spring: M3.spatialFast; target: ma.pressed ? 1 : 0 }

    Rectangle {
        id: track
        width: root.switchWidth
        height: root.switchHeight
        anchors.centerIn: parent
        radius: height / 2
        color: root.checked ? root.activeTrack : root.inactiveTrack
        border.width: root.checked ? 0 : 2 * root.unit
        border.color: root.inactiveOutline
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Rectangle {
        readonly property real d: Math.max(0, (16 + 8 * pos.value + 4 * grow.value) * root.unit)
        width: d
        height: d
        radius: d / 2
        y: track.y + (track.height - d) / 2
        x: track.x + (16 + 20 * pos.value) * root.unit - d / 2
        color: root.checked ? root.activeThumb : root.inactiveThumb
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
