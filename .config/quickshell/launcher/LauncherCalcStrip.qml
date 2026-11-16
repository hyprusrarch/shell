import QtQuick
import "../" as Local

// Calculator result strip. Height springs open while there is a result (the
// same container-transform feel as the panels) and keeps the last text while
// it collapses.
Item {
    id: root

    property string result: ""
    signal copyRequested()

    property string shownText: ""
    onResultChanged: if (result !== "") shownText = result

    Local.SpringValue { id: reveal; spring: Local.M3.spatialDefault; target: root.result !== "" ? 1 : 0 }

    implicitHeight: 52 * Math.max(0, reveal.value)
    visible: implicitHeight > 0.5
    clip: true

    Rectangle {
        width: parent.width
        height: 52
        radius: 16
        color: Local.M3.surfaceContainerHigh
        opacity: Math.max(0, Math.min(1, reveal.value * 1.4))

        Local.M3Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            text: root.shownText
            color: Local.M3.primary
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
            width: 64
            height: 26
            radius: 13
            color: Local.M3.surfaceContainerHighest
            Local.M3Text {
                anchors.centerIn: parent
                text: "⏎ copy"
                color: Local.M3.surfaceVariantText
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copyRequested()
        }
    }
}
