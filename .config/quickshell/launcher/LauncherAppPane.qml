import QtQuick
import "../" as Local
import "." as Parts

// The grid + list for one tab. Both views share the tab's ListModel; only the
// active one is bound. A spring-driven highlight follows the keyboard cursor.
Item {
    id: pane

    required property var controller
    property int tabIdx: 0

    readonly property Item activeView: pane.controller.gridViewMode ? tabGrid : tabList

    // build the model when the pane appears, release it when the pane goes
    Component.onCompleted: {
        if (pane.controller.listStabilized)
            Qt.callLater(function () { pane.controller.rebuildTabModel(pane.tabIdx); });
    }
    Component.onDestruction: pane.controller.modelForTab(pane.tabIdx).clear()

    function rebuild() { pane.controller.rebuildTabModel(pane.tabIdx); }

    // ── GRID ────────────────────────────────────────────────────────────
    Local.SpringValue {
        id: gx
        spring: Local.M3.spatialFast
        target: tabGrid.currentItem ? tabGrid.currentItem.x + 5 : 0
    }
    Local.SpringValue {
        id: gy
        spring: Local.M3.spatialFast
        target: tabGrid.currentItem ? tabGrid.currentItem.y + 5 : 0
    }

    GridView {
        id: tabGrid
        anchors.fill: parent
        clip: true
        visible: pane.controller.gridViewMode
        model: pane.controller.gridViewMode ? pane.controller.modelForTab(pane.tabIdx) : null
        reuseItems: true
        cacheBuffer: 0
        cellWidth: Math.floor(width / 6)
        cellHeight: 114
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        currentIndex: 0
        highlightFollowsCurrentItem: false
        highlight: Rectangle {
            x: gx.value
            y: gy.value
            width: tabGrid.cellWidth - 10
            height: tabGrid.cellHeight - 10
            radius: 16
            color: Local.M3.surfaceContainerHighest
            visible: tabGrid.count > 0 && !pane.controller.editMode
            opacity: 0.9
        }
        onModelChanged: currentIndex = 0
        onCountChanged: {
            if (count === 0) currentIndex = 0;
            else if (currentIndex >= count) currentIndex = count - 1;
        }
        moveDisplaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
        }
        delegate: Parts.LauncherGridItem {
            controller: pane.controller
            view: tabGrid
            tabIdx: pane.tabIdx
        }
    }

    // ── LIST ────────────────────────────────────────────────────────────
    Local.SpringValue {
        id: ly
        spring: Local.M3.spatialFast
        target: tabList.currentItem ? tabList.currentItem.y + 2 : 0
    }

    ListView {
        id: tabList
        anchors.fill: parent
        clip: true
        visible: !pane.controller.gridViewMode
        model: !pane.controller.gridViewMode ? pane.controller.modelForTab(pane.tabIdx) : null
        reuseItems: true
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        currentIndex: 0
        highlightFollowsCurrentItem: false
        highlight: Rectangle {
            y: ly.value
            width: tabList.width
            height: 51
            radius: 14
            color: Local.M3.surfaceContainerHighest
            visible: tabList.count > 0 && !pane.controller.editMode
            opacity: 0.9
        }
        onModelChanged: currentIndex = 0
        onCountChanged: {
            if (count === 0) currentIndex = 0;
            else if (currentIndex >= count) currentIndex = count - 1;
        }
        moveDisplaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
        }
        delegate: Parts.LauncherListItem {
            controller: pane.controller
            view: tabList
            tabIdx: pane.tabIdx
        }
    }

    Local.M3Text {
        anchors.centerIn: parent
        visible: pane.controller.listStabilized && (pane.controller.gridViewMode ? tabGrid.count : tabList.count) === 0
        text: "Nothing here"
        color: Local.M3.surfaceVariantText
        font.pixelSize: 14
    }
}
