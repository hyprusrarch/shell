pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager-backed Wi-Fi model. Radio/connection status is queried separately
// from AP discovery, so the shell never triggers a network scan while the Wi-Fi page
// is closed. Available APs are scanned only on entering that page or after a Wi-Fi action.
Singleton {
    id: root

    property bool enabled: false
    property bool stateKnown: false
    property bool scanning: false
    property bool connecting: false
    property string connectingSsid: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property bool menuOpen: false
    property var currentConnection: null
    property var networks: []
    property var profiles: []
    property var rawNetworks: []
    property bool nextForcedScan: false
    property bool refreshQueued: false
    property bool queuedForcedScan: false
    property string actionMode: ""

    readonly property var active: {
        // The status query is authoritative. Never keep showing a stale AP row after
        // NetworkManager reports that Wi-Fi disconnected.
        if (!root.currentConnection || !root.currentConnection.connected) return null;
        if (root.menuOpen) {
            const items = root.networks;
            for (let i = 0; i < items.length; ++i)
                if (items[i].connected) return items[i];
        }
        return root.currentConnection;
    }

    function iconFor(signalStrength) {
        return signalStrength < 0.34 ? "wifi_1_bar" : signalStrength < 0.67 ? "wifi_2_bar" : "wifi";
    }

    // nmcli --terse escapes ':' and '\\'. Decode without splitting SSIDs containing ':' characters.
    function splitTerse(line) {
        const out = [];
        let field = "";
        for (let i = 0; i < line.length; ++i) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                field += line[++i];
            } else if (ch === ":") {
                out.push(field);
                field = "";
            } else {
                field += ch;
            }
        }
        out.push(field);
        return out;
    }

    function hasBusyQuery() {
        return radioProc.running || deviceProc.running || listProc.running || profilesProc.running || profilesFallbackProc.running || actionProc.running;
    }

    function refresh(forceScan) {
        const shouldScan = !!forceScan && root.menuOpen;
        if (hasBusyQuery()) {
            refreshQueued = true;
            queuedForcedScan = queuedForcedScan || shouldScan;
            return;
        }
        nextForcedScan = shouldScan;
        radioProc.running = true;
    }

    function setMenuOpen(open) {
        if (root.menuOpen === open) return;
        root.menuOpen = open;
        if (open) {
            // Always do one fresh scan on menu entry; no AP discovery occurs outside it.
            refresh(true);
            return;
        }

        // Stop any scan that is still in flight and release the AP/profile list cache.
        nextForcedScan = false;
        refreshQueued = false;
        queuedForcedScan = false;
        scanning = false;
        if (listProc.running) listProc.running = false;
        if (profilesProc.running) profilesProc.running = false;
        if (profilesFallbackProc.running) profilesFallbackProc.running = false;
        networks = [];
        rawNetworks = [];
        profiles = [];
    }

    function runQueuedRefresh() {
        if (hasBusyQuery() || !refreshQueued) return;
        const force = queuedForcedScan && root.menuOpen;
        refreshQueued = false;
        queuedForcedScan = false;
        Qt.callLater(() => root.refresh(force));
    }

    function startScan(force) {
        if (!root.menuOpen || !root.enabled) {
            root.scanning = false;
            return;
        }
        if (listProc.running || profilesProc.running || profilesFallbackProc.running) {
            root.refreshQueued = true;
            root.queuedForcedScan = root.queuedForcedScan || !!force;
            return;
        }
        root.errorMessage = "";
        root.scanning = true;
        root.statusMessage = "Scanning for networks…";
        listProc.command = ["nmcli", "--wait", "15", "-t", "-e", "yes", "-f", "IN-USE,SSID,SECURITY,SIGNAL,BSSID", "device", "wifi", "list", "--rescan", force ? "yes" : "no"];
        profilesProc.running = true;
        listProc.running = true;
    }

    function setEnabled(on) {
        if (actionProc.running) return;
        actionMode = "radio";
        errorMessage = "";
        actionProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        actionProc.running = true;
    }

    function connect(ssid, password, bssid) {
        if (actionProc.running || !ssid || ssid.length === 0) return;
        const args = ["nmcli", "--wait", "25", "device", "wifi", "connect", ssid];
        if (password && password.length > 0) args.push("password", password);
        if (bssid && bssid.length > 0) args.push("bssid", bssid);
        actionMode = "connect";
        connecting = true;
        connectingSsid = ssid;
        statusMessage = "Connecting to " + ssid + "…";
        errorMessage = "";
        actionProc.command = args;
        actionProc.running = true;
    }

    function forget(profileName) {
        if (actionProc.running || !profileName || profileName.length === 0) return;
        actionMode = "forget";
        errorMessage = "";
        actionProc.command = ["nmcli", "connection", "delete", "id", profileName];
        actionProc.running = true;
    }

    function rebuildNetworks() {
        const result = [];
        for (let i = 0; i < rawNetworks.length; ++i) {
            const item = rawNetworks[i];
            let profile = null;
            for (let j = 0; j < profiles.length; ++j) {
                if (profiles[j].ssid === item.name || profiles[j].name === item.name) {
                    profile = profiles[j];
                    break;
                }
            }
            result.push({
                name: item.name,
                ssid: item.name,
                security: item.security,
                signal: item.signal,
                signalStrength: item.signal / 100.0,
                bssid: item.bssid,
                connected: item.connected,
                known: profile !== null || item.connected,
                profileName: profile ? profile.name : item.name,
                stateChanging: root.connectingSsid === item.name
            });
        }
        root.networks = result;
        for (let i = 0; i < result.length; ++i) {
            if (result[i].connected) {
                // Cache the last verified SSID/signal so the always-visible pill does not
                // need an AP scan to show current connection status while the menu is closed.
                root.currentConnection = result[i];
                break;
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector { id: radioOut }
        stderr: StdioCollector { id: radioErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.stateKnown = false;
                root.enabled = false;
                root.currentConnection = null;
                root.rawNetworks = [];
                root.networks = [];
                root.scanning = false;
                root.errorMessage = radioErr.text.trim() || "NetworkManager is unavailable. Check that NetworkManager is running and nmcli is installed.";
                root.runQueuedRefresh();
                return;
            }
            const state = radioOut.text.trim().toLowerCase();
            root.stateKnown = state === "enabled" || state === "disabled";
            root.enabled = state === "enabled";
            if (!root.enabled) {
                root.currentConnection = null;
                root.rawNetworks = [];
                root.networks = [];
                root.scanning = false;
                root.statusMessage = "Wi-Fi is turned off";
                root.nextForcedScan = false;
                root.runQueuedRefresh();
                return;
            }
            deviceProc.running = true;
        }
    }

    // This cheap status query does not discover access points or initiate a scan.
    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector { id: deviceOut }
        stderr: StdioCollector { id: deviceErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const lines = deviceOut.text.split(/\r?\n/);
                let found = null;
                for (let i = 0; i < lines.length; ++i) {
                    if (!lines[i].length) continue;
                    const f = root.splitTerse(lines[i]);
                    if (f.length < 4 || f[1].toLowerCase() !== "wifi") continue;
                    if (f[2].toLowerCase().indexOf("connected") === 0 && f[3] && f[3] !== "--") {
                        const profileName = f[3];
                        const prev = root.currentConnection;
                        if (prev && prev.connected && prev.profileName === profileName) {
                            found = prev;
                        } else {
                            found = {
                                name: profileName,
                                ssid: profileName,
                                security: "",
                                signal: 50,
                                signalStrength: 0.5,
                                bssid: "",
                                connected: true,
                                known: true,
                                profileName: profileName,
                                stateChanging: root.connectingSsid === profileName
                            };
                        }
                        break;
                    }
                }
                if (found) {
                    if (!root.currentConnection || !root.currentConnection.connected || root.currentConnection.profileName !== found.profileName)
                        root.currentConnection = found;
                } else if (root.currentConnection !== null) {
                    root.currentConnection = null;
                }
            } else if (root.menuOpen) {
                root.errorMessage = deviceErr.text.trim() || "Could not read Wi-Fi device status.";
            }

            const shouldScan = root.nextForcedScan && root.menuOpen && root.enabled;
            root.nextForcedScan = false;
            if (shouldScan) root.startScan(true);
            else root.runQueuedRefresh();
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector { id: listOut }
        stderr: StdioCollector { id: listErr }
        onExited: (exitCode, exitStatus) => {
            if (!root.menuOpen) {
                root.scanning = false;
                root.runQueuedRefresh();
                return;
            }
            root.scanning = false;
            if (exitCode !== 0) {
                root.errorMessage = listErr.text.trim() || "Wi-Fi scan failed. Check NetworkManager and the wireless adapter.";
                root.rawNetworks = [];
                root.networks = [];
            } else {
                const lines = listOut.text.split(/\r?\n/);
                const entries = [];
                for (let i = 0; i < lines.length; ++i) {
                    if (!lines[i].length) continue;
                    const f = root.splitTerse(lines[i]);
                    if (f.length < 4 || !f[1]) continue;
                    const signal = Math.max(0, Math.min(100, parseInt(f[3], 10) || 0));
                    const entry = {
                        name: f[1],
                        security: (f[2] && f[2] !== "--") ? f[2] : "",
                        signal: signal,
                        bssid: f.length > 4 ? f[4] : "",
                        connected: f[0] === "*"
                    };
                    let existing = -1;
                    for (let j = 0; j < entries.length; ++j) {
                        if (entries[j].name === entry.name) { existing = j; break; }
                    }
                    if (existing < 0) entries.push(entry);
                    else if (entry.connected || (!entries[existing].connected && entry.signal > entries[existing].signal)) entries[existing] = entry;
                }
                entries.sort((a, b) => (Number(b.connected) - Number(a.connected)) || (b.signal - a.signal) || a.name.localeCompare(b.name));
                root.rawNetworks = entries;
                root.errorMessage = "";
                root.statusMessage = entries.length ? "" : "No networks found";
                root.rebuildNetworks();
            }
            root.runQueuedRefresh();
        }
    }

    Process {
        id: profilesProc
        command: ["nmcli", "-t", "-e", "yes", "-f", "connection.id,802-11-wireless.ssid", "connection", "show"]
        stdout: StdioCollector { id: profilesOut }
        stderr: StdioCollector { id: profilesErr }
        onExited: (exitCode, exitStatus) => {
            if (!root.menuOpen) { root.runQueuedRefresh(); return; }
            const found = [];
            if (exitCode === 0) {
                const lines = profilesOut.text.split(/\r?\n/);
                for (let i = 0; i < lines.length; ++i) {
                    if (!lines[i].length) continue;
                    const f = root.splitTerse(lines[i]);
                    if (f.length >= 2 && f[0] && f[1] && f[1] !== "--") found.push({ name: f[0], ssid: f[1] });
                }
            }
            if (exitCode !== 0 || (found.length === 0 && root.rawNetworks.length > 0)) {
                profilesFallbackProc.running = true;
                return;
            }
            root.profiles = found;
            root.rebuildNetworks();
            root.runQueuedRefresh();
        }
    }

    Process {
        id: profilesFallbackProc
        command: ["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector { id: profilesFallbackOut }
        stderr: StdioCollector { id: profilesFallbackErr }
        onExited: (exitCode, exitStatus) => {
            if (!root.menuOpen) { root.runQueuedRefresh(); return; }
            const found = [];
            if (exitCode === 0) {
                const lines = profilesFallbackOut.text.split(/\r?\n/);
                for (let i = 0; i < lines.length; ++i) {
                    if (!lines[i].length) continue;
                    const f = root.splitTerse(lines[i]);
                    if (f.length >= 2 && f[0] && (f[1].toLowerCase().indexOf("wireless") >= 0 || f[1].toLowerCase() === "wifi"))
                        found.push({ name: f[0], ssid: f[0] });
                }
            }
            root.profiles = found;
            root.rebuildNetworks();
            root.runQueuedRefresh();
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: (exitCode, exitStatus) => {
            const mode = root.actionMode;
            if (exitCode !== 0) {
                root.errorMessage = actionErr.text.trim() || actionOut.text.trim() || "NetworkManager operation failed.";
                root.statusMessage = "";
            } else {
                root.errorMessage = "";
                root.statusMessage = mode === "connect" ? "Connected" : mode === "forget" ? "Saved network forgotten" : "";
            }
            root.connecting = false;
            root.connectingSsid = "";
            if (mode === "connect") actionProc.command = ["nmcli"];
            if (exitCode === 0) root.refresh(root.menuOpen && (mode === "connect" || mode === "radio" || mode === "forget"));
        }
    }
}
