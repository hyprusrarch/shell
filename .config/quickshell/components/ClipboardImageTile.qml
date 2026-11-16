import QtQuick
import Quickshell
import "." as ClipboardParts
import "../" as Local

// One image in the 3-column grid. Images are rounded with a CornerMask (the
// panel colour cut around a rounded rectangle) because `clip: true` only clips
// to a rectangle. There are no empty placeholder tiles: the grid only contains
// real clipboard images.
Item {
    id: tile
    property var controller
    property var itemData
    property int itemIndex: 0
    property real cellSize: 108
    property bool hovered: tileHover.hovered
    readonly property real cornerRadius: 22

    width: cellSize
    height: cellSize
    opacity: Math.max(0, Math.min(1, appear.value)) * Math.min(1, removal.presence * 1.4)
    scale: (0.95 + 0.05 * appear.value) * (1 + 0.015 * hoverMorph.value) * (0.88 + 0.12 * removal.presence)
    transform: Translate { y: (1 - appear.value) * 10 }
    enabled: !removal.active

    Local.SpringValue { id: appear; spring: Local.M3.spatialDefault; initial: 0; target: 1 }
    Local.SpringValue { id: hoverMorph; spring: Local.M3.spatialFast; target: tile.hovered ? 1 : 0 }
    HoverHandler { id: tileHover; acceptedDevices: PointerDevice.Mouse; target: null }

    ClipboardParts.ClipboardRemoval {
        id: removal
        controller: tile.controller
        itemIndex: tile.itemIndex
        onFinished: tile.controller.deleteClipboardEntry("IMG", tile.itemData.clipId, tile.itemData.rawPath)
    }

    Item {
        id: frame
        anchors.fill: parent
        anchors.margins: 2

        Rectangle {                         // surface shown while the image decodes
            anchors.fill: parent
            radius: tile.cornerRadius
            color: tile.hovered
                ? Qt.tint(Local.ClipboardTheme.content, Qt.alpha(Local.ClipboardTheme.text, 0.08))
                : Local.ClipboardTheme.content
            Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }
        }

        Image {
            id: image
            anchors.fill: parent
            source: tile.itemData.path || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(tile.cellSize * 2, tile.cellSize * 2)
            cache: false
            mipmap: false
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // Real rounded corners (panel colour is what sits behind the grid).
        Local.CornerMask {
            anchors.fill: parent
            radius: tile.cornerRadius
            color: Local.ClipboardTheme.panel
        }

        Rectangle {                         // hover wash, rounded to match
            anchors.fill: parent
            radius: tile.cornerRadius
            color: tile.hovered ? Qt.alpha(Local.ClipboardTheme.accent, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Rectangle {                         // source-app badge
            visible: tileBadge.hasIcon
            x: 5; y: 5; z: 2
            width: 20; height: 20; radius: 10
            color: Qt.alpha(Local.ClipboardTheme.panel, 0.82)
            ClipboardParts.ClipboardSource {
                id: tileBadge
                anchors.centerIn: parent
                source: tile.itemData.source || ""
                showName: false
                iconSize: 13
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                tile.controller.copyImage(tile.itemData.rawPath, tile.itemData.mime, tile.itemData.source || "");
                tile.controller.showCopyFeedback();
            }
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4
            spacing: 0
            z: 3

            ClipboardParts.ClipboardIconButton {
                iconSource: tile.itemData.isFav === true ? "../assets/clipboard/heart-filled.svg" : "../assets/clipboard/heart.svg"
                iconSize: 12
                hoverColor: Qt.alpha(Local.ClipboardTheme.accent, 0.18)
                onActivated: tile.controller.toggleFav("IMG", tile.itemData.clipId, "", tile.itemData.rawPath, tile.itemData.mime, tile.itemData.source || "")
            }
            ClipboardParts.ClipboardIconButton {
                iconSource: "../assets/clipboard/trash.svg"
                iconSize: 12
                hoverColor: Qt.alpha(Local.ClipboardTheme.error, 0.18)
                onActivated: removal.remove(0, false)
            }
        }
    }

    GridView.onReused: {
        removal.reset();
        appear.value = 0;
        appear.target = 1;
        appear.kick();
    }
}
