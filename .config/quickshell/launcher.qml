import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import Qt.labs.settings 1.0
import Quickshell
import Quickshell.Io

import "themes.js" as ThemeDb

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    focusable: true
    color: "transparent"

    // ── GRACEFUL CLOSE WATCHER (LAG-FREE) ──
    Process {
        id: closeWatcher
        running: true
        command: ["tail", "-F", "/tmp/qs_launcher_cmd"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

    // --- Configuration ---
    property string fileManager: "nautilus"
    readonly property string fontFamily: "Noto Sans"
    readonly property int fontSize: 13

    // --- UI State ---
    property bool editMode: false
    property string currentTab: "Apps"
    property bool isGridView: true

    // ── SLIDING TAB STATE & PHYSICS ──
    property int activeTabIndex: 0
    property int animatingTabIndex: -1
    property real swipeOffset: 0

    NumberAnimation {
        id: offsetAnim
        target: root
        property: "swipeOffset"
        to: 0
        duration: 350
        easing.type: Easing.OutQuart
        onFinished: {
            root.animatingTabIndex = -1;
            gc(); // Drop RAM immediately when animation finishes
        }
    }

    function switchTab(newIndex, newName) {
        if (activeTabIndex === newIndex) return;

        // If clicked from navbar, setup the offset to simulate a slide!
        if (!swipeHandler.active) {
            root.swipeOffset = newIndex > activeTabIndex ? (mainBox.width + 40) : -(mainBox.width + 40);
        }

        animatingTabIndex = activeTabIndex;
        activeTabIndex = newIndex;
        root.currentTab = newName;
        app_search.text = "";
        app_search.forceActiveFocus();

        offsetAnim.restart();
    }

    // --- Calculator State ---
    property string calcResult: ""
    property string rawMathCmd: ""

    // ── ZERO-LAG GLOBAL CACHE ──
    // Stores raw data so swapping tabs skips heavy JS loops entirely. Takes <0.5MB RAM!
    property var cache_apps: null
    property var cache_games: null
    property var cache_system: null
    property var cache_themes: null

    // --- NATIVE State Management ---
    Settings {
        id: appSettings
        property string savedOrder_Apps: "[]"
        property string savedOrder_Games: "[]"
        property string savedOrder_System: "[]"

        property string frequencyData: "{}"
        property string hiddenApps: "[]"
        property bool savedIsGridView: true
    }

    Component.onCompleted: {
        root.isGridView = appSettings.savedIsGridView;
    }

    onIsGridViewChanged: {
        appSettings.savedIsGridView = root.isGridView;
    }

    // --- Anti-Race Condition Logic ---
    property bool listStabilized: false
    property int lastAppCount: -1

    Timer {
        id: stabilityTimer
        interval: 250
        repeat: true
        running: true
        onTriggered: function() {
            var currentCount = DesktopEntries.applications.values.length;
            if (currentCount > 0 && currentCount === root.lastAppCount) {
                if (!root.listStabilized) {
                    root.listStabilized = true;
                }
            } else if (currentCount > 0) {
                root.lastAppCount = currentCount;
            }
        }
    }

    Process {
        id: adhocProcess
    }

    function saveFreq(appName) {
        var freqs = {};
        try {
            freqs = JSON.parse(appSettings.frequencyData);
        } catch(e) {}

        freqs[appName] = (freqs[appName] || 0) + 1;
        appSettings.frequencyData = JSON.stringify(freqs);

        // Invalidate cache so resort takes effect
        root.cache_apps = null;
        root.cache_games = null;
        root.cache_system = null;
    }

    function saveCurrentOrder(modelToSave) {
        var newOrder = [];
        for (var i = 0; i < modelToSave.count; i++) {
            if (!modelToSave.get(i).isCustom) {
                newOrder.push(modelToSave.get(i).appName);
            }
        }

        // SAVE UNIQUELY & CLEAR CACHE TO FORCE REBUILD
        if (root.currentTab === "Apps") {
            appSettings.savedOrder_Apps = JSON.stringify(newOrder);
            root.cache_apps = null;
        } else if (root.currentTab === "Games") {
            appSettings.savedOrder_Games = JSON.stringify(newOrder);
            root.cache_games = null;
        } else if (root.currentTab === "System") {
            appSettings.savedOrder_System = JSON.stringify(newOrder);
            root.cache_system = null;
        }
    }

    function hideApp(appName) {
        var hidden = [];
        try {
            hidden = JSON.parse(appSettings.hiddenApps);
        } catch(e) {}

        if (hidden.indexOf(appName) === -1) {
            hidden.push(appName);
            appSettings.hiddenApps = JSON.stringify(hidden);
        }

        // Invalidate cache
        root.cache_apps = null;
        root.cache_games = null;
        root.cache_system = null;
    }

    // --- BACKGROUND CLICK TO CLOSE ---
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!outroAnim.running) {
                outroAnim.start();
            }
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                if (!outroAnim.running) {
                    outroAnim.start();
                }
            }
        }

        // --- MAIN LAUNCHER WINDOW ---
        Rectangle {
            id: mainBox
            width: 800
            height: 420

            y: 0
            x: -width - 20

            radius: 10
            color: Theme.bgMain
            border.width: 0

            Rectangle {
                anchors {
                    top: parent.top;
                    left: parent.left;
                    right: parent.right
                }
                height: 10
                color: Theme.bgMain
            }

            Rectangle {
                anchors {
                    top: parent.top;
                    bottom: parent.bottom;
                    left: parent.left
                }
                width: 10
                color: Theme.bgMain
            }

            Component.onCompleted: {
                introAnim.start();
                app_search.forceActiveFocus();
            }

            ParallelAnimation {
                id: introAnim
                NumberAnimation {
                    target: mainBox;
                    property: "x";
                    to: 0;
                    duration: 350;
                    easing.type: Easing.OutQuart
                }
                onFinished: {
                    app_search.forceActiveFocus();
                }
            }

            ParallelAnimation {
                id: outroAnim
                NumberAnimation {
                    target: mainBox;
                    property: "x";
                    to: -mainBox.width - 250;
                    duration: 300;
                    easing.type: Easing.InQuart
                }
                onFinished: {
                    Qt.quit();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: function(m) {
                    m.accepted = true;
                    app_search.forceActiveFocus();
                }
            }

            Shape {
                anchors.top: parent.bottom
                anchors.left: parent.left
                width: 15
                height: 15
                ShapePath {
                    fillColor: Theme.bgMain
                    strokeWidth: 0
                    startX: 0
                    startY: 0

                    PathLine { x: 0; y: 15 }
                    PathArc {
                        x: 15; y: 0;
                        radiusX: 15; radiusY: 15;
                        useLargeArc: false;
                        direction: PathArc.Clockwise
                    }
                    PathLine { x: 0; y: 0 }
                }
            }

            // ── DYNAMIC APP VIEW COMPONENT ──
            Component {
                id: tabContentComp
                Item {
                    id: tabRoot
                    anchors.fill: parent

                    property alias gridView: app_grid
                    property alias listView: app_list

                    ListModel {
                        id: localAppModel
                    }

                    Timer {
                        id: searchDebounce
                        interval: 100
                        running: false
                        onTriggered: {
                            updateLocalModel();
                        }
                    }

                    // INITIAL DRAG LAG FIX: Pushes heavy model insertion 1ms past the first drag frame!
                    Timer {
                        id: initialPopulateTimer
                        interval: 1
                        running: true
                        onTriggered: {
                            updateLocalModel();
                        }
                    }

                    function updateLocalModel() {
                        if (!root.listStabilized) return;
                        var rawText = app_search.text;
                        var query = rawText.toLowerCase();

                        root.calcResult = "";
                        root.rawMathCmd = "";

                        // ZERO-LAG CACHE CHECK: If no search query, inject pre-built list instantly!
                        if (query === "") {
                            var cachedItems = null;
                            if (myFilter === "") cachedItems = root.cache_apps;
                            else if (myFilter === "Game") cachedItems = root.cache_games;
                            else if (myFilter === "Settings") cachedItems = root.cache_system;

                            if (cachedItems !== null) {
                                localAppModel.clear();
                                localAppModel.append(cachedItems);
                                if (root.isGridView) app_grid.currentIndex = 0; else app_list.currentIndex = 0;
                                return; // Complete instantly, skip all math!
                            }
                        }

                        // --- IF CACHE IS EMPTY OR SEARCHING, BUILD THE LIST ---
                        var allApps = DesktopEntries.applications.values;
                        if (allApps.length === 0) return;

                        localAppModel.clear();

                        var isExplicitCalc = rawText.startsWith("=");
                        var mathRegex = /^[\d\s\+\-\*\/\(\)\.]+$/;
                        var isMath = mathRegex.test(rawText) && /[\+\-\*\/]/.test(rawText) && /\d/.test(rawText);

                        var batchItems = [];

                        if (isExplicitCalc || isMath) {
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

                        if (rawText.startsWith(":")) {
                            var cmd = rawText.substring(1).trim();
                            if (cmd.length > 0) {
                                batchItems.push({
                                    appName: "Run command: " + cmd,
                                    appIcon: "foot",
                                    isCustom: true,
                                    type: "command",
                                    cmd: cmd,
                                    path: "",
                                    appId: ""
                                });
                                localAppModel.append(batchItems);
                            }
                            return;
                        }

                        if (rawText.startsWith("/") || rawText.startsWith("~")) {
                            batchItems.push({
                                appName: "Open path: " + rawText,
                                appIcon: "org.gnome.Nautilus",
                                isCustom: true,
                                type: "path",
                                cmd: "",
                                path: rawText,
                                appId: ""
                            });
                            localAppModel.append(batchItems);
                            return;
                        }

                        var appMap = {};
                        var validApps = [];

                        var categoryFilter = myFilter;
                        var hiddenAppsList = [];

                        try {
                            hiddenAppsList = JSON.parse(appSettings.hiddenApps);
                        } catch(e) {}

                        for (var i = 0; i < allApps.length; i++) {
                            var app = allApps[i];
                            if (!app.noDisplay && !app.runInTerminal) {
                                if (hiddenAppsList.indexOf(app.name) !== -1) {
                                    continue;
                                }

                                if (categoryFilter !== "") {
                                    var cats = app.categories || [];
                                    var matchesCategory = false;
                                    for(var c = 0; c < cats.length; c++) {
                                        if (cats[c].includes(categoryFilter)) {
                                            matchesCategory = true;
                                        }
                                    }
                                    if (!matchesCategory) {
                                        continue;
                                    }
                                }
                                appMap[app.name] = app;
                                validApps.push(app);
                            }
                        }

                        var parsedOrder = [];
                        try {
                            if (myFilter === "") parsedOrder = JSON.parse(appSettings.savedOrder_Apps);
                            else if (myFilter === "Game") parsedOrder = JSON.parse(appSettings.savedOrder_Games);
                            else if (myFilter === "Settings") parsedOrder = JSON.parse(appSettings.savedOrder_System);
                        } catch(e) {}

                        var freqs = {};
                        try {
                            freqs = JSON.parse(appSettings.frequencyData);
                        } catch(e) {}

                        var finalOrder = [];
                        var used = {};

                        if (parsedOrder && parsedOrder.length > 0) {
                            for (var j = 0; j < parsedOrder.length; j++) {
                                var name = parsedOrder[j];
                                if (appMap[name] && !used[name]) {
                                    finalOrder.push(appMap[name]);
                                    used[name] = true;
                                }
                            }
                        }

                        var remainingApps = [];
                        for (var k = 0; k < validApps.length; k++) {
                            if (!used[validApps[k].name]) {
                                remainingApps.push(validApps[k]);
                            }
                        }

                        remainingApps.sort(function(a, b) {
                            var freqA = freqs[a.name] || 0;
                            var freqB = freqs[b.name] || 0;
                            if (freqB !== freqA) {
                                return freqB - freqA;
                            }
                            return a.name.localeCompare(b.name);
                        });

                        for (var m = 0; m < remainingApps.length; m++) {
                            finalOrder.push(remainingApps[m]);
                        }

                        for (var n = 0; n < finalOrder.length; n++) {
                            var appData = finalOrder[n];
                            var matchesSearch = true;

                            if (query.length > 0) {
                                matchesSearch = appData.name.toLowerCase().includes(query) ||
                                appData.keywords.some(function(k) { return k.toLowerCase().includes(query); });
                            }

                            if (matchesSearch) {
                                batchItems.push({
                                    appName: appData.name,
                                    appIcon: appData.icon || "",
                                    appId: appData.id || appData.name + ".desktop",
                                    isCustom: false,
                                    type: "",
                                    cmd: "",
                                    path: ""
                                });
                            }
                        }

                        if (query.length > 0) {
                            batchItems.push({
                                appName: "Search the web for '" + rawText + "'",
                                appIcon: "system-search",
                                appId: "",
                                isCustom: true,
                                type: "search",
                                cmd: rawText,
                                path: ""
                            });
                        }

                        // POPULATE THE ZERO-LAG CACHE!
                        if (query === "") {
                            if (myFilter === "") root.cache_apps = batchItems;
                            else if (myFilter === "Game") root.cache_games = batchItems;
                            else if (myFilter === "Settings") root.cache_system = batchItems;
                        }

                        localAppModel.append(batchItems);

                        if (root.isGridView) {
                            app_grid.currentIndex = 0;
                        } else {
                            app_list.currentIndex = 0;
                        }
                    }

                    Connections {
                        target: app_search;
                        function onTextChanged() {
                            searchDebounce.restart();
                        }
                    }

                    Connections {
                        target: root;
                        function onListStabilizedChanged() {
                            if (root.listStabilized) {
                                updateLocalModel();
                            }
                        }
                    }

                    // --- GRID VIEW ---
                    GridView {
                        id: app_grid
                        anchors.fill: parent
                        visible: root.isGridView
                        model: root.isGridView ? localAppModel : null
                        reuseItems: true
                        cellWidth: Math.floor(parent.width / 7)
                        cellHeight: 90
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        moveDisplaced: Transition {
                            NumberAnimation {
                                properties: "x,y";
                                duration: 150;
                                easing.type: Easing.OutQuad
                            }
                        }

                        delegate: Item {
                            id: grid_delegate
                            width: app_grid.cellWidth
                            height: app_grid.cellHeight
                            property int visualIndex: index
                            z: dragArea.drag.active ? 100 : 1

                            DropArea {
                                anchors.fill: parent
                                visible: !model.isCustom
                                onEntered: function(drag) {
                                    var from = drag.source.visualIndex;
                                    var to = grid_delegate.visualIndex;
                                    if (from !== undefined && to !== undefined && from !== to) {
                                        localAppModel.move(from, to, 1);
                                    }
                                }
                            }

                            function launch() {
                                if (root.editMode) return;

                                if (model.isCustom) {
                                    var execString = "";

                                    if (model.type === "search") {
                                        var searchUrl = "https://www.google.com/search?q=" + encodeURIComponent(model.cmd);
                                        var safeUrl = searchUrl.replace(/'/g, "'\\''");
                                        execString = "xdg-open '" + safeUrl + "'";
                                    } else if (model.type === "command") {
                                        var safeCmd = model.cmd.replace(/'/g, "'\\''");
                                        execString = "foot bash -c '" + safeCmd + "; exec bash'";
                                    } else if (model.type === "path") {
                                        var rawPath = model.path;
                                        var finalPathStr = rawPath.startsWith("~") ? "$HOME/\"" + rawPath.substring(1).replace(/^\//, "").replace(/"/g, '\\"') + "\"" : "\"" + rawPath.replace(/"/g, '\\"') + "\"";
                                        var bashCmd = root.fileManager + " " + finalPathStr;
                                        execString = "bash -c '" + bashCmd.replace(/'/g, "'\\''") + "'";
                                    }

                                    adhocProcess.command = ["hyprctl", "dispatch", "exec", "--", execString];
                                    adhocProcess.running = true;
                                } else {
                                    root.saveFreq(model.appName);
                                    var apps = DesktopEntries.applications.values;
                                    for (var i = 0; i < apps.length; i++) {
                                        if (apps[i].name === model.appName) {
                                            apps[i].execute();
                                            break;
                                        }
                                    }
                                }

                                if (!outroAnim.running) {
                                    outroAnim.start();
                                }
                            }

                            Rectangle {
                                id: gridContentItem
                                x: 6
                                y: 4
                                width: grid_delegate.width - 12
                                height: grid_delegate.height - 8
                                radius: 8
                                color: grid_delegate.GridView.isCurrentItem && !root.editMode ? Theme.bgDark : "transparent"

                                Behavior on x {
                                    enabled: !dragArea.drag.active;
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                                }
                                Behavior on y {
                                    enabled: !dragArea.drag.active;
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                                }

                                states: [
                                    State {
                                        when: dragArea.drag.active
                                        ParentChange {
                                            target: gridContentItem;
                                            parent: app_grid
                                        }
                                        PropertyChanges {
                                            target: gridContentItem;
                                            z: 1000;
                                            opacity: 0.9;
                                            scale: 1.05
                                        }
                                    }
                                ]

                                property real pressX: width / 2
                                property real pressY: height / 2

                                Drag.active: dragArea.drag.active
                                Drag.source: grid_delegate
                                Drag.hotSpot.x: pressX
                                Drag.hotSpot.y: pressY

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: (root.editMode && !model.isCustom) ? gridContentItem : null
                                    drag.axis: Drag.XAndYAxis
                                    cursorShape: root.editMode && !model.isCustom ? Qt.OpenHandCursor : Qt.ArrowCursor

                                    onPressed: function(mouse) {
                                        if (root.editMode && !model.isCustom) {
                                            gridContentItem.pressX = mouse.x;
                                            gridContentItem.pressY = mouse.y;
                                            cursorShape = Qt.ClosedHandCursor;
                                        }
                                    }
                                    onReleased: {
                                        if (root.editMode && !model.isCustom) {
                                            cursorShape = Qt.OpenHandCursor;
                                            gridContentItem.x = 6;
                                            gridContentItem.y = 4;
                                            root.saveCurrentOrder(localAppModel);
                                        }
                                    }
                                    onClicked: {
                                        if (!root.editMode) {
                                            app_grid.currentIndex = index;
                                            app_search.forceActiveFocus();
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (!root.editMode) {
                                            grid_delegate.launch();
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    enabled: false

                                    Button {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        padding: 0
                                        enabled: false
                                        background: null

                                        icon.name: {
                                            var ic = model.appIcon || "";
                                            if (ic === "") return "application-x-executable";
                                            if (ic.startsWith("/") || ic.startsWith("file://")) return "";
                                                return ic.replace(/\.(png|svg|xpm)$/i, "");
                                        }

                                        icon.source: {
                                            var ic = model.appIcon || "";
                                            if (ic.startsWith("file://")) return ic;
                                                if (ic.startsWith("/")) return "file://" + ic;
                                                    return "";
                                        }
                                        icon.width: 32
                                        icon.height: 32
                                        icon.color: "transparent"
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        text: model.appName
                                        color: grid_delegate.GridView.isCurrentItem && !root.editMode ? Theme.accent : Theme.textMain
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                    }
                                }

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: Theme.error
                                    visible: root.editMode && !model.isCustom
                                    anchors {
                                        top: parent.top;
                                        right: parent.right;
                                        topMargin: -4;
                                        rightMargin: -4
                                    }
                                    z: 10

                                    Text {
                                        text: "✕"
                                        anchors.centerIn: parent
                                        color: Theme.bgMain
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.hideApp(model.appName);
                                            localAppModel.remove(index);
                                            root.saveCurrentOrder(localAppModel);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- LIST VIEW ---
                    ListView {
                        id: app_list
                        anchors.fill: parent
                        visible: !root.isGridView
                        model: !root.isGridView ? localAppModel : null
                        reuseItems: true
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        moveDisplaced: Transition {
                            NumberAnimation {
                                properties: "x,y";
                                duration: 150;
                                easing.type: Easing.OutQuad
                            }
                        }

                        delegate: Item {
                            id: list_delegate
                            width: app_list.width
                            height: 44
                            property int visualIndex: index
                            z: listDragArea.drag.active ? 100 : 1

                            DropArea {
                                anchors.fill: parent
                                visible: !model.isCustom
                                onEntered: function(drag) {
                                    var from = drag.source.visualIndex;
                                    var to = list_delegate.visualIndex;
                                    if (from !== undefined && to !== undefined && from !== to) {
                                        localAppModel.move(from, to, 1);
                                    }
                                }
                            }

                            function launch() {
                                if (root.editMode) return;

                                if (model.isCustom) {
                                    var execString = "";
                                    if (model.type === "search") {
                                        var searchUrl = "https://www.google.com/search?q=" + encodeURIComponent(model.cmd);
                                        var safeUrl = searchUrl.replace(/'/g, "'\\''");
                                        execString = "xdg-open '" + safeUrl + "'";
                                    } else if (model.type === "command") {
                                        var safeCmd = model.cmd.replace(/'/g, "'\\''");
                                        execString = "foot bash -c '" + safeCmd + "; exec bash'";
                                    } else if (model.type === "path") {
                                        var rawPath = model.path;
                                        var finalPathStr = rawPath.startsWith("~") ? "$HOME/\"" + rawPath.substring(1).replace(/^\//, "").replace(/"/g, '\\"') + "\"" : "\"" + rawPath.replace(/"/g, '\\"') + "\"";
                                        var bashCmd = root.fileManager + " " + finalPathStr;
                                        execString = "bash -c '" + bashCmd.replace(/'/g, "'\\''") + "'";
                                    }
                                    adhocProcess.command = ["hyprctl", "dispatch", "exec", "--", execString];
                                    adhocProcess.running = true;
                                } else {
                                    root.saveFreq(model.appName);
                                    var apps = DesktopEntries.applications.values;
                                    for (var i = 0; i < apps.length; i++) {
                                        if (apps[i].name === model.appName) {
                                            apps[i].execute();
                                            break;
                                        }
                                    }
                                }

                                if (!outroAnim.running) {
                                    outroAnim.start();
                                }
                            }

                            Rectangle {
                                id: listContentItem
                                x: 0
                                y: 2
                                width: list_delegate.width
                                height: list_delegate.height - 4
                                radius: 8
                                color: list_delegate.ListView.isCurrentItem && !root.editMode ? Theme.bgDark : "transparent"

                                Behavior on x {
                                    enabled: !listDragArea.drag.active;
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                                }
                                Behavior on y {
                                    enabled: !listDragArea.drag.active;
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
                                }

                                states: [
                                    State {
                                        when: listDragArea.drag.active
                                        ParentChange {
                                            target: listContentItem;
                                            parent: app_list
                                        }
                                        PropertyChanges {
                                            target: listContentItem;
                                            z: 1000;
                                            opacity: 0.9;
                                            scale: 1.02
                                        }
                                    }
                                ]

                                property real pressX: width / 2
                                property real pressY: height / 2

                                Drag.active: listDragArea.drag.active
                                Drag.source: list_delegate
                                Drag.hotSpot.x: pressX
                                Drag.hotSpot.y: pressY

                                MouseArea {
                                    id: listDragArea
                                    anchors.fill: parent
                                    drag.target: (root.editMode && !model.isCustom) ? listContentItem : null
                                    drag.axis: Drag.YAxis
                                    cursorShape: root.editMode && !model.isCustom ? Qt.OpenHandCursor : Qt.ArrowCursor

                                    onPressed: function(mouse) {
                                        if (root.editMode && !model.isCustom) {
                                            listContentItem.pressX = mouse.x;
                                            listContentItem.pressY = mouse.y;
                                            cursorShape = Qt.ClosedHandCursor;
                                        }
                                    }
                                    onReleased: {
                                        if (root.editMode && !model.isCustom) {
                                            cursorShape = Qt.OpenHandCursor;
                                            listContentItem.x = 0;
                                            listContentItem.y = 2;
                                            root.saveCurrentOrder(localAppModel);
                                        }
                                    }
                                    onClicked: {
                                        if (!root.editMode) {
                                            app_list.currentIndex = index;
                                            app_search.forceActiveFocus();
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (!root.editMode) {
                                            list_delegate.launch();
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 12
                                    enabled: false

                                    Button {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        padding: 0
                                        enabled: false
                                        background: null

                                        icon.name: {
                                            var ic = model.appIcon || "";
                                            if (ic === "") return "application-x-executable";
                                            if (ic.startsWith("/") || ic.startsWith("file://")) return "";
                                                return ic.replace(/\.(png|svg|xpm)$/i, "");
                                        }

                                        icon.source: {
                                            var ic = model.appIcon || "";
                                            if (ic.startsWith("file://")) return ic;
                                                if (ic.startsWith("/")) return "file://" + ic;
                                                    return "";
                                        }

                                        icon.width: 24
                                        icon.height: 24
                                        icon.color: "transparent"
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        text: model.appName
                                        color: list_delegate.ListView.isCurrentItem && !root.editMode ? Theme.accent : Theme.textMain
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: Theme.error
                                    visible: root.editMode && !model.isCustom
                                    anchors {
                                        right: parent.right;
                                        rightMargin: 12;
                                        verticalCenter: parent.verticalCenter
                                    }
                                    z: 10

                                    Text {
                                        text: "✕"
                                        anchors.centerIn: parent
                                        color: Theme.bgMain
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.hideApp(model.appName);
                                            localAppModel.remove(index);
                                            root.saveCurrentOrder(localAppModel);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── DYNAMIC THEME SELECTOR COMPONENT (Darkest to Lightest) ──
            Component {
                id: themesComp
                Item {
                    id: themesRoot
                    anchors.fill: parent
                    property alias gridView: themeGrid
                    property alias listView: themeList

                    ListModel {
                        id: themeListModel
                    }

                    Timer {
                        id: themeDebounce
                        interval: 100
                        running: false
                        onTriggered: {
                            updateModel(app_search.text);
                        }
                    }

                    // ZERO-LAG THEME LOADER
                    Timer {
                        id: initialPopulateTimer
                        interval: 1
                        running: true
                        onTriggered: {
                            updateModel("");
                        }
                    }

                    function updateModel(query) {
                        var q = query.toLowerCase();
                        themeListModel.clear();

                        // HEAVY MATH IS NOW CACHED AT ROOT!
                        if (root.cache_themes === null) {
                            let themeArray = [];
                            for (let t in ThemeDb.themes) {
                                let bg = String(ThemeDb.themes[t].bgMain).replace('#', '');
                                let r = parseInt(bg.substring(0, 2), 16);
                                let g = parseInt(bg.substring(2, 4), 16);
                                let b = parseInt(bg.substring(4, 6), 16);

                                let lum = 0.299 * r + 0.587 * g + 0.114 * b;
                                themeArray.push({ name: t, lum: lum });
                            }

                            themeArray.sort((a, b) => a.lum - b.lum);

                            var precalcBatch = [];
                            for (var i = 0; i < themeArray.length; i++) {
                                var tName = themeArray[i].name;
                                var t = ThemeDb.themes[tName];
                                precalcBatch.push({
                                    themeName: tName, bgMain: t.bgMain, bgDark: t.bgDark,
                                    textMain: t.textMain, accent: t.accent, accentAlt: t.accentAlt,
                                    error: t.error, warning: t.warning, success: t.success, info: t.info
                                });
                            }
                            root.cache_themes = precalcBatch;
                        }

                        // FAST PATH CACHE HIT
                        if (q === "") {
                            themeListModel.append(root.cache_themes);
                            if (root.isGridView) themeGrid.currentIndex = 0; else themeList.currentIndex = 0;
                            return;
                        }

                        // SEARCHING OVER CACHED DATA
                        var searchBatch = [];
                        for (var j = 0; j < root.cache_themes.length; j++) {
                            if (root.cache_themes[j].themeName.replace(/_/g, " ").toLowerCase().indexOf(q) !== -1) {
                                searchBatch.push(root.cache_themes[j]);
                            }
                        }

                        themeListModel.append(searchBatch);
                        if (root.isGridView) themeGrid.currentIndex = 0; else themeList.currentIndex = 0;
                    }

                    Connections {
                        target: app_search
                        function onTextChanged() {
                            if (root.activeTabIndex === 3) {
                                themeDebounce.restart();
                            }
                        }
                    }

                    GridView {
                        id: themeGrid
                        visible: root.isGridView
                        anchors.fill: parent
                        cellWidth: Math.floor(parent.width / 4)
                        cellHeight: 80
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.isGridView ? themeListModel : null
                        reuseItems: true

                        delegate: Item {
                            width: themeGrid.cellWidth
                            height: themeGrid.cellHeight

                            function launch() {
                                if (typeof Theme.applyTheme === "function") {
                                    Theme.applyTheme(model.themeName);
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                radius: 8
                                color: Theme.currentTheme === model.themeName ? Theme.border : model.bgMain
                                border.color: Theme.currentTheme === model.themeName ? Theme.accent : "transparent"
                                border.width: 2

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.currentTheme === model.themeName ? 4 : 0
                                    radius: 6
                                    color: model.bgMain
                                    border.color: Theme.border
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.themeName.replace(/_/g, " ")
                                            color: Theme.currentTheme === model.themeName ? Theme.accent : model.textMain
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.bold: Theme.currentTheme === model.themeName
                                            font.capitalization: Font.Capitalize
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: 6
                                            Rectangle { width: 14; height: 14; radius: 7; color: model.accent }
                                            Rectangle { width: 14; height: 14; radius: 7; color: model.accentAlt }
                                            Rectangle { width: 14; height: 14; radius: 7; color: model.warning }
                                            Rectangle { width: 14; height: 14; radius: 7; color: model.error }
                                            Rectangle { width: 14; height: 14; radius: 7; color: model.info }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        themeGrid.currentIndex = index;
                                        if (typeof Theme.applyTheme === "function") {
                                            Theme.applyTheme(model.themeName);
                                        }
                                        app_search.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: themeList
                        visible: !root.isGridView
                        anchors.fill: parent
                        model: !root.isGridView ? themeListModel : null
                        reuseItems: true
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            width: themeList.width
                            height: 48

                            function launch() {
                                if (typeof Theme.applyTheme === "function") {
                                    Theme.applyTheme(model.themeName);
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 8
                                color: themeList.currentIndex === index ? Theme.bgDark : "transparent"
                                border.color: Theme.currentTheme === model.themeName ? Theme.accent : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 16

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.themeName.replace(/_/g, " ")
                                        color: Theme.currentTheme === model.themeName ? Theme.accent : model.textMain
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.bold: Theme.currentTheme === model.themeName
                                        font.capitalization: Font.Capitalize
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        spacing: 8
                                        Rectangle { width: 16; height: 16; radius: 4; color: model.bgMain; border.color: Theme.border; border.width: 1 }
                                        Rectangle { width: 16; height: 16; radius: 8; color: model.accent }
                                        Rectangle { width: 16; height: 16; radius: 8; color: model.accentAlt }
                                        Rectangle { width: 16; height: 16; radius: 8; color: model.warning }
                                        Rectangle { width: 16; height: 16; radius: 8; color: model.error }
                                        Rectangle { width: 16; height: 16; radius: 8; color: model.info }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        themeList.currentIndex = index;
                                        if (typeof Theme.applyTheme === "function") {
                                            Theme.applyTheme(model.themeName);
                                        }
                                        app_search.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        TextField {
                            id: app_search
                            placeholderText: !root.listStabilized ? "Loading apps..." : (root.activeTabIndex === 3 ? "Search " + Object.keys(ThemeDb.themes).length + " themes..." : "Search, calculate, run commands, open directories")
                            focus: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            background: Rectangle { color: "transparent" }
                            color: Theme.textMain
                            placeholderTextColor: Theme.textMuted
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            enabled: root.listStabilized

                            Keys.onPressed: function(event) {
                                var activeLoader = loadersRepeater.itemAt(root.activeTabIndex);
                                if (!activeLoader || !activeLoader.item) return;

                                var currentView = root.isGridView ? activeLoader.item.gridView : activeLoader.item.listView;
                                if (!currentView) return;

                                if (event.key === Qt.Key_Up) {
                                    if (root.isGridView) currentView.moveCurrentIndexUp();
                                    else currentView.decrementCurrentIndex();
                                } else if (event.key === Qt.Key_Down) {
                                    if (root.isGridView) currentView.moveCurrentIndexDown();
                                    else currentView.incrementCurrentIndex();
                                } else if (event.key === Qt.Key_Left && root.isGridView) {
                                    currentView.moveCurrentIndexLeft();
                                } else if (event.key === Qt.Key_Right && root.isGridView) {
                                    currentView.moveCurrentIndexRight();
                                } else if (event.key === Qt.Key_Return && !root.editMode) {
                                    if (root.calcResult !== "" && root.activeTabIndex !== 3) {
                                        adhocProcess.running = false;
                                        adhocProcess.command = ["bash", "-c", "echo -n '" + root.rawMathCmd.replace(/'/g, "'\\''") + "' | wl-copy"];
                                        adhocProcess.running = true;
                                        if (!outroAnim.running) outroAnim.start();
                                    } else if (currentView.currentItem) {
                                        currentView.currentItem.launch();
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 6
                            Layout.fillWidth: true

                            Repeater {
                                model: [
                                { name: "Apps", icon: "󰀻", filter: "" },
                                { name: "Games", icon: "󰊗", filter: "Game" },
                                { name: "System", icon: "󰒓", filter: "Settings" },
                                { name: "Themes", icon: "󰸉", filter: "" }
                                ]
                                delegate: Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: tabText.width + tabIcon.width + 22
                                    radius: 4
                                    color: root.activeTabIndex === index ? Theme.border : "transparent"

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            id: tabIcon
                                            text: modelData.icon
                                            color: root.activeTabIndex === index ? Theme.accent : Theme.textMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            id: tabText
                                            text: modelData.name
                                            color: root.activeTabIndex === index ? Theme.accent : Theme.textMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 12
                                            font.bold: root.activeTabIndex === index
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.switchTab(index, modelData.name)
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: root.activeTabIndex !== 3 ? 75 : 0
                        visible: root.activeTabIndex !== 3
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 75
                            Layout.preferredHeight: 32
                            radius: 8
                            color: root.editMode ? Theme.border : "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    id: penIcon
                                    text: "✎"
                                    color: root.editMode ? Theme.accent : Theme.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    transform: Scale { origin.x: penIcon.width / 2; xScale: -1 }
                                }

                                Text {
                                    text: root.editMode ? "Done" : "Edit"
                                    color: root.editMode ? Theme.accent : Theme.textMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function() {
                                    root.editMode = !root.editMode;
                                    if (!root.editMode) app_search.forceActiveFocus();
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 75
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        RowLayout {
                            Layout.preferredWidth: 75
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 7

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 28
                                radius: 8
                                color: root.isGridView ? Theme.border : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰕰"
                                    color: root.isGridView ? Theme.accent : Theme.textMuted
                                    font.pixelSize: 14
                                    font.family: root.fontFamily
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isGridView = true;
                                        app_search.forceActiveFocus();
                                        gc();
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 28
                                radius: 8
                                color: !root.isGridView ? Theme.border : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒏"
                                    color: !root.isGridView ? Theme.accent : Theme.textMuted
                                    font.pixelSize: 14
                                    font.family: root.fontFamily
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isGridView = false;
                                        app_search.forceActiveFocus();
                                        gc();
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.calcResult !== "" && root.activeTabIndex !== 3 ? 60 : 0
                    visible: root.calcResult !== "" && root.activeTabIndex !== 3
                    color: Theme.bgDark
                    radius: 8
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: root.calcResult
                        color: Theme.textMain
                        font.family: root.fontFamily
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: Theme.bgMain
                        radius: 4
                        width: 32
                        height: 20

                        Text {
                            text: "⏎ 1"
                            anchors.centerIn: parent
                            color: Theme.textMuted
                            font.family: root.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function() {
                            adhocProcess.running = false;
                            adhocProcess.command = ["bash", "-c", "echo -n '" + root.rawMathCmd.replace(/'/g, "'\\''") + "' | wl-copy"];
                            adhocProcess.running = true;
                            if (!outroAnim.running) outroAnim.start();
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // ── HORIZONTAL STICK-TO-FINGER SWIPE ENGINE ──
                    DragHandler {
                        id: swipeHandler
                        target: null
                        enabled: !root.editMode
                        xAxis.enabled: true
                        yAxis.enabled: false

                        // Caches distance before reset on release
                        property real lastDx: 0

                        onTranslationChanged: {
                            if (active) {
                                root.swipeOffset = translation.x;
                                lastDx = translation.x;
                            }
                        }

                        onActiveChanged: {
                            if (!active) {
                                let dx = lastDx;

                                // EXACT 50% Threshold to mathematically snap to nearest!
                                let threshold = (mainBox.width + 40) / 2;

                                let targetIndex = root.activeTabIndex;

                                // Dragged far left (next tab)
                                if (dx < -threshold && root.activeTabIndex < 3) {
                                    targetIndex = root.activeTabIndex + 1;
                                }
                                // Dragged far right (prev tab)
                                else if (dx > threshold && root.activeTabIndex > 0) {
                                    targetIndex = root.activeTabIndex - 1;
                                }

                                if (targetIndex !== root.activeTabIndex) {
                                    // Math to preserve visual X position during instant model swap
                                    if (targetIndex > root.activeTabIndex) {
                                        root.swipeOffset += (mainBox.width + 40);
                                    } else {
                                        root.swipeOffset -= (mainBox.width + 40);
                                    }

                                    root.animatingTabIndex = root.activeTabIndex;
                                    root.activeTabIndex = targetIndex;

                                    let tabs = ["Apps", "Games", "System", "Themes"];
                                    root.currentTab = tabs[targetIndex];
                                    app_search.text = "";
                                    app_search.forceActiveFocus();
                                }

                                // Animate the remaining offset to 0 to snap it in perfectly
                                offsetAnim.restart();
                                lastDx = 0;
                            }
                        }
                    }

                    // ── TOUCHPAD WHEEL ENGINE ──
                    WheelHandler {
                        enabled: !root.editMode
                        property real accumulatedDelta: 0

                        onWheel: function(event) {
                            accumulatedDelta += event.angleDelta.x;
                            let tabs = ["Apps", "Games", "System", "Themes"];

                            if (accumulatedDelta < -150 && root.activeTabIndex < 3) {
                                root.switchTab(root.activeTabIndex + 1, tabs[root.activeTabIndex + 1]);
                                accumulatedDelta = 0;
                            } else if (accumulatedDelta > 150 && root.activeTabIndex > 0) {
                                root.switchTab(root.activeTabIndex - 1, tabs[root.activeTabIndex - 1]);
                                accumulatedDelta = 0;
                            }
                        }
                    }

                    Repeater {
                        id: loadersRepeater
                        model: [
                        { name: "Apps", filter: "" },
                        { name: "Games", filter: "Game" },
                        { name: "System", filter: "Settings" },
                        { name: "Themes", filter: "" }
                        ]

                        delegate: Loader {
                            readonly property int myIndex: index
                            readonly property string myFilter: modelData.filter

                            width: parent.width
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom

                            // EXTREME RAM SAVER: Fully eliminated layer.enabled FBO allocations to stop all lag

                            // LAZY LOADING + MEMORY FIX: Keep adjacent tabs alive during the ENTIRE swipe and snap-back sequence
                            active: root.activeTabIndex === index ||
                            root.animatingTabIndex === index ||
                            ((swipeHandler.active || offsetAnim.running) && Math.abs(root.activeTabIndex - index) === 1)

                            asynchronous: false
                            sourceComponent: active ? (myIndex === 3 ? themesComp : tabContentComp) : undefined

                            // DYNAMIC MATH POSITIONS ALL LOADERS RELATIVE TO ACTIVE TAB (STUCK TO SWIPE)
                            x: ((index - root.activeTabIndex) * (parent.width + 40)) + root.swipeOffset
                        }
                    }
                }
            }
        }
    }
}
