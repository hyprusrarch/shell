import QtQuick
import "../" as Local

// Spring-driven removal shared by every clipboard entry (same M3 spatial spring
// as the Wi-Fi / control-centre pages). `presence` runs 1 -> 0; once it has
// collapsed, `finished()` fires so the owner can delete the real item. Entries
// also react to the controller's `clearRequested()` with a staggered cascade
// (one after another, top to bottom) and stay silent: the controller wipes the
// data itself once the cascade is over.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var controller
    property int itemIndex: 0
    property bool active: false
    property bool silent: false
    property bool committed: false
    property int staggerMs: 45
    property int maxStagger: 8

    // 1 = fully present, 0 = gone. Clamped: the spring may overshoot.
    readonly property real presence: Math.max(0, Math.min(1, spring.value))

    signal finished()

    function remove(delayMs, quiet) {
        if (active || delayTimer.running) return;
        silent = quiet === true;
        if (delayMs > 0) {
            delayTimer.interval = delayMs;
            delayTimer.start();
        } else {
            active = true;
        }
    }

    // ListView.onReused / delegate recycling.
    function reset() {
        delayTimer.stop();
        active = false;
        silent = false;
        committed = false;
        spring.value = 1;
        spring.velocity = 0;
        spring.target = 1;
    }

    Timer { id: delayTimer; onTriggered: root.active = true }

    Local.SpringValue {
        id: spring
        spring: Local.M3.spatialDefault
        target: root.active ? 0 : 1
        initial: 1
        precision: 0.002
    }

    Connections {
        target: spring
        function onValueChanged() {
            if (root.active && !root.committed && spring.value < 0.03) {
                root.committed = true;
                if (!root.silent) root.finished();
            }
        }
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true
        function onClearRequested() {
            root.remove(Math.min(root.itemIndex, root.maxStagger) * root.staggerMs, true);
        }
    }
}
