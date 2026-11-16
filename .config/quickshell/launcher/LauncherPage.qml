import QtQuick
import QtQuick.Layouts
import "../" as Local
import "." as Parts

// The launcher as page 3 of the shared shell panel (Panel.qml), next to the
// notification centre (0), Wi-Fi (1) and clipboard (2). The panel owns the
// surface, the open / close spring, the container-transform size change and the
// page slide, so the launcher opens and closes exactly like they do. The
// content keeps a fixed size and is revealed as the surface grows.
Item {
    id: page

    property bool menuVisible: false

    readonly property real contentWidth: 732
    readonly property real contentHeight: 482

    Parts.LauncherController {
        id: controller
        onCloseRequested: Local.Ui.open = false
        onFocusSearchRequested: searchBar.focusField()
    }

    // Esc / backdrop click leave edit mode first (handled by the overlay).
    Binding { target: Local.Ui; property: "launcherEditing"; value: controller.editMode; when: page.menuVisible }
    Connections {
        target: Local.Ui
        function onLauncherEditingChanged() {
            if (!Local.Ui.launcherEditing && controller.editMode) controller.editMode = false;
        }
    }

    function start() {
        controller.editMode = false;
        controller.switchTab(0);
        controller.searchText = "";
        controller.searchCleared();
        controller.refreshActive();
        focusTimer.restart();
    }

    Timer { id: focusTimer; interval: 60; onTriggered: searchBar.focusField() }

    onMenuVisibleChanged: {
        if (menuVisible) start();
        else {
            controller.editMode = false;
            searchBar.releaseFocus();
            Local.Ui.launcherEditing = false;
        }
    }
    Component.onCompleted: if (menuVisible) start()

    // Enter on the themes tab applies the first theme shown.
    function applyCurrentTheme() {
        const mdl = controller.modelForTab(controller.themeTab);
        if (mdl.count > 0) Local.Theme.applyTheme(mdl.get(0).themeName);
    }

    Item {
        width: page.contentWidth
        height: page.contentHeight

        ColumnLayout {
            anchors.fill: parent
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
                        page.applyCurrentTheme();
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
            }
        }
    }
}
