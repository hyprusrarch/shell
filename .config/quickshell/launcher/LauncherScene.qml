import QtQuick
import QtQuick.Layouts
import "../" as Local
import "." as Parts

// One launcher window's content: the dismiss backdrop plus the panel surface.
// Opens and closes exactly like Panel.qml (notification centre / Wi-Fi /
// clipboard): one M3 spring scales it in from the corner and fades it, a
// second spring grows the surface height (container transform) while the
// content keeps its size and is revealed.
Item {
    id: scene

    property int closeRequest: 0
    signal closed()

    readonly property real panelWidth: 768
    readonly property real panelHeight: 518
    property bool shown: false
    property bool closing: false
    property bool closeSent: false
    // Heavy content (the app panes) is built only once the surface has mostly
    // opened, so the open animation itself never competes with model building.
    property bool contentReady: false
    property int warmFrames: 0

    function requestClose() {
        if (scene.closing) return;
        scene.closing = true;
        scene.shown = false;
        // closed before the open animation ever started: nothing to play
        if (openP.value < 0.03 && !scene.closeSent) {
            scene.closeSent = true;
            scene.closed();
        }
    }

    onCloseRequestChanged: if (controller.startupReady) requestClose()

    Parts.LauncherController {
        id: controller
        onCloseRequested: scene.requestClose()
        onFocusSearchRequested: searchBar.focusField()
    }

    Local.SpringValue { id: openP; spring: Local.M3.spatialDefault; target: scene.shown ? 1 : 0 }
    Local.SpringValue { id: hSpring; spring: Local.M3.spatialDefault; target: scene.shown ? scene.panelHeight : 115 }

    Connections {
        target: openP
        function onValueChanged() {
            if (!scene.contentReady && openP.value > 0.8) scene.contentReady = true;
            if (scene.closing && !scene.closeSent && openP.value < 0.03) {
                scene.closeSent = true;
                scene.closed();
            }
        }
    }

    // A freshly created layer-shell window is not on screen for its first
    // frames. Start the open spring only after a few frames were really
    // rendered; otherwise the opening plays while nothing is visible and the
    // launcher just pops in.
    FrameAnimation {
        running: !scene.shown && !scene.closing
        onTriggered: {
            scene.warmFrames++;
            if (scene.warmFrames >= 3) scene.shown = true;
        }
    }

    Component.onCompleted: searchBar.focusField()

    // Esc leaves edit mode first, then closes.
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (controller.editMode) controller.editMode = false;
            else scene.requestClose();
        }
    }

    // Click outside: leave edit mode, or close.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (controller.editMode) controller.editMode = false;
            else scene.requestClose();
        }
    }

    Item {
        id: panel
        x: 12
        y: 12
        width: scene.panelWidth
        height: Math.max(115, hSpring.value)
        opacity: Math.max(0, Math.min(1, openP.value * 1.6))
        enabled: !scene.closing
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: 0.9 + 0.1 * openP.value
            yScale: 0.9 + 0.1 * openP.value
        }

        MouseArea { anchors.fill: parent }   // swallow clicks so the backdrop doesn't close us

        Rectangle {
            anchors.fill: parent
            radius: Local.M3.shapeLgInc
            color: Local.M3.surfaceContainer
        }

        Item {
            anchors.fill: parent
            clip: true

            ColumnLayout {
                x: 22
                y: 22
                width: scene.panelWidth - 44
                height: scene.panelHeight - 44
                spacing: 14

                Parts.LauncherSearchBar {
                    id: searchBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    controller: controller
                    onNavigate: key => pages.navigate(key)
                    onAccepted: {
                        if (controller.calcResult !== "" && controller.activeTabIndex !== controller.themeTab)
                            controller.copyCalcResult();
                        else if (controller.activeTabIndex === controller.themeTab)
                            scene.applyCurrentTheme();
                        else
                            pages.activateCurrent();
                    }
                }

                Parts.LauncherTabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    controller: controller
                    position: pages.position
                    onTabSelected: index => {
                        controller.switchTab(index);
                        searchBar.focusField();
                    }
                }

                Parts.LauncherCalcStrip {
                    id: calc
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: implicitHeight > 0.5
                    result: controller.activeTabIndex === controller.themeTab ? "" : controller.calcResult
                    onCopyRequested: controller.copyCalcResult()
                }

                Parts.LauncherPages {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    controller: controller
                    ready: scene.contentReady
                }
            }
        }
    }

    // Enter on the themes tab applies the single / first theme shown.
    function applyCurrentTheme() {
        const mdl = controller.modelForTab(controller.themeTab);
        if (mdl.count > 0) {
            Local.Theme.applyTheme(mdl.get(0).themeName);
        }
    }
}
