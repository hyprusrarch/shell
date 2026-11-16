import QtQuick
import Quickshell
import "." as ClipboardParts
import "../" as Local

Item {
    id: entry
    property var controller
    property var itemData
    property int itemIndex: 0
    property int itemCount: 0
    property real containerWidth: 0
    property bool isExpanded: false
    property bool hovered: entryHover.hovered
    readonly property real collapsedBodyHeight: 65
    readonly property real extraHeight: itemData.type === "TXT" ? Math.min(144, Math.max(0, naturalFavText.implicitHeight - collapsedBodyHeight)) : 0
    readonly property bool canExpand: itemData.type === "TXT" && (favText.truncated || extraHeight > 1)
    property string pendingAction: "delete"
    width: containerWidth
    opacity: Math.max(0, Math.min(1, appear.value)) * Math.min(1, removal.presence * 1.4)
    scale: (0.97 + 0.03 * appear.value) * (0.94 + 0.06 * removal.presence)
    transform: Translate { y: (1 - appear.value) * 12 }
    clip: removal.presence < 0.999
    enabled: !removal.active

    Local.SpringValue { id: appear; spring: Local.M3.spatialDefault; initial: 0; target: 1 }
    Local.SpringValue { id: expansion; spring: Local.M3.spatialDefault; target: entry.isExpanded ? 1 : 0 }
    height: (itemData.type === "TXT" ? 120 + extraHeight * expansion.value : 140) * removal.presence

    ClipboardParts.ClipboardRemoval {
        id: removal
        controller: entry.controller
        itemIndex: entry.itemIndex
        onFinished: {
            if (entry.pendingAction === "unfavorite")
                entry.controller.toggleFav(entry.itemData.type, entry.itemData.clipId, entry.itemData.content || "", entry.itemData.rawPath, entry.itemData.mime || "");
            else
                entry.controller.deleteClipboardEntry("FAV", entry.itemData.clipId, entry.itemData.rawPath);
        }
    }

    HoverHandler { id: entryHover; acceptedDevices: PointerDevice.Mouse; target: null }
    Rectangle {
        id: rowSurface
        anchors.fill: parent
        color: entry.hovered ? Qt.tint(Local.ClipboardTheme.content, Qt.alpha(Local.ClipboardTheme.text, 0.075)) : Local.ClipboardTheme.content
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    ClipboardParts.ClipboardSource {
        visible: itemData.type === "TXT"
        x: 13; y: 9
        source: entry.itemData.source || ""
    }

    Local.M3Text {
        id: favText
        visible: itemData.type === "TXT"
        x: 13; y: 32; width: parent.width - 26; height: entry.collapsedBodyHeight + entry.extraHeight * expansion.value
        text: String(itemData.content || "").trim()
        font.pixelSize: 10; color: Local.ClipboardTheme.text; wrapMode: Text.Wrap
        lineHeight: 1.12; lineHeightMode: Text.ProportionalHeight
        maximumLineCount: entry.isExpanded ? 1000 : 6
        elide: Text.ElideRight
    }

    Local.M3Text {
        id: naturalFavText
        visible: false
        width: entry.width - 26
        text: String(itemData.content || "").trim()
        font.pixelSize: 10
        wrapMode: Text.Wrap
        lineHeight: 1.12
        lineHeightMode: Text.ProportionalHeight
    }

    Item {
        id: imageFrame
        visible: itemData.type === "IMG"
        anchors.fill: parent
        anchors.margins: 8
        anchors.rightMargin: 7

        Rectangle {                       // loading surface, same rounding as the image
            anchors.fill: parent
            radius: 16
            color: Local.ClipboardTheme.selected
        }
        Image {
            id: favImage
            anchors.fill: parent
            source: entry.itemData.type === "IMG" ? (entry.itemData.path || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width * 2, height * 2)
            cache: false
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Rectangle {                     // source-app badge
            visible: favBadge.hasIcon
            x: 6; y: 6; z: 2
            width: 22; height: 22; radius: 11
            color: Qt.alpha(Local.ClipboardTheme.panel, 0.82)
            ClipboardParts.ClipboardSource {
                id: favBadge
                anchors.centerIn: parent
                source: entry.itemData.source || ""
                showName: false
                iconSize: 14
            }
        }
        // `clip: true` is rectangular; cut the real rounded corners out of the
        // image with the row colour so favourites match the images tab.
        Local.CornerMask {
            anchors.fill: parent
            radius: 16
            color: rowSurface.color
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: 27
        anchors.rightMargin: 60
        anchors.bottomMargin: entry.canExpand ? 19 : 0
        z: 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (entry.itemData.type === "TXT") entry.controller.copyText(entry.itemData.rawPath, entry.itemData.source || "");
            else entry.controller.copyImage(entry.itemData.rawPath, entry.itemData.mime, entry.itemData.source || "");
            entry.controller.showCopyFeedback();
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 7
        anchors.topMargin: 5
        spacing: 1
        z: 5
        ClipboardParts.ClipboardIconButton {
            iconSource: "../assets/clipboard/heart-filled.svg"
            iconSize: 13
            hoverColor: Qt.alpha(Local.ClipboardTheme.accent, 0.16)
            onActivated: { entry.pendingAction = "unfavorite"; removal.remove(0, false); }
        }
        ClipboardParts.ClipboardIconButton {
            iconSource: "../assets/clipboard/trash.svg"
            iconSize: 13
            hoverColor: Qt.alpha(Local.ClipboardTheme.error, 0.16)
            onActivated: { entry.pendingAction = "delete"; removal.remove(0, false); }
        }
    }

    ClipboardParts.ClipboardSemiCircleHandle {
        visible: entry.canExpand
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        z: 6
        expanded: entry.isExpanded
        cutoutColor: Local.ClipboardTheme.panel
        arrowColor: Local.ClipboardTheme.text
        onClicked: entry.isExpanded = !entry.isExpanded
    }

    Rectangle {
        visible: entry.itemIndex < entry.itemCount - 1
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 1; color: Local.ClipboardTheme.panel; z: 7
    }

    ListView.onReused: {
        entry.isExpanded = false;
        removal.reset();
        appear.value = 0;
        appear.target = 1;
        appear.kick();
    }
}
