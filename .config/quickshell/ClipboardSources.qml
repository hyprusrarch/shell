pragma Singleton
import QtQuick
import Quickshell

// Resolves the window class a clip was copied from into the app's display
// name and icon, using the installed desktop entries (same data the launcher
// uses). Results are cached and refreshed when the app list changes.
QtObject {
    id: root

    property int revision: 0
    property var cache: ({})

    function norm(s) { return String(s || "").toLowerCase().replace(/\.desktop$/, ""); }

    function pretty(cls) {
        let n = String(cls || "");
        if (n.indexOf(".") > 0) n = n.substring(n.lastIndexOf(".") + 1);
        n = n.replace(/[-_]+/g, " ").trim();
        return n.length ? n.charAt(0).toUpperCase() + n.slice(1) : "";
    }

    function execName(entry) {
        const e = String(entry.execString || "").trim().split(/\s+/)[0] || "";
        return norm(e.substring(e.lastIndexOf("/") + 1));
    }

    function findEntry(cls) {
        const key = norm(cls);
        const apps = DesktopEntries.applications.values || [];
        let loose = null;
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            const id = norm(e.id);
            if (id === key || norm(e.startupClass) === key) return e;
            if (!loose && (id.endsWith("." + key) || norm(e.name) === key || execName(e) === key)) loose = e;
        }
        return loose;
    }

    function resolve(cls) {
        if (!cls) return { name: "", icon: "" };
        if (root.cache[cls]) return root.cache[cls];
        const apps = DesktopEntries.applications.values || [];
        const entry = root.findEntry(cls);
        let icon = "";
        if (entry && entry.icon) icon = Quickshell.iconPath(entry.icon, true) || "";
        if (!icon) icon = Quickshell.iconPath(root.norm(cls), true) || "";
        const res = { name: (entry && entry.name) ? entry.name : root.pretty(cls), icon: icon };
        if (apps.length > 0) root.cache[cls] = res;   // don't cache before the app list has loaded
        return res;
    }

    property var appsWatcher: Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.cache = ({});
            root.revision++;
        }
    }
}
