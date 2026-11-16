pragma Singleton
import QtQuick
import Quickshell

// Public audio facade. All controls use SystemStatus' single PipeWire tracker.
Singleton {
    readonly property var sink: SystemStatus.sink
    readonly property var audio: SystemStatus.audio
    readonly property bool ready: SystemStatus.audioReady
    readonly property real volume: SystemStatus.volume
    readonly property bool muted: SystemStatus.muted
    readonly property string icon: muted ? "volume_mute" : (volume < 0.33 ? "volume_down" : "volume_up")
    function setVolume(value) { SystemStatus.setVolume(value); }
    function toggleMute() { SystemStatus.toggleMute(); }
}
