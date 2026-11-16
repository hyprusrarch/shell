pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// One shared audio tracker and the only periodic Wi-Fi status scheduler in the shell.
// PipeWire is event-driven; Wi-Fi status polling backs off while the UI is idle.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool audioReady: !!audio
    readonly property real volume: audioReady ? audio.volume : 0
    readonly property bool muted: !audioReady || audio.muted
    readonly property int wifiInterval: Ui.open ? (Ui.page === 1 ? 15000 : 60000) : 90000

    function setVolume(value) {
        if (!root.audioReady) return;
        root.audio.volume = Math.max(0, Math.min(1.5, value));
    }
    function toggleMute() {
        if (root.audioReady) root.audio.muted = !root.audio.muted;
    }

    PwObjectTracker { objects: [root.sink, root.audio] }


    property string cpuUsage: "0"
    property string memUsage: "0.0G"
    property string gpuInfo: "Hover to query"
    property string cpuTemp: "N/A"
    property string coreLines: ""
    property string batPct: "100"
    property string batStatus: "Unknown"
    property bool autoSleepEnabled: true
    property bool hasBattery: false
    property real gpuQueriedAt: 0
    property var prevTotal: ({})
    property var prevIdle: ({})

    readonly property string cpuCoreDetails: coreLines === "" ? "Loading…" : `<b>Per-Core Usage</b><br>${coreLines}<b>Temp:</b> ${cpuTemp}`
    readonly property string ramTooltip: `<b>Memory Usage</b><br>System: ${memUsage}<br>${gpuInfo}`
    readonly property string batTooltip: `<b>Battery: ${batPct}%</b><br>Status: ${batStatus}`
    readonly property string batIcon: {
        if (!hasBattery) return "󰁹";
        const p = parseInt(batPct);
        if (batStatus === "Charging") return "󰂄";
        if (p >= 90) return "󰁹";
        if (p >= 65) return "󰂁";
        if (p >= 40) return "󰁽";
        if (p >= 15) return "󰁻";
        return "󰁺";
    }

    function scriptPath(name) {
        return decodeURIComponent(String(Qt.resolvedUrl("scripts/" + name)).replace(/^file:\/\//, ""));
    }

    function sampleCpu(text) {
        const lines = text.split("\n");
        let main = 0;
        let details = "";
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (line.substring(0, 3) !== "cpu") break;
            const f = line.split(/\s+/);
            const id = f[0];
            let total = 0;
            for (let j = 1; j < f.length; ++j) total += Number(f[j]) || 0;
            const idle = Number(f[4]) || 0;
            const dt = total - (root.prevTotal[id] || 0);
            const di = idle - (root.prevIdle[id] || 0);
            root.prevTotal[id] = total;
            root.prevIdle[id] = idle;
            const u = dt <= 0 ? 0 : Math.floor(100 * (dt - di) / dt);
            if (id === "cpu") main = u;
            else details += `Core ${id.substring(3)}: ${u}%<br>`;
        }
        root.cpuUsage = String(main);
        root.coreLines = details;
    }

    function sampleMem(text) {
        const t = /MemTotal:\s+(\d+)/.exec(text);
        const a = /MemAvailable:\s+(\d+)/.exec(text);
        if (!t || !a) return;
        const um = Math.floor((Number(t[1]) - Number(a[1])) / 1024);
        root.memUsage = um > 1024 ? `${Math.floor(um / 1024)}.${Math.floor((um % 1024) * 10 / 1024)}G` : `${um}M`;
    }

    function refreshGpu() {
        const now = Date.now();
        if (gpuProc.running || now - root.gpuQueriedAt < 15000) return;
        root.gpuQueriedAt = now;
        gpuProc.running = true;
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.sampleCpu(text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.sampleMem(text())
    }

    FileView {
        id: tempFile
        onLoaded: root.cpuTemp = `${Math.floor(Number(text()) / 1000)}°C`
    }

    FileView {
        id: batCapFile
        path: root.hasBattery ? "/sys/class/power_supply/BAT0/capacity" : ""
        onLoaded: root.batPct = text().trim()
    }

    FileView {
        id: batStatusFile
        path: root.hasBattery ? "/sys/class/power_supply/BAT0/status" : ""
        onLoaded: root.batStatus = text().trim()
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (tempFile.path !== "") tempFile.reload();
            if (root.hasBattery) {
                batCapFile.reload();
                batStatusFile.reload();
            }
        }
    }

    Process {
        id: probeProc
        command: ["sh", root.scriptPath("sys-probe.sh")]
        stdout: SplitParser {
            onRead: (d) => {
                const p = d.trim().split("|");
                if (p[0] === "TEMP" && p[1]) tempFile.path = p[1];
                else if (p[0] === "BAT") root.hasBattery = p[1] === "1";
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", root.scriptPath("gpu-info.sh")]
        stdout: SplitParser { onRead: (d) => root.gpuInfo = d.trim() }
    }

    Process {
        id: idleCheck
        command: ["sh", "-c", "pgrep -x hypridle >/dev/null && echo on || echo off"]
        stdout: SplitParser { onRead: (d) => root.autoSleepEnabled = d.trim() === "on" }
    }

    function toggleIdle() {
        if (root.autoSleepEnabled) Quickshell.execDetached(["pkill", "-x", "hypridle"]);
        else Quickshell.execDetached(["hypridle"]);
        root.autoSleepEnabled = !root.autoSleepEnabled;
    }

    function refreshNetworkStatus() {
        if (!Wifi.hasBusyQuery()) Wifi.refresh(false);
    }

    Timer {
        interval: root.wifiInterval
        repeat: true
        running: true
        onTriggered: root.refreshNetworkStatus()
    }

    Connections {
        target: Ui
        function onOpenChanged() {
            if (Ui.open) root.refreshNetworkStatus();
        }
        function onPageChanged() {
            if (Ui.open && Ui.page === 1) root.refreshNetworkStatus();
        }
    }

    Component.onCompleted: {
        probeProc.running = true;
        idleCheck.running = true;
        Wifi.refresh(false);
    }
}
