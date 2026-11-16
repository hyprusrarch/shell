import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../" as Local
import "../themes.js" as ThemeDb

// Launcher state + logic (no visuals): tabs, search, models, caches, ordering,
// hidden apps, usage frequency, calculator / command / path / web-search
// items, theme list and launching. One instance per launcher window.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    // ── tabs ────────────────────────────────────────────────────────────
    readonly property var tabList: ["All", "Network", "Game", "System", "Utility", "Themes"]
    readonly property var tabLabels: ["All", "Web", "Game", "System", "Utility", "Themes"]
    readonly property int themeTab: 5
    readonly property string fileManager: "nautilus"

    // ── state ───────────────────────────────────────────────────────────
    property int activeTabIndex: 0
    property bool editMode: false
    property bool gridViewMode: true
    property string searchText: ""
    property string calcResult: ""
    property string rawMathCmd: ""
    property bool startupReady: false
    property bool listStabilized: false
    property int lastAppCount: -1

    signal closeRequested()          // launching / copying asks the window to close
    signal searchCleared()           // tell the search field to empty itself
    signal focusSearchRequested()

    // ── models ──────────────────────────────────────────────────────────
    ListModel { id: model_All }
    ListModel { id: model_Network }
    ListModel { id: model_Game }
    ListModel { id: model_System }
    ListModel { id: model_Utility }
    ListModel { id: model_Themes }

    function modelForTab(idx) {
        return [model_All, model_Network, model_Game, model_System, model_Utility, model_Themes][idx] || model_All;
    }

    // ── caches (plain objects: nothing binds to them) ───────────────────
    property var _cache: ({})
    property var _orderCache: ({})
    property var _themeCache: null

    function cacheForTab(idx) { return root._cache[idx] === undefined ? null : root._cache[idx]; }
    function setCacheForTab(idx, val) { root._cache[idx] = val; }
    function invalidateAllCaches() { root._cache = ({}); root._orderCache = ({}); }

    // ── persistence (same category / keys as before: existing data is kept) ─
    Settings {
        id: appSettings
        category: "Launcher"
        property string savedOrder_All: "[]"
        property string savedOrder_Network: "[]"
        property string savedOrder_Game: "[]"
        property string savedOrder_System: "[]"
        property string savedOrder_Utility: "[]"
        property string hiddenApps: "[]"
        property string frequencyData: "{}"
        property bool savedIsGridView: true
    }

    Component.onCompleted: {
        root.gridViewMode = appSettings.savedIsGridView;
        root.startupReady = true;
    }
    onGridViewModeChanged: appSettings.savedIsGridView = root.gridViewMode

    // ── wait until the desktop-entry list stops changing ────────────────
    Timer {
        id: stabilityTimer
        interval: 80
        repeat: false
        running: true
        onTriggered: {
            const n = DesktopEntries.applications.values.length;
            if (n > 0) {
                if (n === root.lastAppCount) root.listStabilized = true;
                else { root.lastAppCount = n; stabilityTimer.start(); }
            } else stabilityTimer.start();
        }
    }

    Timer { id: searchDebounce; interval: 80; onTriggered: root.rebuildTabModel(root.activeTabIndex) }
    Timer { id: themeDebounce; interval: 80; onTriggered: root.rebuildThemeModel(root.searchText) }

    onSearchTextChanged: {
        if (root.activeTabIndex === root.themeTab) themeDebounce.restart();
        else searchDebounce.restart();
    }

    Process { id: adhocProcess }

    // ── tab switching ───────────────────────────────────────────────────
    function switchTab(newIndex) {
        if (newIndex === root.activeTabIndex) return;
        if (newIndex < 0 || newIndex >= root.tabList.length) return;
        root.activeTabIndex = newIndex;
        root.searchText = "";
        root.searchCleared();
    }

    // ── helpers: order / hidden / frequency ─────────────────────────────
    function savedOrderForTab(tabName) {
        if (root._orderCache[tabName] === undefined) {
            try { root._orderCache[tabName] = JSON.parse(appSettings["savedOrder_" + tabName]); }
            catch (e) { root._orderCache[tabName] = []; }
        }
        return root._orderCache[tabName];
    }

    function saveFreq(appName) {
        var freqs = {};
        try { freqs = JSON.parse(appSettings.frequencyData); } catch (e) {}
        freqs[appName] = (freqs[appName] || 0) + 1;
        appSettings.frequencyData = JSON.stringify(freqs);
        root._cache = ({});
    }

    function saveOrderForTab(tabIdx) {
        const mdl = root.modelForTab(tabIdx);
        const order = [];
        for (let i = 0; i < mdl.count; i++) {
            const item = mdl.get(i);
            if (!item.isCustom) order.push(item.appName);
        }
        const name = root.tabList[tabIdx];
        appSettings["savedOrder_" + name] = JSON.stringify(order);
        root._orderCache[name] = order;
        root._cache[tabIdx] = null;
    }

    function hideApp(appName) {
        var hidden = [];
        try { hidden = JSON.parse(appSettings.hiddenApps); } catch (e) {}
        if (hidden.indexOf(appName) === -1) {
            hidden.push(appName);
            appSettings.hiddenApps = JSON.stringify(hidden);
        }
        root.invalidateAllCaches();
    }

    // ── theme list (luminance-sorted, cached) ───────────────────────────
    function rebuildThemeModel(rawQuery) {
        const q = String(rawQuery || "").toLowerCase().replace(/ /g, "_");

        if (root._themeCache === null) {
            const arr = [];
            for (const t in ThemeDb.themes) {
                const bg = String(ThemeDb.themes[t].bgMain).replace('#', '');
                const rr = parseInt(bg.substring(0, 2), 16);
                const gg = parseInt(bg.substring(2, 4), 16);
                const bb = parseInt(bg.substring(4, 6), 16);
                arr.push({ name: t, lum: 0.299 * rr + 0.587 * gg + 0.114 * bb });
            }
            arr.sort(function (a, b) { return a.lum - b.lum; });

            const batch = [];
            for (let i = 0; i < arr.length; i++) {
                const n = arr[i].name;
                const d = ThemeDb.themes[n];
                batch.push({ themeName: n, bgMain: d.bgMain || "", bgDark: d.bgDark || "",
                    textMain: d.textMain || "", accent: d.accent || "", accentAlt: d.accentAlt || "",
                    error: d.error || "", warning: d.warning || "", success: d.success || "", info: d.info || "" });
            }
            root._themeCache = batch;
        }

        model_Themes.clear();
        if (q === "") {
            model_Themes.append(root._themeCache);
        } else {
            const filtered = [];
            for (let j = 0; j < root._themeCache.length; j++)
                if (root._themeCache[j].themeName.indexOf(q) !== -1) filtered.push(root._themeCache[j]);
            model_Themes.append(filtered);
        }
    }

    // ── app model rebuild ───────────────────────────────────────────────
    function rebuildTabModel(tabIdx) {
        if (!root.listStabilized) return;
        if (tabIdx === root.themeTab) { root.rebuildThemeModel(root.searchText); return; }

        const tabName = root.tabList[tabIdx];
        const rawText = (tabIdx === root.activeTabIndex) ? root.searchText : "";
        const query = rawText.toLowerCase();

        if (tabIdx === root.activeTabIndex) { root.calcResult = ""; root.rawMathCmd = ""; }

        if (query === "") {
            const cached = root.cacheForTab(tabIdx);
            if (cached !== null) { const mc = root.modelForTab(tabIdx); mc.clear(); mc.append(cached); return; }
        }

        const allApps = DesktopEntries.applications.values || [];
        let hidden = [];
        try { hidden = JSON.parse(appSettings.hiddenApps); } catch (e) {}

        const items = [];

        // calculator: "=expr" or a bare arithmetic expression
        const isExplicitCalc = rawText.startsWith("=");
        const isMath = /^[\d\s\+\-\*\/\(\)\.]+$/.test(rawText) && /[\+\-\*\/]/.test(rawText) && /\d/.test(rawText);
        if (tabIdx === root.activeTabIndex && (isExplicitCalc || isMath)) {
            const mathStr = isExplicitCalc ? rawText.substring(1).trim() : rawText.trim();
            if (mathStr.length > 0) {
                try {
                    if (/^[0-9\+\-\*\/\(\)\.\s]*$/.test(mathStr)) {
                        const result = eval(mathStr);
                        if (result !== undefined && !isNaN(result) && result !== Infinity) {
                            root.calcResult = "= " + result;
                            root.rawMathCmd = result.toString();
                            if (isExplicitCalc) return;
                        }
                    }
                } catch (e) {}
            }
        }

        // ":cmd" runs a command in a terminal
        if (rawText.startsWith(":") && tabIdx === root.activeTabIndex) {
            const cmd = rawText.substring(1).trim();
            if (cmd.length > 0) {
                items.push({ appName: "Run: " + cmd, appIcon: "foot",
                    isCustom: true, itemType: "command", itemCmd: cmd, itemPath: "" });
                root.modelForTab(tabIdx).clear();
                root.modelForTab(tabIdx).append(items);
            }
            return;
        }

        // "/path" or "~/path" opens in the file manager
        if ((rawText.startsWith("/") || rawText.startsWith("~")) && tabIdx === root.activeTabIndex) {
            items.push({ appName: "Open: " + rawText, appIcon: "folder",
                isCustom: true, itemType: "path", itemCmd: "", itemPath: rawText });
            root.modelForTab(tabIdx).clear();
            root.modelForTab(tabIdx).append(items);
            return;
        }

        // regular apps: visible, not hidden, matching the tab category
        const filtered = [];
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            if (app.noDisplay) continue;
            if (hidden.indexOf(app.name) !== -1) continue;
            if (tabName !== "All") {
                const cats = app.categories || [];
                let hit = false;
                for (let c = 0; c < cats.length; c++) {
                    if (cats[c].toLowerCase().includes(tabName.toLowerCase())) { hit = true; break; }
                }
                if (!hit) continue;
            }
            filtered.push(app);
        }

        // saved manual order first, the rest by usage frequency then name
        const savedOrder = root.savedOrderForTab(tabName);
        const appMap = {};
        for (let j = 0; j < filtered.length; j++) appMap[filtered[j].name] = filtered[j];
        const ordered = [];
        const used = {};
        for (let k = 0; k < savedOrder.length; k++) {
            const sn = savedOrder[k];
            if (appMap[sn] && !used[sn]) { ordered.push(appMap[sn]); used[sn] = true; }
        }
        const remaining = [];
        for (let m = 0; m < filtered.length; m++) if (!used[filtered[m].name]) remaining.push(filtered[m]);
        let freqs = {};
        try { freqs = JSON.parse(appSettings.frequencyData); } catch (e) {}
        remaining.sort(function (a, b) {
            const fa = freqs[a.name] || 0;
            const fb = freqs[b.name] || 0;
            if (fb !== fa) return fb - fa;
            return a.name.localeCompare(b.name);
        });
        for (let r = 0; r < remaining.length; r++) ordered.push(remaining[r]);

        for (let p = 0; p < ordered.length; p++) {
            const a = ordered[p];
            if (query !== "") {
                const nm = a.name && a.name.toLowerCase().includes(query);
                const cm = a.comment && a.comment.toLowerCase().includes(query);
                if (!nm && !cm) continue;
            }
            items.push({ appName: a.name, appIcon: a.icon || "",
                isCustom: false, itemType: "", itemCmd: "", itemPath: "" });
        }

        // web search fallback
        if (query.length > 0 && tabIdx === root.activeTabIndex) {
            items.push({ appName: "Search: '" + rawText + "'", appIcon: "system-search",
                isCustom: true, itemType: "search", itemCmd: rawText, itemPath: "" });
        }

        if (query === "") root.setCacheForTab(tabIdx, items);

        const mdl = root.modelForTab(tabIdx);
        mdl.clear();
        mdl.append(items);
    }

    // Called each time the launcher opens: fresh results (usage counts / the
    // saved order may have changed) without rebuilding the whole page.
    function refreshActive() {
        root.invalidateAllCaches();
        root.rebuildTabModel(root.activeTabIndex);
    }

    // ── launching ───────────────────────────────────────────────────────
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
        root.closeRequested();
    }

    // Enter on a calculator result copies it and closes.
    function copyCalcResult() {
        adhocProcess.running = false;
        adhocProcess.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy", "qs-copy-math", root.rawMathCmd];
        adhocProcess.running = true;
        root.closeRequested();
    }
}
