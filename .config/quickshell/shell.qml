//@ pragma UseQApplication
//@ pragma DropExpensiveFonts
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

ShellRoot {
    id: shell

    readonly property string clipboardWatchScript: decodeURIComponent(
        String(Qt.resolvedUrl("scripts/clipboard-watch.sh")).replace(/^file:\/\//, ""))

    // Start the independent cliphist capture service with the shell, even though
    // the clipboard UI itself is a page of the shell panel. The manager respects the saved on/off state.
    Process {
        id: clipboardServiceManager
        running: true
        command: ["bash", shell.clipboardWatchScript]
    }

    function panelLoader(name) {
        switch (name) {
        case "media": return mediaLoader;
        case "modules": return modulesLoader;
        default: return null;
        }
    }

    function panelCommandFile(name) {
        switch (name) {
        case "media": return "media.cmd";
        case "modules": return "modules.cmd";
        default: return "";
        }
    }

    function togglePanel(name) {
        // Clipboard lives inside the shared panel (same animation as Wi-Fi).
        if (name === "clipboard") { Ui.toggleClipboard(); return; }
        if (name === "launcher") { Ui.toggleLauncher(); return; }
        const loader = panelLoader(name);
        if (!loader) return;
        if (!loader.active) {
            loader.active = true;
            return;
        }
        const file = panelCommandFile(name);
        if (file === "") return;
        Quickshell.execDetached(["sh", "-c",
            "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf 'CLOSE\\n' >> \"$runtime/quickshell/" + file + "\""]);
    }

    function unloadPanel(name) {
        const loader = panelLoader(name);
        if (loader) loader.active = false;
    }

    Process {
        id: controlWatcher
        running: true
        command: ["sh", "-c",
            "set -eu; runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; " +
            "umask 077; mkdir -p \"$runtime/quickshell\"; chmod 700 \"$runtime/quickshell\"; " +
            "touch \"$runtime/quickshell/control\"; " +
            "for f in launcher clipboard media modules; do " +
            "p=\"$runtime/quickshell/$f.cmd\"; [ ! -p \"$p\" ] || rm -f \"$p\"; " +
            "touch \"$p\"; done; exec tail -n 0 -F \"$runtime/quickshell/control\""]
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length < 2) return;
                if (parts[0] === "toggle") shell.togglePanel(parts[1]);
                else if (parts[0] === "closed") shell.unloadPanel(parts[1]);
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Item {
                required property ShellScreen modelData

                Loader {
                    id: barInstance
                    property var screenForInstance: modelData
                    active: true
                    source: "bar.qml"
                    onLoaded: if (item) item.targetScreen = screenForInstance
                }

            }
        }
    }

    LazyLoader { id: mediaLoader; active: false; source: "media.qml" }
    LazyLoader { id: modulesLoader; active: false; source: "modules.qml" }

    M3Overlay { }
}
