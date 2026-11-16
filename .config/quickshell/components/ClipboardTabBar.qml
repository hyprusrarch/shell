import QtQuick
import QtQuick.Layouts
import "../" as Local

Item {
    id: root
    property int currentIndex: 0
    signal tabSelected(int index)

    Local.SpringValue {
        id: selectedPosition
        spring: Local.M3.spatialDefault
        target: root.currentIndex
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Local.ClipboardTheme.content
        clip: true

        Rectangle {
            x: selectedPosition.value * (track.width / 3)
            y: 0
            width: track.width / 3
            height: track.height
            radius: height / 2          // always a pill, on every tab
            color: Local.ClipboardTheme.selected
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: ["Text", "Images", "Favorites"]
                delegate: Item {
                    required property int index
                    required property string modelData
                    width: track.width / 3
                    height: track.height
                    readonly property bool selected: root.currentIndex === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: height / 2
                        color: tabHover.containsMouse && !selected ? Qt.alpha(Local.ClipboardTheme.text, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Local.M3Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: selected ? Local.ClipboardTheme.text : Local.ClipboardTheme.secondaryText
                        font.pixelSize: 12
                        font.weight: selected ? Font.Medium : Font.Normal
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: tabHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tabSelected(index)
                    }
                }
            }
        }

        Rectangle {
            x: track.width / 3 - 0.5
            y: 1
            width: 1
            height: track.height - 2
            color: Local.ClipboardTheme.panel
            opacity: 0.65
        }
        Rectangle {
            x: track.width * 2 / 3 - 0.5
            y: 1
            width: 1
            height: track.height - 2
            color: Local.ClipboardTheme.panel
            opacity: 0.65
        }
    }
}
