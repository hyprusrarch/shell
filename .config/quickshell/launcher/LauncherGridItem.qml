import QtQuick
import Quickshell
import "../" as Local
import "." as Parts

// One app (or custom item: calculator/command/path/search) in the grid.
// Stagger-in uses the shared M3 spring; hover pops the icon with a faster
// under-damped spring; edit mode jiggles, drags to reorder and shows a hide badge.
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

    width: view ? view.cellWidth : 0
    height: view ? view.cellHeight : 0
    z: ma.drag.active ? 100 : 1
    opacity: 0
    scale: 0.75

    // ── stagger-in ──────────────────────────────────────────────────────
    // Runs on the animation engine (not a JS spring per item), so dozens of
    // icons can appear together without costing frames.
    SequentialAnimation {
        id: appearAnim
        PauseAnimation { id: appearDelay; duration: 0 }
        ParallelAnimation {
            NumberAnimation {
                target: item; property: "opacity"; to: 1; duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            }
            NumberAnimation {
                target: item; property: "scale"; to: 1; duration: 340
                easing.type: Easing.OutBack; easing.overshoot: 1.1
            }
        }
    }
    function playAppear() {
        appearAnim.stop();
        item.opacity = 0;
        item.scale = 0.75;
        appearDelay.duration = Math.min(item.index * 15, 240);
        appearAnim.start();
    }
    Component.onCompleted: playAppear()
    Component.onDestruction: appearAnim.stop()

    GridView.onPooled: {
        appearAnim.stop();
        item.opacity = 0;
        item.scale = 0.75;
        jiggle.running = false;
        icon.source = "";
    }
    GridView.onReused: {
        playAppear();
        icon.source = item.appIcon ? Quickshell.iconPath(item.appIcon, true) : "";
        jiggle.running = item.editing && !ma.drag.active;
    }

    // drop target while another item is dragged over this one
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
        x: 5
        y: 5
        width: item.width - 10
        height: item.height - 10
        radius: 16
        color: ma.containsMouse && !item.editing ? Qt.alpha(Local.M3.surfaceText, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on x { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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
            PropertyChanges { target: card; z: 1000; opacity: 0.9; scale: 1.06 }
        }

        RotationAnimation on rotation {
            id: jiggle
            running: item.editing && !ma.drag.active
            loops: Animation.Infinite
            from: -1.2
            to: 1.2
            duration: 220 + (item.index % 5) * 30
            easing.type: Easing.SineCurve
        }
        Behavior on rotation { enabled: !item.editing; NumberAnimation { duration: 120 } }

        Column {
            anchors.centerIn: parent
            spacing: 10

            Item {
                width: 40
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                scale: ma.containsMouse && !item.editing ? 1.10 : 1.0
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                Image {
                    id: icon
                    anchors.fill: parent
                    sourceSize: Qt.size(80, 80)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: item.appIcon ? Quickshell.iconPath(item.appIcon, true) : ""
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Component.onDestruction: source = ""
                }
            }
            Local.M3Text {
                width: card.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.appName
                color: Local.M3.surfaceText
                font.pixelSize: 13
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            drag.target: (item.editing && item.canEdit) ? card : null
            drag.axis: Drag.XAndYAxis
            cursorShape: item.editing && item.canEdit ? Qt.OpenHandCursor : Qt.ArrowCursor

            // press-and-hold enters edit mode
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
                    card.x = 5;
                    card.y = 5;
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
            anchors { top: parent.top; right: parent.right; topMargin: -5; rightMargin: -5 }
            shown: item.editing && item.canEdit
            onClicked: {
                item.controller.hideApp(item.appName);
                item.controller.modelForTab(item.tabIdx).remove(item.index);
                item.controller.saveOrderForTab(item.tabIdx);
            }
        }
    }
}
