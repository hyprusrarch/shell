import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "./" as Local
import "./themes.js" as ThemeDb

Item {
    id: launcherRoot

    function notifyClosed() {
        Quickshell.execDetached(["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf \"closed launcher\\n\" >> \"$runtime/quickshell/control\""]);
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: root
                required property ShellScreen modelData
                screen: modelData

                anchors { top: true; bottom: true; left: true; right: true }
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                color: "transparent"

                Shortcut {
                    sequence: "Esc"
                    onActivated: {
                        if (root.editMode) { root.editMode = false; }
                        else if (!outroAnim.running) { outroAnim.start(); }
                    }
                }

                // ── THEME ALIASES (so the rest of the file reads Theme.xxx) ──
                readonly property color bgMain:     Local.Theme.bgMain
                readonly property color bgDark:     Local.Theme.bgDark
                readonly property color clrText:    Local.Theme.textMain
                readonly property color subtext:    Local.Theme.textMuted
                readonly property color accent:     Local.Theme.accent
                readonly property color surface:    Local.Theme.border
                readonly property color overlay:    Qt.darker(Local.Theme.border, 1.35)
                readonly property color errorColor: Local.Theme.error

                readonly property string fileManager: "nautilus"

                // ── TABS (apps + Themes at end) ──
                readonly property var tabList: ["All", "Network", "Game", "System", "Utility", "Themes"]
                property int  activeTabIndex:    0
                property int  animatingTabIndex: -1
                property real swipeOffset:       0
                property bool editMode:          false
                property bool startupReady:       false
                property bool gridViewMode:      true
                property string calcResult: ""
                property string rawMathCmd: ""

                // ── CACHES ──
                property var cache_All:     null
                property var cache_Network: null
                property var cache_Game:    null
                property var cache_System:  null
                property var cache_Utility: null
                property var cache_Themes:  null
                property var cache_Order_All:     null
                property var cache_Order_Network: null
                property var cache_Order_Game:    null
                property var cache_Order_System:  null
                property var cache_Order_Utility: null

                function cacheForTab(idx) {
                    if (idx === 0) return root.cache_All;
                    if (idx === 1) return root.cache_Network;
                    if (idx === 2) return root.cache_Game;
                    if (idx === 3) return root.cache_System;
                    if (idx === 4) return root.cache_Utility;
                    return null;
                }
                function setCacheForTab(idx, val) {
                    if      (idx === 0) root.cache_All     = val;
                    else if (idx === 1) root.cache_Network = val;
                    else if (idx === 2) root.cache_Game    = val;
                    else if (idx === 3) root.cache_System  = val;
                    else if (idx === 4) root.cache_Utility = val;
                }
                function invalidateAllCaches() {
                    root.cache_All = null; root.cache_Network = null;
                    root.cache_Game = null; root.cache_System = null;
                    root.cache_Utility = null;
                    root.cache_Order_All = null; root.cache_Order_Network = null;
                    root.cache_Order_Game = null; root.cache_Order_System = null;
                    root.cache_Order_Utility = null;
                     // PERF: deferred — avoids blocking the render frame
                }

                // ── SNAP ANIM — render-thread friendly: animates swipeOffset which drives Loader x positions ──
                NumberAnimation {
                    id: snapAnim
                    target: root; property: "swipeOffset"
                    to: 0; duration: 280
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
                    onFinished: { root.animatingTabIndex = -1;  } // PERF: deferred gc after swipe
                }

                function switchTab(newIndex) {
                    if (newIndex === root.activeTabIndex) return;
                    if (newIndex < 0 || newIndex >= root.tabList.length) return;
                    if (!tabSwipeHandler.active) {
                        root.swipeOffset = newIndex > root.activeTabIndex
                            ? (gridArea.width + 48) : -(gridArea.width + 48);
                    }
                    root.animatingTabIndex = root.activeTabIndex;
                    root.activeTabIndex    = newIndex;
                    searchInput.text       = "";
                    snapAnim.restart();
                }

                // ── PERSISTENCE (same org/app as original shell) ──
                Settings {
                    id: appSettings
                    category: "Launcher"
                    property string savedOrder_All:     "[]"
                    property string savedOrder_Network: "[]"
                    property string savedOrder_Game:    "[]"
                    property string savedOrder_System:  "[]"
                    property string savedOrder_Utility: "[]"
                    property string hiddenApps:         "[]"
                    property string frequencyData:      "{}"
                    property bool   savedIsGridView:    true
                }

                Component.onCompleted: {
                    root.gridViewMode = appSettings.savedIsGridView;
                    root.startupReady = true;
                    searchInput.forceActiveFocus();
                    introAnim.start();
                }
                onGridViewModeChanged: { appSettings.savedIsGridView = root.gridViewMode; }

                // ── STABILITY GATE ──
                property bool listStabilized: false
                property int  lastAppCount:   -1
                Timer {
                    id: stabilityTimer
                    // PERF: repeat:false + manual restart — zero timer events after stabilization
                    interval: 80; repeat: false; running: true
                    onTriggered: {
                        const n = DesktopEntries.applications.values.length;
                        if (n > 0) {
                            if (n === root.lastAppCount) {
                                root.listStabilized = true;
                            } else { root.lastAppCount = n; stabilityTimer.start(); }
                        } else { stabilityTimer.start(); }
                    }
                }

                Timer { id: searchDebounce;  interval: 80;  running: false; onTriggered: rebuildTabModel(root.activeTabIndex) }
                Timer { id: themeDebounce;   interval: 80;  running: false; onTriggered: rebuildThemeModel(searchInput.text) }

                Process { id: adhocProcess }
                // ── GRACEFUL CLOSE WATCHER ──
                Process {
                    id: closeWatcher
                    running: true
                    // Listens for IPC commands from shell.qml / Bar toggle button.
                    // CLOSE  → run the outro animation; the shared shell unloads this panel afterwards.
                    command: ["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; exec tail -n 0 -F \"$runtime/quickshell/launcher.cmd\""]
                    stdout: SplitParser {
                        onRead: function(msg) {
                            const cmd = msg.trim();
                            if (cmd === "CLOSE" && root.startupReady && !outroAnim.running) {
                                outroAnim.start();
                            }
                        }
                    }
                }

                // ── ORDER CACHE MAP ──
                readonly property var _orderCacheMap: ({
                    "All":     function() { return { get: function() { return root.cache_Order_All; },  set: function(v) { root.cache_Order_All = v; },  setting: function() { return appSettings.savedOrder_All; }  }; },
                    "Network": function() { return { get: function() { return root.cache_Order_Network; }, set: function(v) { root.cache_Order_Network = v; }, setting: function() { return appSettings.savedOrder_Network; } }; },
                    "Game":    function() { return { get: function() { return root.cache_Order_Game; },   set: function(v) { root.cache_Order_Game = v; },   setting: function() { return appSettings.savedOrder_Game; }   }; },
                    "System":  function() { return { get: function() { return root.cache_Order_System; }, set: function(v) { root.cache_Order_System = v; }, setting: function() { return appSettings.savedOrder_System; } }; },
                    "Utility": function() { return { get: function() { return root.cache_Order_Utility; },set: function(v) { root.cache_Order_Utility = v; },setting: function() { return appSettings.savedOrder_Utility; }}; }
                })

                function savedOrderForTab(tabName) {
                    const entry = _orderCacheMap[tabName];
                    if (!entry) return [];
                    const e = entry();
                    if (e.get() === null) {
                        try { e.set(JSON.parse(e.setting())); } catch(err) { e.set([]); }
                    }
                    return e.get();
                }
                // ── HELPERS (saveFreq, saveOrderForTab, hideApp) ──
                function saveFreq(appName) {
                    var freqs = {};
                    try { freqs = JSON.parse(appSettings.frequencyData); } catch(e) {}
                    freqs[appName] = (freqs[appName] || 0) + 1;
                    appSettings.frequencyData = JSON.stringify(freqs);
                    root.cache_All = null; root.cache_Network = null;
                    root.cache_Game = null; root.cache_System = null;
                    root.cache_Utility = null;
                }
                function saveOrderForTab(tabIdx) {
                    var mdl = modelForTab(tabIdx); var order = [];
                    for (var i = 0; i < mdl.count; i++) {
                        var item = mdl.get(i);
                        if (!item.isCustom) order.push(item.appName);
                    }
                    var json = JSON.stringify(order); var name = root.tabList[tabIdx];
                    if (name === "All")     { appSettings.savedOrder_All     = json; root.cache_Order_All     = order; root.cache_All     = null; }
                    if (name === "Network") { appSettings.savedOrder_Network = json; root.cache_Order_Network = order; root.cache_Network = null; }
                    if (name === "Game")    { appSettings.savedOrder_Game    = json; root.cache_Order_Game    = order; root.cache_Game    = null; }
                    if (name === "System")  { appSettings.savedOrder_System  = json; root.cache_Order_System  = order; root.cache_System  = null; }
                    if (name === "Utility") { appSettings.savedOrder_Utility = json; root.cache_Order_Utility = order; root.cache_Utility = null; }
                }
                function hideApp(appName) {
                    var hidden = [];
                    try { hidden = JSON.parse(appSettings.hiddenApps); } catch(e) {}
                    if (hidden.indexOf(appName) === -1) { hidden.push(appName); appSettings.hiddenApps = JSON.stringify(hidden); }
                    invalidateAllCaches();
                }

                // ── APP MODELS ──
                ListModel { id: model_All     }
                ListModel { id: model_Network }
                ListModel { id: model_Game    }
                ListModel { id: model_System  }
                ListModel { id: model_Utility }
                ListModel { id: model_Themes  }

                function modelForTab(idx) {
                    if (idx === 0) return model_All;
                    if (idx === 1) return model_Network;
                    if (idx === 2) return model_Game;
                    if (idx === 3) return model_System;
                    if (idx === 4) return model_Utility;
                    if (idx === 5) return model_Themes;
                    return model_All;
                }

                // ── THEME MODEL REBUILD (luminance-sorted, cached) ──
                function rebuildThemeModel(rawQuery) {
                    var q = rawQuery.toLowerCase().replace(/ /g, "_");

                    if (root.cache_Themes === null) {
                        var arr = [];
                        for (var t in ThemeDb.themes) {
                            var bg = String(ThemeDb.themes[t].bgMain).replace('#', '');
                            var rr = parseInt(bg.substring(0,2), 16);
                            var gg = parseInt(bg.substring(2,4), 16);
                            var bb = parseInt(bg.substring(4,6), 16);
                            arr.push({ name: t, lum: 0.299*rr + 0.587*gg + 0.114*bb });
                        }
                        arr.sort(function(a, b) { return a.lum - b.lum; });

                        var batch = [];
                        for (var i = 0; i < arr.length; i++) {
                            var n = arr[i].name;
                            var d = ThemeDb.themes[n];
                            batch.push({ themeName: n, bgMain: d.bgMain, bgDark: d.bgDark,
                                textMain: d.textMain, accent: d.accent, accentAlt: d.accentAlt,
                                error: d.error, warning: d.warning, success: d.success, info: d.info });
                        }
                        root.cache_Themes = batch;
                    }

                    model_Themes.clear();
                    if (q === "") {
                        model_Themes.append(root.cache_Themes);
                    } else {
                        var filtered = [];
                        for (var j = 0; j < root.cache_Themes.length; j++) {
                            if (root.cache_Themes[j].themeName.indexOf(q) !== -1)
                                filtered.push(root.cache_Themes[j]);
                        }
                        model_Themes.append(filtered);
                    }
                }

                // ── APP MODEL REBUILD ──
                function rebuildTabModel(tabIdx) {
                    if (!root.listStabilized) return;

                    if (tabIdx === 5) { rebuildThemeModel(searchInput.text); return; }

                    const tabName = root.tabList[tabIdx];
                    const rawText = (tabIdx === root.activeTabIndex) ? searchInput.text : "";
                    const query   = rawText.toLowerCase();

                    if (tabIdx === root.activeTabIndex) { root.calcResult = ""; root.rawMathCmd = ""; }

                    if (query === "") {
                        var cached = cacheForTab(tabIdx);
                        if (cached !== null) { var mc = modelForTab(tabIdx); mc.clear(); mc.append(cached); return; }
                    }

                    var allApps = DesktopEntries.applications.values || [];
                    var hidden  = [];
                    try { hidden = JSON.parse(appSettings.hiddenApps); } catch(e) {}

                    var items = [];

                    var isExplicitCalc = rawText.startsWith("=");
                    var isMath = /^[\d\s\+\-\*\/\(\)\.]+$/.test(rawText) && /[\+\-\*\/]/.test(rawText) && /\d/.test(rawText);
                    if (tabIdx === root.activeTabIndex && (isExplicitCalc || isMath)) {
                        var mathStr = isExplicitCalc ? rawText.substring(1).trim() : rawText.trim();
                        if (mathStr.length > 0) {
                            try {
                                if (/^[0-9\+\-\*\/\(\)\.\s]*$/.test(mathStr)) {
                                    var result = eval(mathStr);
                                    if (result !== undefined && !isNaN(result) && result !== Infinity) {
                                        root.calcResult = "= " + result;
                                        root.rawMathCmd = result.toString();
                                        if (isExplicitCalc) return;
                                    }
                                }
                            } catch(e) {}
                        }
                    }

                    if (rawText.startsWith(":") && tabIdx === root.activeTabIndex) {
                        var cmd = rawText.substring(1).trim();
                        if (cmd.length > 0) {
                            items.push({ appName: "Run: " + cmd, appIcon: "foot",
                                isCustom: true, itemType: "command", itemCmd: cmd, itemPath: "" });
                            modelForTab(tabIdx).clear(); modelForTab(tabIdx).append(items);
                        }
                        return;
                    }

                    if ((rawText.startsWith("/") || rawText.startsWith("~")) && tabIdx === root.activeTabIndex) {
                        items.push({ appName: "Open: " + rawText, appIcon: "folder",
                            isCustom: true, itemType: "path", itemCmd: "", itemPath: rawText });
                        modelForTab(tabIdx).clear(); modelForTab(tabIdx).append(items);
                        return;
                    }

                    var filtered = [];
                    for (var i = 0; i < allApps.length; i++) {
                        var app = allApps[i];
                        if (app.noDisplay) continue;
                        if (hidden.indexOf(app.name) !== -1) continue;
                        if (tabName !== "All") {
                            var cats = app.categories || []; var hit = false;
                            for (var c = 0; c < cats.length; c++) {
                                if (cats[c].toLowerCase().includes(tabName.toLowerCase())) { hit = true; break; }
                            }
                            if (!hit) continue;
                        }
                        filtered.push(app);
                    }

                    var savedOrder = savedOrderForTab(tabName);
                    var appMap = {};
                    for (var j = 0; j < filtered.length; j++) appMap[filtered[j].name] = filtered[j];
                    var ordered = []; var used = {};
                    for (var k = 0; k < savedOrder.length; k++) {
                        var sn = savedOrder[k];
                        if (appMap[sn] && !used[sn]) { ordered.push(appMap[sn]); used[sn] = true; }
                    }
                    var remaining = [];
                    for (var m = 0; m < filtered.length; m++) { if (!used[filtered[m].name]) remaining.push(filtered[m]); }
                    var freqs = {};
                    try { freqs = JSON.parse(appSettings.frequencyData); } catch(e) {}
                    remaining.sort(function(a, b) {
                        var fa = freqs[a.name] || 0; var fb = freqs[b.name] || 0;
                        if (fb !== fa) return fb - fa;
                        return a.name.localeCompare(b.name);
                    });
                    for (var r = 0; r < remaining.length; r++) ordered.push(remaining[r]);

                    for (var p = 0; p < ordered.length; p++) {
                        var a = ordered[p];
                        if (query !== "") {
                            var nm = a.name    && a.name.toLowerCase().includes(query);
                            var cm = a.comment && a.comment.toLowerCase().includes(query);
                            if (!nm && !cm) continue;
                        }
                        items.push({ appName: a.name, appIcon: a.icon || "",
                            isCustom: false, itemType: "", itemCmd: "", itemPath: "" });
                    }

                    if (query.length > 0 && tabIdx === root.activeTabIndex) {
                        items.push({ appName: "Search: '" + rawText + "'", appIcon: "system-search",
                            isCustom: true, itemType: "search", itemCmd: rawText, itemPath: "" });
                    }

                    if (query === "") setCacheForTab(tabIdx, items);

                    var mdl = modelForTab(tabIdx);
                    mdl.clear(); mdl.append(items);
                }

                // ── LAUNCH ──
                function launchItem(isCustom, appName, itemType, itemCmd, itemPath) {
                    if (root.editMode) return;
                    if (isCustom) {
                        let execStr = "";
                        if (itemType === "search") {
                            const url = "https://www.google.com/search?q=" + encodeURIComponent(itemCmd);
                            execStr = "xdg-open '" + url.replace(/'/g, "'\\''") + "'";
                        } else if (itemType === "command") {
                            execStr = "foot bash -c '" + itemCmd.replace(/'/g, "'\\''") + "; exec bash'";
                        } else if (itemType === "path") {
                            const rp = itemPath;
                            const fp = rp.startsWith("~")
                                ? "$HOME/\"" + rp.substring(1).replace(/^\//, "").replace(/"/g, '\\"') + "\""
                                : "\"" + rp.replace(/"/g, '\\"') + "\"";
                            execStr = "bash -c '" + (root.fileManager + " " + fp).replace(/'/g, "'\\''") + "'";
                        }
                        adhocProcess.command = ["hyprctl", "dispatch", "exec", "--", execStr];
                        adhocProcess.running = true;
                    } else {
                        root.saveFreq(appName);
                        const apps = DesktopEntries.applications.values;
                        for (let i = 0; i < apps.length; i++) {
                            if (apps[i].name === appName) { apps[i].execute(); break; }
                        }
                    }
                    if (!outroAnim.running) outroAnim.start();
                }

                Connections {
                    target: root
                    function onListStabilizedChanged() {
                        if (!root.listStabilized) return;
                        for (let i = 0; i < root.tabList.length - 1; i++) {
                            const ldr = tabLoadersRepeater.itemAt(i);
                            if (ldr && ldr.active && !ldr.isThemeTab)
                                rebuildTabModel(i);
                        }
                    }
                }

                // ── DISMISS ──
                MouseArea {
                    anchors.fill: parent
                    onClicked: { if (root.editMode) root.editMode = false; else if (!outroAnim.running) outroAnim.start(); }
                }

                // ── SURFACE — expressive enter + fast exit ──
                // Intro: scale uses subtle overshoot; opacity uses enter easing.
                // Outro: scale and opacity use exit easing.

                ParallelAnimation {
                    id: introAnim
                    readonly property bool running: introScaleAnim.running || introOpacityAnim.running
                    function start() {
                        introAnim.restart()
                    }

                    NumberAnimation {
                        id: introScaleAnim
                        target: launcherSurface; property: "scale"
                        from: 0.92; to: 1.0
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.34, 1.56, 0.64, 1.0, 1.0, 1.0]
                    }
                    NumberAnimation {
                        id: introOpacityAnim
                        target: launcherSurface; property: "opacity"
                        from: 0; to: 1
                        duration: 180
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
                    }
                }

                ParallelAnimation {
                    id: outroAnim
                    readonly property bool running: outroScaleAnim.running || outroOpacityAnim.running
                    function start() {
                        outroAnim.restart()
                    }
                    onFinished: {
                        launcherRoot.notifyClosed();
                    }

                    NumberAnimation {
                        id: outroScaleAnim
                        target: launcherSurface; property: "scale"
                        from: 1.0; to: 0.96
                        duration: 140
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                    }
                    NumberAnimation {
                        id: outroOpacityAnim
                        target: launcherSurface; property: "opacity"
                        from: 1; to: 0
                        duration: 160
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
                    }
                }

                Rectangle {
                    id: launcherSurface
                    anchors { top: parent.top; left: parent.left; topMargin: 12; leftMargin: 12 }
                    width: 768; height: 518
                    opacity: 0
                    transformOrigin: Item.TopLeft
                    color: root.bgMain; radius: 30

                    MouseArea { anchors.fill: parent; onClicked: function(m) { m.accepted = true; } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 26
                        spacing: 16

                        // ── SEARCH BAR + EDIT ICON (conjoined semi-circles) ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52

                            Rectangle {
                                anchors.fill: parent
                                radius: 29
                                color: root.surface
                            Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: parent.width - 52
                                radius: 26
                                Rectangle {
                                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                                    width: 26; color: parent.color
                                }
                                color: (searchInput.activeFocus && !root.editMode && root.startupReady)
                                       ? root.overlay
                                       : (root.editMode ? Qt.rgba(0.27, 0.28, 0.35, 0.6) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Rectangle {
                                anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 52 }
                                width: 1; height: 30
                                color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            TextField {
                                id: searchInput
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: 52 }
                                font.pixelSize: 17; color: root.clrText
                                placeholderText: root.editMode ? "Edit mode — drag to reorder, hold ✕ to exit"
                                    : root.activeTabIndex === 5 ? "Search themes..."
                                    : "Search apps..."
                                placeholderTextColor: root.subtext
                                leftPadding: 22; rightPadding: 16
                                enabled: !root.editMode
                                background: Item {}

                                onTextChanged: {
                                    if (root.activeTabIndex === 5) themeDebounce.restart();
                                    else searchDebounce.restart();
                                }

                                Keys.onPressed: function(event) {
                                    var activeLoader = tabLoadersRepeater.itemAt(root.activeTabIndex);
                                    if (!activeLoader || !activeLoader.item) return;

                                    var currentView = root.gridViewMode
                                        ? activeLoader.item.gridView
                                        : activeLoader.item.listView;
                                    if (!currentView) return;

                                    if (event.key === Qt.Key_Up) {
                                        if (root.gridViewMode) currentView.moveCurrentIndexUp();
                                        else currentView.decrementCurrentIndex();
                                        currentView.positionViewAtIndex(currentView.currentIndex, GridView.Contain);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down) {
                                        if (root.gridViewMode) currentView.moveCurrentIndexDown();
                                        else currentView.incrementCurrentIndex();
                                        currentView.positionViewAtIndex(currentView.currentIndex, GridView.Contain);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Left && root.gridViewMode) {
                                        currentView.moveCurrentIndexLeft();
                                        currentView.positionViewAtIndex(currentView.currentIndex, GridView.Contain);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Right && root.gridViewMode) {
                                        currentView.moveCurrentIndexRight();
                                        currentView.positionViewAtIndex(currentView.currentIndex, GridView.Contain);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.calcResult !== "" && root.activeTabIndex !== 5) {
                                            adhocProcess.running = false;
                                            adhocProcess.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy", "qs-copy-math", root.rawMathCmd];
                                            adhocProcess.running = true;
                                            if (!outroAnim.running) outroAnim.start();
                                        } else {
                                            var cur = currentView.currentIndex;
                                            var mdl = modelForTab(root.activeTabIndex);
                                            var target = (cur >= 0 && cur < mdl.count) ? mdl.get(cur)
                                                       : (mdl.count === 1 ? mdl.get(0) : null);
                                            if (target)
                                                launchItem(target.isCustom, target.appName,
                                                           target.itemType, target.itemCmd, target.itemPath);
                                        }
                                        event.accepted = true;
                                    }
                                }

                            }

                            Item {
                                id: viewToggleBtn
                                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                                width: 52

                                Rectangle {
                                    anchors.fill: parent
                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: 26; color: parent.color
                                    }
                                    radius: 26
                                    color: viewToggleHover.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.editMode
                                    text: "✕"
                                    color: root.errorColor
                                    font.pixelSize: 17; font.bold: true
                                    opacity: viewToggleHover.containsMouse ? 1.0 : 0.75
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !root.editMode
                                    text: root.gridViewMode ? "󰕰" : "󰒏"
                                    color: root.subtext
                                    font.pixelSize: 16
                                    opacity: viewToggleHover.containsMouse ? 1.0 : 0.65
                                    Behavior on color   { ColorAnimation  { duration: 120 } }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: viewToggleHover; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.editMode) {
                                            root.editMode = false;
                                        } else {
                                            root.gridViewMode = !root.gridViewMode;
                                             // PERF: deferred
                                        }
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // ── TAB CHIPS ──
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 37
                            Layout.minimumHeight:   37
                            Layout.maximumHeight:   37
                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                            Repeater {
                                model: root.tabList
                                delegate: Rectangle {
                                    readonly property bool isActive: root.activeTabIndex === index
                                    property bool hovered: false
                                    implicitWidth: tabLbl.implicitWidth + 24; height: 37
                                    color: isActive ? root.surface : (hovered ? Qt.rgba(1,1,1,0.05) : "transparent")
                                    radius: 19
                                    opacity: (root.editMode && index !== root.activeTabIndex) ? 0.35 : 1.0
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        id: tabLbl
                                        text: modelData === "Network" ? "Web" : modelData
                                        anchors.centerIn: parent
                                        color: parent.isActive ? root.accent : root.subtext
                                        font.pixelSize: 14
                                        font.weight: parent.isActive ? Font.DemiBold : Font.Normal
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true
                                        enabled: !root.editMode || index === root.activeTabIndex
                                        onClicked: root.switchTab(index)
                                        onEntered: parent.hovered = true
                                        onExited:  parent.hovered = false
                                    }
                                }
                            }
                            }
                        }

                        // ── CALCULATOR STRIP (below tabs) ──
                        Loader {
                            Layout.fillWidth: true
                            Layout.preferredHeight: active ? 52 : 0
                            active: root.calcResult !== ""
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                            sourceComponent: Component {
                                Rectangle {
                                    color: root.surface; radius: 13; clip: true
                                    Behavior on color { ColorAnimation { duration: 300 } }

                                    Text {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 19 }
                                        text: root.calcResult
                                        color: root.accent; font.pixelSize: 22; font.weight: Font.Bold
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Rectangle {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 11 }
                                        color: root.overlay; radius: 6; width: 56; height: 22
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                        Text { anchors.centerIn: parent; text: "⏎ copy"; color: root.subtext; font.pixelSize: 11; font.weight: Font.Medium }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            adhocProcess.running = false;
                                            adhocProcess.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy", "qs-copy-math", root.rawMathCmd];
                                            adhocProcess.running = true;
                                            if (!outroAnim.running) outroAnim.start();
                                        }
                                    }
                                }
                            }
                        }

                        // ── SWIPE AREA ──
                        Item {
                            id: gridArea
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                            DragHandler {
                                id: tabSwipeHandler
                                target: null; enabled: !root.editMode
                                xAxis.enabled: true; yAxis.enabled: false
                                property real lastDx: 0
                                onTranslationChanged: { if (active) { root.swipeOffset = translation.x; lastDx = translation.x; } }
                                onActiveChanged: {
                                    if (!active) {
                                        var dx = lastDx;
                                        var threshold = (gridArea.width + 48) / 2;
                                        var tgt = root.activeTabIndex;
                                        if (dx < -threshold && root.activeTabIndex < root.tabList.length - 1) tgt = root.activeTabIndex + 1;
                                        else if (dx > threshold && root.activeTabIndex > 0) tgt = root.activeTabIndex - 1;
                                        if (tgt !== root.activeTabIndex) {
                                            root.swipeOffset += tgt > root.activeTabIndex ? (gridArea.width + 48) : -(gridArea.width + 48);
                                            root.animatingTabIndex = root.activeTabIndex;
                                            root.activeTabIndex    = tgt;
                                            searchInput.text       = "";
                                        }
                                        snapAnim.restart(); lastDx = 0;
                                    }
                                }
                            }

                            // ── APP PANE COMPONENT (grid + list) ──
                            Component {
                                id: appPaneComp
                                Item {
                                    id: tabPane
                                    property int myTabIdx: 0
                                    property alias gridView: tabGrid
                                    property alias listView: tabList
                                    anchors.fill: parent

                                    // ── GRID VIEW ──
                                    GridView {
                                        id: tabGrid
                                        anchors.fill: parent; clip: true
                                        visible: root.gridViewMode
                                        model: root.gridViewMode ? modelForTab(tabPane.myTabIdx) : null
                                        reuseItems: true
                                        cacheBuffer: 0 // PERF: no off-screen delegate pre-instantiation
                                        cellWidth: Math.floor(width / 6); cellHeight: 114
                                        boundsBehavior: Flickable.StopAtBounds
                                        keyNavigationEnabled: false
                                        currentIndex: 0
                                        highlight: Rectangle {
                                            width: tabGrid.cellWidth - 10; height: tabGrid.cellHeight - 10
                                            radius: 13; color: Qt.rgba(1,1,1,0.08)
                                            x: tabGrid.currentItem ? tabGrid.currentItem.x + 5 : 0
                                            y: tabGrid.currentItem ? tabGrid.currentItem.y + 5 : 0
                                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline
                                                              easing.bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                                            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.BezierSpline
                                                              easing.bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                                            z: 10; visible: tabGrid.count > 0
                                        }
                                        highlightFollowsCurrentItem: false
                                        onModelChanged: currentIndex = 0
                                        onCountChanged: { if (count === 0) { currentIndex = 0; } else if (currentIndex >= count) { currentIndex = count - 1; } }
                                        moveDisplaced: Transition {
                                            NumberAnimation {
                                                properties: "x,y"; duration: 150
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
                                            }
                                        }
                                        delegate: Item {
                                            id: gridDelegate
                                            width: GridView.view ? GridView.view.cellWidth : 0
                                            height: GridView.view ? GridView.view.cellHeight : 0
                                            property int visualIndex: index
                                            z: gridDrag.drag.active ? 100 : 1
                                            opacity: 0
                                            scale: 0.75

                                            // Staggered appear: each icon scales+fades in offset by index*15ms (max 240ms)
                                            SequentialAnimation {
                                                id: gAppear
                                                property int delay: 0
                                                PauseAnimation { duration: gAppear.delay }
                                                ParallelAnimation {
                                                    NumberAnimation {
                                                        target: gridDelegate; property: "opacity"
                                                        from: 0; to: 1; duration: 280
                                                        easing.type: Easing.BezierSpline
                                                        easing.bezierCurve: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
                                                    }
                                                    NumberAnimation {
                                                        target: gridDelegate; property: "scale"
                                                        from: 0.75; to: 1.0; duration: 280
                                                        easing.type: Easing.BezierSpline
                                                        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                                                    }
                                                }
                                            }

                                            Component.onCompleted: {
                                                gAppear.delay = Math.min(index * 15, 240);
                                                gAppear.start();
                                            }
                                            Component.onDestruction: gAppear.stop()

                                            // POOL: stop animations, reset appear state, null icon source
                                            GridView.onPooled: {
                                                gAppear.stop();
                                                gridDelegate.opacity = 0;
                                                gridDelegate.scale   = 0.75;
                                                jiggleAnim.running   = false;
                                                gridIcon.source      = "";
                                            }
                                            // REUSED: re-run appear, restore icon and jiggle
                                            GridView.onReused: {
                                                gAppear.delay = Math.min(index * 15, 240);
                                                gAppear.start();
                                                gridIcon.source    = model.appIcon ? Quickshell.iconPath(model.appIcon, true) : "";
                                                jiggleAnim.running = root.editMode && !gridDrag.drag.active;
                                            }
                                            DropArea {
                                                anchors.fill: parent; visible: !model.isCustom
                                                onEntered: function(drag) {
                                                    var from = drag.source.visualIndex; var to = gridDelegate.visualIndex;
                                                    if (from !== undefined && to !== undefined && from !== to)
                                                        modelForTab(tabPane.myTabIdx).move(from, to, 1);
                                                }
                                            }
                                            Rectangle {
                                                id: gridCard
                                                x: 5; y: 5
                                                width: gridDelegate.width - 10; height: gridDelegate.height - 10
                                                radius: 14
                                                color: gridDrag.containsMouse && !root.editMode ? root.surface : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on x { enabled: !gridDrag.drag.active; NumberAnimation { duration: 150; easing.type: Easing.BezierSpline
                                                                            easing.bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                                                Behavior on y { enabled: !gridDrag.drag.active; NumberAnimation { duration: 150; easing.type: Easing.BezierSpline
                                                                            easing.bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                                                property real pressX: width / 2; property real pressY: height / 2
                                                Drag.active: gridDrag.drag.active; Drag.source: gridDelegate
                                                Drag.hotSpot.x: gridCard.pressX; Drag.hotSpot.y: gridCard.pressY
                                                states: State {
                                                    when: gridDrag.drag.active
                                                    ParentChange { target: gridCard; parent: tabGrid }
                                                    PropertyChanges { target: gridCard; z: 1000; opacity: 0.88; scale: 1.06 }
                                                }
                                                RotationAnimation on rotation {
                                                    id: jiggleAnim
                                                    running: root.editMode && !gridDrag.drag.active
                                                    loops: Animation.Infinite; from: -1.2; to: 1.2
                                                    duration: 220 + (index % 5) * 30; easing.type: Easing.SineCurve
                                                }
                                                Behavior on rotation { enabled: !root.editMode; NumberAnimation { duration: 120 } }
                                                Column {
                                                    anchors.centerIn: parent; spacing: 11
                                                    Item {
                                                        width: 38; height: 38
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        scale: gridDrag.containsMouse && !root.editMode ? 1.10 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.BezierSpline
                                                            easing.bezierCurve: [0.34, 1.56, 0.64, 1.0, 1.0, 1.0] } }
                                                        Image {
                                                            id: gridIcon
                                                            anchors.fill: parent; sourceSize: Qt.size(77, 77)
                                                            fillMode: Image.PreserveAspectFit; asynchronous: true
                                                            source: model.appIcon ? Quickshell.iconPath(model.appIcon, true) : ""
                                                            opacity: status === Image.Ready ? 1.0 : 0.0
                                                            Behavior on opacity { NumberAnimation { duration: 80 } }
                                                            Component.onDestruction: { source = ""; }
                                                        }
                                                    }
                                                    Text {
                                                        text: model.appName; color: root.clrText
                                                        font.pixelSize: 13; font.weight: Font.Medium
                                                        width: tabGrid.cellWidth - 22; elide: Text.ElideRight
                                                        horizontalAlignment: Text.AlignHCenter
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        wrapMode: Text.WordWrap; maximumLineCount: 2
                                                    }
                                                }
                                                MouseArea {
                                                    id: gridDrag; anchors.fill: parent; hoverEnabled: true
                                                    drag.target: (root.editMode && !model.isCustom) ? gridCard : null
                                                    drag.axis: Drag.XAndYAxis
                                                    cursorShape: root.editMode && !model.isCustom ? Qt.OpenHandCursor : Qt.ArrowCursor
                                                    Timer {
                                                        id: gridHoldTimer; interval: 500; repeat: false
                                                        onTriggered: { if (!root.editMode && !model.isCustom) root.editMode = true; }
                                                    }
                                                    onPressed: function(mouse) {
                                                        if (!root.editMode && !model.isCustom) gridHoldTimer.start();
                                                        if (root.editMode && !model.isCustom) {
                                                            gridHoldTimer.stop();
                                                            gridCard.pressX = mouse.x; gridCard.pressY = mouse.y;
                                                            cursorShape = Qt.ClosedHandCursor;
                                                        }
                                                    }
                                                    onReleased: {
                                                        gridHoldTimer.stop();
                                                        if (root.editMode && !model.isCustom) {
                                                            cursorShape = Qt.OpenHandCursor;
                                                            gridCard.x = 5; gridCard.y = 5;
                                                            saveOrderForTab(tabPane.myTabIdx);
                                                            setCacheForTab(tabPane.myTabIdx, null);
                                                        }
                                                    }
                                                    onCanceled: gridHoldTimer.stop()
                                                    onClicked: {
                                                        if (!root.editMode) {
                                                            tabGrid.currentIndex = index;
                                                            searchInput.forceActiveFocus();
                                                        }
                                                    }
                                                    onDoubleClicked: {
                                                        if (!root.editMode)
                                                            launchItem(model.isCustom, model.appName,
                                                                       model.itemType, model.itemCmd, model.itemPath);
                                                    }
                                                }
                                                Rectangle {
                                                    width: 22; height: 22; radius: 11; color: root.errorColor
                                                    visible: root.editMode && !model.isCustom
                                                    anchors { top: parent.top; right: parent.right; topMargin: -5; rightMargin: -5 }
                                                    z: 20
                                                    Text { text: "✕"; anchors.centerIn: parent; color: root.bgMain; font.pixelSize: 10; font.bold: true }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.hideApp(model.appName);
                                                            modelForTab(tabPane.myTabIdx).remove(index);
                                                            saveOrderForTab(tabPane.myTabIdx);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── LIST VIEW ──
                                    ListView {
                                        id: tabList
                                        anchors.fill: parent; clip: true
                                        visible: !root.gridViewMode
                                        model: !root.gridViewMode ? modelForTab(tabPane.myTabIdx) : null
                                        reuseItems: true
                                        cacheBuffer: 0 // PERF: no off-screen delegate pre-instantiation
                                        boundsBehavior: Flickable.StopAtBounds
                                        keyNavigationEnabled: false
                                        currentIndex: 0
                                        onModelChanged: currentIndex = 0
                                        onCountChanged: { if (count === 0) { currentIndex = 0; } else if (currentIndex >= count) { currentIndex = count - 1; } }
                                        moveDisplaced: Transition {
                                            NumberAnimation {
                                                properties: "x,y"; duration: 150
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
                                            }
                                        }
                                        delegate: Item {
                                            id: listDelegate
                                            width: ListView.view ? ListView.view.width : 0
                                            height: 56
                                            property int visualIndex: index
                                            z: listDrag.drag.active ? 100 : 1

                                            ListView.onPooled:  { listIcon.source = ""; }
                                            ListView.onReused:  { listIcon.source = model.appIcon ? Quickshell.iconPath(model.appIcon, true) : ""; }
                                            DropArea {
                                                anchors.fill: parent; visible: !model.isCustom
                                                onEntered: function(drag) {
                                                    var from = drag.source.visualIndex; var to = listDelegate.visualIndex;
                                                    if (from !== undefined && to !== undefined && from !== to)
                                                        modelForTab(tabPane.myTabIdx).move(from, to, 1);
                                                }
                                            }
                                            Rectangle {
                                                id: listCard
                                                x: 0; y: 2
                                                width: listDelegate.width; height: listDelegate.height - 5
                                                radius: 10
                                                color: listDrag.containsMouse && !root.editMode ? root.surface : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on y { enabled: !listDrag.drag.active; NumberAnimation { duration: 150; easing.type: Easing.BezierSpline
                                                                        easing.bezierCurve: [0.3, 0.0, 0.0, 1.0, 1.0, 1.0] } }
                                                property real pressX: width / 2; property real pressY: height / 2
                                                Drag.active: listDrag.drag.active; Drag.source: listDelegate
                                                Drag.hotSpot.x: listCard.pressX; Drag.hotSpot.y: listCard.pressY
                                                states: State {
                                                    when: listDrag.drag.active
                                                    ParentChange { target: listCard; parent: tabList }
                                                    PropertyChanges { target: listCard; z: 1000; opacity: 0.88; scale: 1.02 }
                                                }
                                                Row {
                                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                    anchors.leftMargin: 13; anchors.rightMargin: 13; spacing: 13
                                                    Image {
                                                        id: listIcon
                                                        width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter
                                                        sourceSize: Qt.size(53, 53)
                                                        fillMode: Image.PreserveAspectFit; asynchronous: true
                                                        source: model.appIcon ? Quickshell.iconPath(model.appIcon, true) : ""
                                                        opacity: status === Image.Ready ? 1.0 : 0.0
                                                        Behavior on opacity { NumberAnimation { duration: 80 } }
                                                        Component.onDestruction: { source = ""; }
                                                    }
                                                    Text {
                                                        text: model.appName; color: root.clrText
                                                        font.pixelSize: 14; font.weight: Font.Medium
                                                        elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 13 - parent.spacing
                                                    }
                                                }
                                                MouseArea {
                                                    id: listDrag; anchors.fill: parent; hoverEnabled: true
                                                    drag.target: (root.editMode && !model.isCustom) ? listCard : null
                                                    drag.axis: Drag.YAxis
                                                    cursorShape: root.editMode && !model.isCustom ? Qt.OpenHandCursor : Qt.ArrowCursor
                                                    Timer {
                                                        id: listHoldTimer; interval: 500; repeat: false
                                                        onTriggered: { if (!root.editMode && !model.isCustom) root.editMode = true; }
                                                    }
                                                    onPressed: function(mouse) {
                                                        if (!root.editMode && !model.isCustom) listHoldTimer.start();
                                                        if (root.editMode && !model.isCustom) {
                                                            listHoldTimer.stop();
                                                            listCard.pressX = mouse.x; listCard.pressY = mouse.y;
                                                            cursorShape = Qt.ClosedHandCursor;
                                                        }
                                                    }
                                                    onReleased: {
                                                        listHoldTimer.stop();
                                                        if (root.editMode && !model.isCustom) {
                                                            cursorShape = Qt.OpenHandCursor;
                                                            listCard.y = 2;
                                                            saveOrderForTab(tabPane.myTabIdx);
                                                            setCacheForTab(tabPane.myTabIdx, null);
                                                        }
                                                    }
                                                    onCanceled: listHoldTimer.stop()
                                                    onClicked: {
                                                        if (!root.editMode) {
                                                            tabList.currentIndex = index;
                                                            searchInput.forceActiveFocus();
                                                        }
                                                    }
                                                    onDoubleClicked: {
                                                        if (!root.editMode)
                                                            launchItem(model.isCustom, model.appName,
                                                                       model.itemType, model.itemCmd, model.itemPath);
                                                    }
                                                }
                                                Rectangle {
                                                    width: 22; height: 22; radius: 11; color: root.errorColor
                                                    visible: root.editMode && !model.isCustom
                                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 5 }
                                                    z: 20
                                                    Text { text: "✕"; anchors.centerIn: parent; color: root.bgMain; font.pixelSize: 10; font.bold: true }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.hideApp(model.appName);
                                                            modelForTab(tabPane.myTabIdx).remove(index);
                                                            saveOrderForTab(tabPane.myTabIdx);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── THEME GRID COMPONENT ──
                            Component {
                                id: themePaneComp
                                GridView {
                                    id: themeGrid
                                    anchors.fill: parent; clip: true
                                    cellWidth: Math.floor(width / 3); cellHeight: 84
                                    model: model_Themes
                                    reuseItems: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Item {
                                        width: themeGrid.cellWidth; height: themeGrid.cellHeight

                                        readonly property string themeAccent:    model.accent    || ""
                                        readonly property string themeAccentAlt: model.accentAlt || ""
                                        readonly property string themeWarning:   model.warning   || ""
                                        readonly property string themeError:     model.error     || ""
                                        readonly property string themeInfo:      model.info      || ""

                                        Rectangle {
                                            anchors.fill: parent; anchors.margins: 6; radius: 11
                                            color: Local.Theme.currentTheme === model.themeName
                                                   ? Local.Theme.border : model.bgMain
                                            border.color: Local.Theme.currentTheme === model.themeName
                                                          ? Local.Theme.accent : "transparent"
                                            border.width: 2

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: Local.Theme.currentTheme === model.themeName ? 5 : 0
                                                radius: 10
                                                color: model.bgMain
                                                Behavior on anchors.margins { NumberAnimation { duration: 150 } }

                                                ColumnLayout {
                                                    anchors.fill: parent; anchors.margins: 12; spacing: 7

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: model.themeName.replace(/_/g, " ")
                                                        color: Local.Theme.currentTheme === model.themeName
                                                               ? Local.Theme.accent : model.textMain
                                                        font.pixelSize: 12; font.weight: Font.DemiBold
                                                        font.capitalization: Font.Capitalize
                                                        elide: Text.ElideRight
                                                    }

                                                    Row {
                                                        spacing: 6
                                                        Repeater {
                                                            model: [themeAccent, themeAccentAlt,
                                                                    themeWarning, themeError, themeInfo]
                                                            delegate: Rectangle {
                                                                required property string modelData
                                                                width: 13; height: 13; radius: 7
                                                                color: modelData || "transparent"
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Local.Theme.applyTheme(model.themeName);
                                                    searchInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── LAZY LOADERS ──
                            Repeater {
                                id: tabLoadersRepeater
                                model: root.tabList.length
                                delegate: Loader {
                                    id: tabLoader
                                    readonly property int tabIdx: index
                                    width: gridArea.width; height: gridArea.height
                                    x: (tabIdx - root.activeTabIndex) * (gridArea.width + 48) + root.swipeOffset
                                    asynchronous: true

                                    visible: x > -width && x < gridArea.width

                                    readonly property bool shouldBeActive:
                                        root.activeTabIndex === tabIdx
                                        || root.animatingTabIndex === tabIdx
                                        || ((tabSwipeHandler.active || snapAnim.running)
                                            && Math.abs(root.activeTabIndex - tabIdx) === 1)

                                    readonly property bool isThemeTab: tabIdx === 5

                                    onShouldBeActiveChanged: {
                                        if (shouldBeActive) {
                                            active = true;
                                            sourceComponent = isThemeTab ? themePaneComp : appPaneComp;
                                            if (isThemeTab) {
                                                rebuildThemeModel(searchInput.text);
                                            } else if (root.listStabilized) {
                                                Qt.callLater(rebuildTabModelForThisLoader);
                                            }
                                        } else {
                                            sourceComponent = null;
                                            active = false;
                                            if (!isThemeTab) modelForTab(tabIdx).clear();
                                        }
                                    }

                                    function rebuildTabModelForThisLoader() { rebuildTabModel(tabIdx); }

                                    active: false

                                    onLoaded: {
                                        if (!isThemeTab) item.myTabIdx = tabIdx;
                                    }

                                    Component.onCompleted: {
                                        if (shouldBeActive) {
                                            active = true;
                                            sourceComponent = isThemeTab ? themePaneComp : appPaneComp;
                                            if (isThemeTab) {
                                                rebuildThemeModel("");
                                            } else if (root.listStabilized) {
                                                Qt.callLater(rebuildTabModelForThisLoader);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
