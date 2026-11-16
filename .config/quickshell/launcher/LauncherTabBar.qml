import QtQuick
import "../" as Local

// Pill tab bar (same construction as the clipboard's): equal segments and a
// pill indicator whose position is the pages' spring value, so it follows a
// swipe and settles with the same spring as the page slide.
Item {
    id: root

    required property var controller
    property real position: 0
    signal tabSelected(int index)

    readonly property int count: controller.tabList.length
    implicitHeight: 40

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Local.M3.surfaceContainerHigh
        clip: true

        Rectangle {
            x: Math.max(0, Math.min(root.count - 1, root.position)) * (track.width / root.count)
            width: track.width / root.count
            height: track.height
            radius: height / 2
            color: Local.M3.surfaceContainerHighest
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: root.controller.tabLabels
                delegate: Item {
                    id: tab
                    required property int index
                    required property string modelData
                    width: track.width / root.count
                    height: track.height
                    readonly property bool selected: root.controller.activeTabIndex === index
                    opacity: (root.controller.editMode && !selected) ? 0.35 : 1
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: height / 2
                        color: hover.containsMouse && !tab.selected ? Qt.alpha(Local.M3.surfaceText, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Local.M3Text {
                        anchors.centerIn: parent
                        text: tab.modelData
                        color: tab.selected ? Local.M3.primary : Local.M3.surfaceVariantText
                        font.pixelSize: 13
                        font.weight: tab.selected ? Font.Medium : Font.Normal
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.controller.editMode || tab.selected
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tabSelected(tab.index)
                    }
                }
            }
        }
    }
}
