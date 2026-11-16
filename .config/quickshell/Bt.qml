pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property var device: {
        if (!adapter) return null
        const v = adapter.devices.values
        for (let i = 0; i < v.length; i++)
            if (v[i].connected) return v[i]
        return null
    }
    readonly property string deviceName: device ? (device.name || device.deviceName || "Device") : ""

    function toggle() { if (adapter) adapter.enabled = !adapter.enabled }
}
