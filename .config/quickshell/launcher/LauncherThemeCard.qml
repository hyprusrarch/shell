import QtQuick
import QtQuick.Layouts
import "../" as Local

// One theme preview: its own background, name and colour swatches. The
// current theme gets an accent ring that springs in.
Item {
    id: card

    required property int index
    required property string themeName
    required property string bgMain
    required property string textMain
    required property string accent
    required property string accentAlt
    required property string warning
    required property string error
    required property string info

    property var controller
    property var view

    readonly property bool current: Local.Theme.currentTheme === themeName

    width: view ? view.cellWidth : 0
    height: view ? view.cellHeight : 0
    opacity: 0
    scale: 0.9

    SequentialAnimation {
        running: true
        PauseAnimation { duration: Math.min(card.index * 12, 200) }
        ParallelAnimation {
            NumberAnimation {
                target: card; property: "opacity"; to: 1; duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }

    property real ringP: card.current ? 1 : 0
    Behavior on ringP { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    property real hoverP: area.containsMouse ? 1 : 0
    Behavior on hoverP { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // outer frame (ring)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 16
        scale: 1 + 0.02 * card.hoverP
        color: Qt.tint(Local.M3.surfaceContainerHigh, Qt.alpha(Local.M3.primary, 0.22 * card.ringP))
        border.width: 2
        border.color: Qt.alpha(Local.M3.primary, card.ringP)

        // the theme's own background
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5 * card.ringP
            radius: 12
            color: card.bgMain

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Local.M3Text {
                    Layout.fillWidth: true
                    text: card.themeName.replace(/_/g, " ")
                    color: card.current ? Local.M3.primary : card.textMain
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: [card.accent, card.accentAlt, card.warning, card.error, card.info]
                        delegate: Rectangle {
                            required property string modelData
                            width: 14
                            height: 14
                            radius: 7
                            color: modelData || "transparent"
                        }
                    }
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Local.Theme.applyTheme(card.themeName);
                card.controller.focusSearchRequested();
            }
        }
    }
}
