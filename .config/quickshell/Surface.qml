import QtQuick

// Interactive M3 Expressive container: state layer + shape morph on press (spring driven).
Rectangle {
    id: root
    property color content: M3.surfaceText
    property real restRadius: 20
    property real pressedRadius: 10
    property bool interactive: true
    property alias hovered: hoverHandler.hovered
    property bool hoverHighlight: true
    property alias pressed: ma.pressed
    signal clicked()
    signal rightClicked()

    color: M3.surfaceContainerHigh
    radius: Math.max(0, restRadius + (pressedRadius - restRadius) * morph.value)
    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    SpringValue { id: morph; spring: M3.spatialFast; target: root.interactive && ma.pressed ? 1 : 0 }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.content
        opacity: !root.interactive ? 0 : ma.pressed ? 0.10 : (root.hoverHighlight && hoverHandler.hovered) ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse
    }

    MouseArea {
        id: ma
        z: -1
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => { if (m.button === Qt.RightButton) root.rightClicked(); else root.clicked() }
    }
}
