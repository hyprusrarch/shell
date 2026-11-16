import QtQuick

Item {
    id: root
    property real value: 0
    signal moved(real value)

    implicitHeight: 40
    readonly property real thumb: 20
    readonly property real travel: Math.max(1, width - thumb)
    readonly property real thumbX: travel * Math.max(0, Math.min(1, value))

    SpringValue { id: halo; spring: M3.spatialFast; target: ma.pressed ? 1 : 0 }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: M3.secondaryContainer
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.thumbX + root.thumb / 2
        height: 4
        radius: 2
        color: M3.primary
    }
    Rectangle {
        readonly property real d: root.thumb + 36 * Math.max(0, halo.value)
        width: d
        height: d
        radius: d / 2
        x: root.thumbX + root.thumb / 2 - d / 2
        y: (root.height - d) / 2
        color: Qt.alpha(M3.primary, 0.18)
    }
    Rectangle {
        width: root.thumb
        height: root.thumb
        radius: root.thumb / 2
        x: root.thumbX
        y: (root.height - height) / 2
        color: M3.primary
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(x) { root.moved(Math.max(0, Math.min(1, (x - root.thumb / 2) / root.travel))) }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x) }
    }
}
