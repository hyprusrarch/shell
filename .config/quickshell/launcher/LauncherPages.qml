import QtQuick
import "../" as Local
import "." as Parts

// The tab pages. Same transition as the notification centre / Wi-Fi / clipboard
// pages: every page slides 48px against the spring and cross-fades
// (opacity 1 - 1.4 * distance). A drag moves the spring position directly and
// hands the distance back to the spring on release. Panes are built lazily and
// only while visible.
Item {
    id: root

    required property var controller
    property bool ready: true

    property real dragFrac: 0
    readonly property real position: pageP.value + dragFrac
    readonly property int pageCount: controller.tabList.length

    clip: true

    Local.SpringValue { id: pageP; spring: Local.M3.spatialDefault; target: root.controller.activeTabIndex }

    // resist swiping past the first / last tab
    function rubber(frac) {
        if ((root.controller.activeTabIndex === 0 && frac < 0)
                || (root.controller.activeTabIndex === root.pageCount - 1 && frac > 0))
            return frac * 0.25;
        return frac;
    }

    DragHandler {
        id: swipe
        target: null
        enabled: !root.controller.editMode
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: if (active) root.dragFrac = root.rubber(-translation.x / root.width)
        onActiveChanged: {
            if (active) return;
            const f = root.dragFrac;
            let next = root.controller.activeTabIndex;
            if (f > 0.22 && next < root.pageCount - 1) next++;
            else if (f < -0.22 && next > 0) next--;
            pageP.value += f;               // continue from where the finger left off
            root.dragFrac = 0;
            root.controller.switchTab(next);
            pageP.kick();
        }
    }

    // ── keyboard / activation (driven by the search field) ──────────────
    function currentView() {
        const ldr = pages.itemAt(root.controller.activeTabIndex);
        return (ldr && ldr.item) ? ldr.item.activeView : null;
    }

    function navigate(key) {
        const v = root.currentView();
        if (!v) return;
        const isGrid = typeof v.moveCurrentIndexUp === "function";
        if (key === Qt.Key_Up) { if (isGrid) v.moveCurrentIndexUp(); else v.decrementCurrentIndex(); }
        else if (key === Qt.Key_Down) { if (isGrid) v.moveCurrentIndexDown(); else v.incrementCurrentIndex(); }
        else if (key === Qt.Key_Left && isGrid) v.moveCurrentIndexLeft();
        else if (key === Qt.Key_Right && isGrid) v.moveCurrentIndexRight();
        v.positionViewAtIndex(v.currentIndex, ListView.Contain);
    }

    function activateCurrent() {
        const v = root.currentView();
        if (!v) return;
        const mdl = root.controller.modelForTab(root.controller.activeTabIndex);
        const cur = v.currentIndex;
        const target = (cur >= 0 && cur < mdl.count) ? mdl.get(cur) : (mdl.count === 1 ? mdl.get(0) : null);
        if (target)
            root.controller.launchItem(target.isCustom, target.appName, target.itemType, target.itemCmd, target.itemPath);
    }

    // once the app list is ready, (re)build every pane that already exists
    Connections {
        target: root.controller
        function onListStabilizedChanged() {
            if (!root.controller.listStabilized) return;
            for (let i = 0; i < root.pageCount - 1; i++) {
                const ldr = pages.itemAt(i);
                if (ldr && ldr.item && ldr.item.rebuild) ldr.item.rebuild();
            }
        }
    }

    Repeater {
        id: pages
        model: root.pageCount
        delegate: Loader {
            id: page
            required property int index

            width: root.width
            height: root.height
            x: -48 * (root.position - index)
            opacity: Math.max(0, Math.min(1, 1 - 1.4 * Math.abs(root.position - index)))
            visible: opacity > 0.001
            enabled: root.controller.activeTabIndex === index
            active: root.ready && (root.controller.activeTabIndex === index || Math.abs(root.position - index) < 1)
            asynchronous: true
            sourceComponent: index === root.controller.themeTab ? themeComp : appComp

            Component {
                id: appComp
                Parts.LauncherAppPane { controller: root.controller; tabIdx: page.index }
            }
            Component {
                id: themeComp
                Parts.LauncherThemePane { controller: root.controller }
            }
        }
    }
}
