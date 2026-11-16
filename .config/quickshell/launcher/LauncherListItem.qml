import QtQuick
import Quickshell
import "../" as Local
import "." as Parts

// One row of the list view (same behaviour as the grid item, vertical drag).
Item {
    id: item

    required property int index
    required property string appName
    required property string appIcon
    required property bool isCustom
    required property string itemType
    required property string itemCmd
    required property string itemPath

    property var controller
    property var view
    property int tabIdx: 0

    readonly property int visualIndex: index
    readonly property bool canEdit: !isCustom
    readonly property bool editing: controller ? controller.editMode : false

    width: view ? view.width : 0
    height: 56
    z: ma.drag.active ? 100 : 1
    property real appearP: 0
    opacity: appearP
    transform: Translate { y: (1 - item.appearP) * 8 }

    SequentialAnimation {
        id: appearAnim
        PauseAnimation { id: appearDelay; duration: 0 }
        NumberAnimation {
            target: item; property: "appearP"; to: 1; duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
        }
    }
    function playAppear() {
        appearAnim.stop();
        item.appearP = 0;
        appearDelay.duration = Math.min(item.index * 12, 180);
        appearAnim.start();
    }
    Component.onCompleted: playAppear()
    Component.onDestruction: appearAnim.stop()

    ListView.onPooled: { appearAnim.stop(); item.appearP = 0; icon.source = ""; }
    ListView.onReused: {
        playAppear();
        icon.source = item.appIcon ? Quickshell.iconPath(item.appIcon, true) : "";
    }

    DropArea {
        anchors.fill: parent
        visible: item.canEdit
        onEntered: function (dragEvent) {
            const from = dragEvent.source.visualIndex;
            const to = item.visualIndex;
            if (from !== undefined && to !== undefined && from !== to)
                item.controller.modelForTab(item.tabIdx).move(from, to, 1);
        }
    }

    Rectangle {
        id: card
        x: 0
        y: 2
        width: item.width
        height: item.height - 5
        radius: 14
        color: ma.containsMouse && !item.editing ? Qt.alpha(Local.M3.surfaceText, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on y { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real pressX: width / 2
        property real pressY: height / 2
        Drag.active: ma.drag.active
        Drag.source: item
        Drag.hotSpot.x: card.pressX
        Drag.hotSpot.y: card.pressY

        states: State {
            when: ma.drag.active
            ParentChange { target: card; parent: item.view }
            PropertyChanges { target: card; z: 1000; opacity: 0.9; scale: 1.02 }
        }

        Row {
            anchors {
                left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                leftMargin: 16; rightMargin: 16
            }
            spacing: 14
            Image {
                id: icon
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: item.appIcon ? Quickshell.iconPath(item.appIcon, true) : ""
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Component.onDestruction: source = ""
            }
            Local.M3Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - parent.spacing
                text: item.appName
                color: Local.M3.surfaceText
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            drag.target: (item.editing && item.canEdit) ? card : null
            drag.axis: Drag.YAxis
            cursorShape: item.editing && item.canEdit ? Qt.OpenHandCursor : Qt.ArrowCursor

            Timer {
                id: holdTimer
                interval: 500
                onTriggered: { if (!item.editing && item.canEdit) item.controller.editMode = true; }
            }
            onPressed: function (mouse) {
                if (!item.editing && item.canEdit) holdTimer.start();
                if (item.editing && item.canEdit) {
                    holdTimer.stop();
                    card.pressX = mouse.x;
                    card.pressY = mouse.y;
                    cursorShape = Qt.ClosedHandCursor;
                }
            }
            onReleased: {
                holdTimer.stop();
                if (item.editing && item.canEdit) {
                    cursorShape = Qt.OpenHandCursor;
                    card.y = 2;
                    item.controller.saveOrderForTab(item.tabIdx);
                    item.controller.setCacheForTab(item.tabIdx, null);
                }
            }
            onCanceled: holdTimer.stop()
            onClicked: {
                if (!item.editing) {
                    item.view.currentIndex = item.index;
                    item.controller.focusSearchRequested();
                }
            }
            onDoubleClicked: {
                if (!item.editing)
                    item.controller.launchItem(item.isCustom, item.appName, item.itemType, item.itemCmd, item.itemPath);
            }
        }

        Parts.LauncherHideBadge {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
            shown: item.editing && item.canEdit
            onClicked: {
                item.controller.hideApp(item.appName);
                item.controller.modelForTab(item.tabIdx).remove(item.index);
                item.controller.saveOrderForTab(item.tabIdx);
            }
        }
    }
}
