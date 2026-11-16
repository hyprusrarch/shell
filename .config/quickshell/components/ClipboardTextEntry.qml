import QtQuick
import Quickshell
import "../" as Local
import "." as ClipboardParts

Item {
    id: row
    property var controller
    property var itemData
    property int itemIndex: 0
    property int itemCount: 0
    property real containerWidth: 0
    property bool isExpanded: false
    property bool canExpand: bodyText.truncated || expandedBodyHeight > 1
    property bool hovered: rowHover.hovered
    readonly property real collapsedBodyHeight: 65
    readonly property real expandedBodyHeight: Math.min(144, Math.max(0, naturalText.implicitHeight - collapsedBodyHeight))
    width: containerWidth
    opacity: Math.max(0, Math.min(1, appear.value)) * Math.min(1, removal.presence * 1.4)
    scale: (0.97 + 0.03 * appear.value) * (0.94 + 0.06 * removal.presence)
    transform: Translate { y: (1 - appear.value) * 12 }
    clip: removal.presence < 0.999
    enabled: !removal.active

    Local.SpringValue { id: appear; spring: Local.M3.spatialDefault; initial: 0; target: 1 }
    Local.SpringValue {
        id: expansion
        spring: Local.M3.spatialDefault
        target: row.isExpanded ? 1 : 0
    }
    height: (120 + expandedBodyHeight * expansion.value) * removal.presence

    // Same spring + collapse the Wi-Fi / control-centre rows use. The real
    // delete only happens once the row has finished collapsing.
    ClipboardParts.ClipboardRemoval {
        id: removal
        controller: row.controller
        itemIndex: row.itemIndex
        onFinished: row.controller.deleteClipboardEntry("TXT", row.itemData.clipId, row.itemData.rawPath)
    }

    HoverHandler {
        id: rowHover
        acceptedDevices: PointerDevice.Mouse
        target: null
    }

    Rectangle {
        id: rowSurface
        anchors.fill: parent
        color: row.hovered
            ? Qt.tint(Local.ClipboardTheme.content, Qt.alpha(Local.ClipboardTheme.text, 0.075))
            : "transparent"
        Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    ClipboardParts.ClipboardSource {
        x: 13
        y: 9
        source: row.itemData.source || ""
    }

    Row {
        id: actions
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 5
        anchors.rightMargin: 7
        spacing: 1
        z: 5

        ClipboardParts.ClipboardIconButton {
            iconSource: row.itemData.isFav === true ? "../assets/clipboard/heart-filled.svg" : "../assets/clipboard/heart.svg"
            iconSize: 12
            hoverColor: Qt.alpha(Local.ClipboardTheme.accent, 0.16)
            onActivated: row.controller.toggleFav("TXT", row.itemData.clipId, row.itemData.content, row.itemData.rawPath, "text/plain", row.itemData.source || "")
        }
        ClipboardParts.ClipboardIconButton {
            iconSource: "../assets/clipboard/trash.svg"
            iconSize: 12
            hoverColor: Qt.alpha(Local.ClipboardTheme.error, 0.16)
            onActivated: removal.remove(0, false)
        }
    }

    Local.M3Text {
        id: bodyText
        x: 13
        y: 32
        width: parent.width - 26
        height: row.collapsedBodyHeight + row.expandedBodyHeight * expansion.value
        text: String(row.itemData.content || "").trim()
        color: Local.ClipboardTheme.text
        font.pixelSize: 10
        font.weight: Font.Normal
        wrapMode: Text.Wrap
        lineHeight: 1.12
        lineHeightMode: Text.ProportionalHeight
        maximumLineCount: row.isExpanded ? 1000 : 6
        elide: Text.ElideRight
    }

    // Measure the full clipboard payload separately so the row can reveal all
    // lines while its height and bottom semicircle morph together.
    Local.M3Text {
        id: naturalText
        visible: false
        x: 13
        y: 32
        width: parent.width - 26
        text: String(row.itemData.content || "").trim()
        font.pixelSize: 10
        wrapMode: Text.Wrap
        lineHeight: 1.12
        lineHeightMode: Text.ProportionalHeight
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: 28
        anchors.bottomMargin: row.canExpand ? 19 : 0
        z: 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            row.controller.copyText(row.itemData.rawPath, row.itemData.source || "");
            row.controller.showCopyFeedback();
        }
    }

    ClipboardParts.ClipboardSemiCircleHandle {
        visible: row.canExpand
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        z: 6
        expanded: row.isExpanded
        cutoutColor: Local.ClipboardTheme.panel
        arrowColor: Local.ClipboardTheme.text
        onClicked: row.isExpanded = !row.isExpanded
    }

    Rectangle {
        visible: row.itemIndex < row.itemCount - 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Local.ClipboardTheme.panel
        z: 7
    }

    ListView.onReused: {
        row.isExpanded = false;
        removal.reset();
        appear.value = 0;
        appear.target = 1;
        appear.kick();
    }
}
