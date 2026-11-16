import QtQuick
import QtQuick.Layouts
import Qt.labs.settings 1.0
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "." as Local

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-clipboard"
    focusable: true
    color: "transparent"

    readonly property string fontFamily: Local.M3.font
    readonly property color panelSurface: Local.ClipboardTheme.panel
    readonly property color contentSurface: Local.ClipboardTheme.content
    readonly property color contentHover: Qt.tint(Local.ClipboardTheme.content, Qt.alpha(Local.ClipboardTheme.text, 0.08))
    readonly property color tabSelected: Local.ClipboardTheme.selected
    readonly property color clrText: Local.ClipboardTheme.text
    readonly property color subtext: Local.ClipboardTheme.secondaryText
    readonly property color accent: Local.ClipboardTheme.accent
    readonly property color errorColor: Local.ClipboardTheme.error

    property string homeDir: ""
    property var textModelArr: []
    property var imageModelArr: []
    property var favModelArr: []
    property var favs: ({ items: [] })
    property var backendMutationQueue: []
    property bool refreshAfterMutation: false
    property int activeTab: 0
    property real dragFrac: 0            // live swipe progress, in pages
    readonly property real pagePos: pageP.value + dragFrac
    property bool shown: false
    property bool isClosing: false
    property bool closeNotified: false
    property bool clearing: false

    // Emitted when "remove all" starts: every visible entry collapses one after
    // another (staggered) before the data is wiped.
    signal clearRequested()

    function localPath(relativePath) {
        let url = String(Qt.resolvedUrl(relativePath));
        if (url.indexOf("file://") === 0)
            url = decodeURIComponent(url.slice(7));
        return url;
    }

    function runScript(name, args) {
        let command = ["bash", localPath("scripts/" + name)];
        if (args && args.length) command = command.concat(args);
        Quickshell.execDetached(command);
    }

    function requestClose() {
        if (root.isClosing) return;
        root.isClosing = true;
        root.shown = false;
    }

    function notifyClosed() {
        Quickshell.execDetached(["sh", "-c",
            "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf 'closed clipboard\\n' >> \"$runtime/quickshell/control\""]);
    }

    Settings {
        id: clipboardSettings
        category: "Clipboard"
        property string favData: '{"items":[]}'
        property bool clipboardEnabled: true
    }
    readonly property bool clipboardEnabled: clipboardSettings.clipboardEnabled

    function parseFavorites() {
        try {
            const data = JSON.parse(clipboardSettings.favData || '{"items":[]}');
            return { items: Array.isArray(data.items) ? data.items : [] };
        } catch (e) {
            console.warn("Clipboard favorites could not be parsed:", e);
            return { items: [] };
        }
    }

    function persistFavorites() {
        clipboardSettings.favData = JSON.stringify(root.favs);
        root.favModelArr = root.favs.items.slice();
    }

    function syncClipboardBackend(enabled) {
        const state = enabled ? "1" : "0";
        const action = enabled ? "start" : "stop";
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell\"; " +
            "printf '%s\\n' \"$1\" > \"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clipboard-enabled\"; " +
            "exec \"$2\" \"$3\"",
            "qs-clipboard-toggle", state, root.localPath("scripts/clipboard-watch.sh"), action]);
    }

    function setClipboardEnabled(enabled) {
        if (clipboardSettings.clipboardEnabled === enabled) return;
        clipboardSettings.clipboardEnabled = enabled;
        syncClipboardBackend(enabled);
    }

    function updateFavModel() {
        root.favModelArr = (root.favs.items || []).slice();
    }

    function checkFav(type, clipId) {
        return (root.favs.items || []).some(f => f.type === type && String(f.clipId) === String(clipId));
    }

    function setFavFlag(type, clipId, value) {
        if (type === "TXT") {
            root.textModelArr = root.textModelArr.map(item =>
                String(item.clipId) === String(clipId) ? Object.assign({}, item, { isFav: value }) : item);
        } else if (type === "IMG") {
            root.imageModelArr = root.imageModelArr.map(item =>
                String(item.clipId) === String(clipId) ? Object.assign({}, item, { isFav: value }) : item);
        }
    }

    function favoriteExtension(mime) {
        switch (mime || "") {
        case "image/jpeg": return ".jpg";
        case "image/webp": return ".webp";
        case "image/gif": return ".gif";
        case "image/svg+xml": return ".svg";
        case "image/bmp": return ".bmp";
        case "image/avif": return ".avif";
        case "image/tiff": return ".tiff";
        case "image/x-icon": case "image/vnd.microsoft.icon": return ".ico";
        default: return mime && mime.indexOf("image/") === 0 ? ".png" : ".txt";
        }
    }

    function toggleFav(type, clipId, content, rawPath, mime) {
        const current = (root.favs.items || []).slice();
        const idx = current.findIndex(f => f.type === type && String(f.clipId) === String(clipId));
        if (idx >= 0) {
            const removed = current.splice(idx, 1)[0];
            root.favs = { items: current };
            root.persistFavorites();
            root.runScript("clipboard-favorite.sh", ["remove", removed.rawPath || ""]);
            setFavFlag(type, clipId, false);
            return;
        }

        const ext = favoriteExtension(mime);
        const destPath = root.homeDir + "/.cache/qs_clip_favs/fav_" + clipId + ext;
        root.runScript("clipboard-favorite.sh", ["add", rawPath, destPath]);
        current.unshift({
            type: type,
            clipId: String(clipId),
            content: content || "",
            path: "file://" + destPath,
            rawPath: destPath,
            mime: mime || ""
        });
        root.favs = { items: current };
        root.persistFavorites();
        setFavFlag(type, clipId, true);
    }

    function deleteClipboardEntry(type, clipId, rawPath) {
        const stableId = String(clipId);
        if (type === "FAV") {
            root.favs = { items: (root.favs.items || []).filter(f => String(f.clipId) !== stableId) };
            root.persistFavorites();
            root.runScript("clipboard-delete.sh", ["FAV", stableId, rawPath || ""]);
            setFavFlag("TXT", stableId, false);
            setFavFlag("IMG", stableId, false);
            return;
        }

        // Update by immutable cliphist ID, never by the delegate's recycled index.
        if (type === "TXT") root.textModelArr = root.textModelArr.filter(item => String(item.clipId) !== stableId);
        if (type === "IMG") root.imageModelArr = root.imageModelArr.filter(item => String(item.clipId) !== stableId);
        root.queueBackendMutation("clipboard-delete.sh", [type, stableId, rawPath || ""]);
    }

    function clearActiveTab() {
        if (root.activeTab === 0) {
            root.textModelArr = [];
            root.queueBackendMutation("clipboard-clear.sh", ["text"]);
        } else if (root.activeTab === 1) {
            root.imageModelArr = [];
            root.queueBackendMutation("clipboard-clear.sh", ["image"]);
        } else {
            const old = (root.favs.items || []).slice();
            root.favs = { items: [] };
            root.persistFavorites();
            old.forEach(f => {
                if (f.type === "TXT") setFavFlag("TXT", f.clipId, false);
                if (f.type === "IMG") setFavFlag("IMG", f.clipId, false);
            });
            root.queueBackendMutation("clipboard-clear.sh", ["favorites"]);
        }
    }

    function clearAll() {
        if (root.clearing) return;
        root.clearing = true;
        root.clearRequested();             // entries collapse one by one
        clearTimer.restart();
    }

    function finishClearAll() {
        // Clear text, images, and saved favourites as one operation, matching
        // the notification centre's Clear all action.
        root.clearing = false;
        root.textModelArr = [];
        root.imageModelArr = [];
        root.favs = { items: [] };
        root.persistFavorites();
        root.queueBackendMutation("clipboard-clear.sh", ["all"]);
    }

    function copyText(rawPath) {
        Quickshell.execDetached(["bash", "-c", "wl-copy < \"$1\"", "qs-copy-text", rawPath]);
    }

    function copyImage(rawPath, mime) {
        Quickshell.execDetached(["bash", "-c",
            "path=\"$1\"; mime=\"$2\"; " +
            "case \"$mime\" in image/*) wl-copy --type \"$mime\" < \"$path\" ;; *) " +
            "detected=$(file --brief --mime-type \"$path\" 2>/dev/null || true); " +
            "case \"$detected\" in image/*) wl-copy --type \"$detected\" < \"$path\" ;; *) wl-copy < \"$path\" ;; esac ;; esac",
            "qs-copy-image", rawPath, mime || ""]);
    }

    function showCopyFeedback() {
        copyFeedback = true;
        copyTimer.restart();
    }

    function switchTab(newTab) {
        if (newTab === root.activeTab) return;
        root.activeTab = newTab;
    }

    // Rubber-band the swipe at the first / last page.
    function rubber(frac) {
        if ((root.activeTab === 0 && frac < 0) || (root.activeTab === 2 && frac > 0))
            return frac * 0.25;
        return frac;
    }

    function refreshHistory() {
        if (clipFetcher.running || backendMutation.running || backendMutationQueue.length > 0) return;
        clipFetcher.stdout.tempTexts = [];
        clipFetcher.stdout.tempImages = [];
        clipFetcher.running = true;
    }

    function queueBackendMutation(name, args) {
        backendMutationQueue = backendMutationQueue.concat([{ name: name, args: args || [] }]);
        runNextBackendMutation();
    }

    function runNextBackendMutation() {
        if (backendMutation.running || backendMutationQueue.length === 0) return;
        const next = backendMutationQueue[0];
        backendMutationQueue = backendMutationQueue.slice(1);
        backendMutation.command = ["bash", root.localPath("scripts/" + next.name)].concat(next.args);
        backendMutation.running = true;
    }

    property bool copyFeedback: false

    Timer {
        id: copyTimer
        interval: 520
        onTriggered: root.copyFeedback = false
    }
    // Same spring family as Panel.qml (Wi-Fi / control centre): one spring opens
    // and closes the panel, one grows its height, one slides between pages.
    Local.SpringValue { id: openP; spring: Local.M3.spatialDefault; target: root.shown ? 1 : 0 }
    Local.SpringValue { id: hSpring; spring: Local.M3.spatialDefault; target: root.shown ? 474 : 96 }
    Local.SpringValue { id: pageP; spring: Local.M3.spatialDefault; target: root.activeTab }

    Connections {
        target: openP
        function onValueChanged() {
            if (root.isClosing && !root.closeNotified && openP.value < 0.03) {
                root.closeNotified = true;
                root.notifyClosed();
            }
        }
    }

    Timer { id: firstFetch; interval: 220; onTriggered: root.refreshHistory() }
    Timer { id: clearTimer; interval: 8 * 45 + 420; onTriggered: root.finishClearAll() }

    Process {
        id: backendMutation
        running: false
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Clipboard backend mutation failed:", exitCode, backendMutation.command.join(" "));
            if (root.backendMutationQueue.length > 0) {
                Qt.callLater(root.runNextBackendMutation);
            } else {
                Qt.callLater(() => {
                    if (clipFetcher.running) root.refreshAfterMutation = true;
                    else root.refreshHistory();
                });
            }
        }
    }

    Process {
        id: closeWatcher
        running: true
        command: ["sh", "-c",
            "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; exec tail -n 0 -F \"$runtime/quickshell/clipboard.cmd\""]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE") root.requestClose();
            }
        }
    }

    Process {
        id: clipFetcher
        running: false
        command: ["bash", root.localPath("scripts/clip-fetch.sh")]
        stdout: SplitParser {
            property var tempTexts: []
            property var tempImages: []
            onRead: function(data) {
                const line = data.trim();
                if (!line) return;
                const parts = line.split("|");
                if (parts[0] === "HOME") { root.homeDir = parts[1]; return; }
                if (parts.length < 3) return;
                const type = parts[0];
                const clipId = String(parts[1]);
                if (type === "TXT" && tempTexts.length < 60) {
                    const content = parts[3] ? parts[3].replace(/_NL_/g, "\n").replace(/¦/g, "|") : "";
                    tempTexts.push({ clipId: clipId, rawPath: parts[2], content: content });
                } else if (type === "IMG" && tempImages.length < 60) {
                    tempImages.push({ clipId: clipId, path: "file://" + parts[2], rawPath: parts[2], mime: parts[3] || "" });
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                const texts = stdout.tempTexts.map(item => Object.assign({}, item, { isFav: root.checkFav("TXT", item.clipId) }));
                const images = stdout.tempImages.map(item => Object.assign({}, item, { isFav: root.checkFav("IMG", item.clipId) }));
                root.textModelArr = texts;
                root.imageModelArr = images;
                stdout.tempTexts = [];
                stdout.tempImages = [];
                if (root.refreshAfterMutation) {
                    root.refreshAfterMutation = false;
                    Qt.callLater(root.refreshHistory);
                }
            }
        }
    }

    Component.onCompleted: {
        root.favs = root.parseFavorites();
        root.updateFavModel();
        root.syncClipboardBackend(root.clipboardEnabled);
        root.shown = true;
        firstFetch.start();
    }

    // Outside click closes the panel. The panel's own MouseArea consumes clicks.
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.requestClose()
    }
    Shortcut {
        sequence: "Ctrl+Shift+Delete"
        context: Qt.ApplicationShortcut
        onActivated: root.clearAll()
    }

    Item {
        id: panelHost
        readonly property real fullHeight: 474
        width: 352
        height: Math.max(96, hSpring.value)
        x: parent.width - width - 16
        y: 16
        opacity: Math.max(0, Math.min(1, openP.value * 1.6))
        transform: Scale {
            origin.x: panelHost.width
            origin.y: 0
            xScale: 0.9 + 0.1 * openP.value
            yScale: 0.9 + 0.1 * openP.value
        }

        Rectangle {
            id: panelSurface
            anchors.fill: parent
            radius: Local.M3.shapeXl
            color: Local.ClipboardTheme.panel
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            // Container transform: the surface grows, the content keeps its
            // size and is revealed (clipped) like Panel.qml does.
            Item {
                anchors.fill: parent
                clip: true

                ColumnLayout {
                    x: 14
                    y: 14
                    width: parent.width - 28
                    height: panelHost.fullHeight - 28
                    spacing: 7
                    enabled: !root.isClosing

                    Local.ClipboardHeader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        clipboardOn: root.clipboardEnabled
                        feedback: root.copyFeedback
                        onToggleRequested: value => root.setClipboardEnabled(value)
                        onRemoveAllRequested: root.clearAll()
                    }

                    Local.ClipboardTabBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        currentIndex: root.activeTab
                        onTabSelected: index => root.switchTab(index)
                    }

                    Item {
                        id: listContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        DragHandler {
                            id: swipeHandler
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false
                            onTranslationChanged: if (active) root.dragFrac = root.rubber(-translation.x / listContainer.width)
                            onActiveChanged: {
                                if (active) return;
                                const f = root.dragFrac;
                                let next = root.activeTab;
                                if (f > 0.22 && root.activeTab < 2) next++;
                                else if (f < -0.22 && root.activeTab > 0) next--;
                                // Hand the drag distance to the spring so the
                                // release continues from where the finger left.
                                pageP.value += f;
                                root.dragFrac = 0;
                                root.activeTab = next;
                                pageP.kick();
                            }
                        }

                        // ── Text ───────────────────────────────────────────
                        Item {
                            id: textPage
                            width: listContainer.width
                            height: listContainer.height
                            x: -48 * (root.pagePos - 0)
                            opacity: Math.max(0, Math.min(1, 1 - 1.4 * Math.abs(root.pagePos - 0)))
                            visible: opacity > 0.001
                            enabled: root.activeTab === 0

                            Rectangle { anchors.fill: parent; radius: 20; color: Local.ClipboardTheme.content }
                            ListView {
                                id: textList
                                anchors.fill: parent
                                clip: true
                                spacing: 0
                                boundsBehavior: Flickable.StopAtBounds
                                cacheBuffer: 0
                                reuseItems: true
                                model: ScriptModel { values: root.textModelArr; objectProp: "clipId" }
                                displaced: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }
                                delegate: Local.ClipboardTextEntry {
                                    required property var modelData
                                    controller: root
                                    itemData: modelData
                                    itemIndex: index
                                    itemCount: textList.count
                                    containerWidth: textList.width
                                }
                                Loader {
                                    anchors.centerIn: parent
                                    active: root.textModelArr.length === 0
                                    sourceComponent: emptyState
                                }
                            }
                            // Rows are rectangles; round the well's corners over them.
                            Local.CornerMask { anchors.fill: parent; radius: 20; color: Local.ClipboardTheme.panel }
                        }

                        // ── Images (real images only, no placeholder slots) ─
                        Item {
                            id: imagePage
                            width: listContainer.width
                            height: listContainer.height
                            x: -48 * (root.pagePos - 1)
                            opacity: Math.max(0, Math.min(1, 1 - 1.4 * Math.abs(root.pagePos - 1)))
                            visible: opacity > 0.001
                            enabled: root.activeTab === 1

                            GridView {
                                id: imageGrid
                                anchors.fill: parent
                                clip: true
                                cellWidth: width / 3
                                cellHeight: width / 3
                                boundsBehavior: Flickable.StopAtBounds
                                cacheBuffer: 0
                                reuseItems: true
                                model: ScriptModel { values: root.imageModelArr; objectProp: "clipId" }
                                displaced: Transition { NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic } }
                                delegate: Local.ClipboardImageTile {
                                    required property var modelData
                                    controller: root
                                    itemData: modelData
                                    itemIndex: index
                                    cellSize: imageGrid.cellWidth
                                }
                                Loader {
                                    anchors.centerIn: parent
                                    active: root.imageModelArr.length === 0
                                    sourceComponent: emptyState
                                }
                            }
                        }

                        // ── Favourites ─────────────────────────────────────
                        Item {
                            id: favPage
                            width: listContainer.width
                            height: listContainer.height
                            x: -48 * (root.pagePos - 2)
                            opacity: Math.max(0, Math.min(1, 1 - 1.4 * Math.abs(root.pagePos - 2)))
                            visible: opacity > 0.001
                            enabled: root.activeTab === 2

                            Rectangle { anchors.fill: parent; radius: 20; color: Local.ClipboardTheme.content }
                            ListView {
                                id: favList
                                anchors.fill: parent
                                clip: true
                                spacing: 0
                                boundsBehavior: Flickable.StopAtBounds
                                cacheBuffer: 0
                                reuseItems: true
                                model: ScriptModel { values: root.favModelArr; objectProp: "clipId" }
                                displaced: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }
                                delegate: Local.ClipboardFavoriteEntry {
                                    required property var modelData
                                    controller: root
                                    itemData: modelData
                                    itemIndex: index
                                    itemCount: favList.count
                                    containerWidth: favList.width
                                }
                                Loader {
                                    anchors.centerIn: parent
                                    active: root.favModelArr.length === 0
                                    sourceComponent: emptyState
                                }
                            }
                            Local.CornerMask { anchors.fill: parent; radius: 20; color: Local.ClipboardTheme.panel }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: emptyState
        Column {
            spacing: 8
            Local.Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "chat_bubble_outline"; size: 38; color: Local.ClipboardTheme.secondaryText }
            Local.M3Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing here yet"; color: Local.ClipboardTheme.secondaryText; font.pixelSize: 12 }
        }
    }
}
