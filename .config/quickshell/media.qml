import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    function notifyClosed() {
        Quickshell.execDetached(["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf \"closed media\\n\" >> \"$runtime/quickshell/control\""]);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"

    property color bgMain: Theme.bgMain
    property color bgDark: Theme.bgDark
    property color textMain: Theme.textMain
    property color textMuted: Theme.textMuted
    property color accent: Theme.accent
    property color border: Theme.border

    property int currentPlayerIndex: 0
    property int playerCount: Mpris.players.values.length

    onPlayerCountChanged: {
        if (currentPlayerIndex >= playerCount) {
            currentPlayerIndex = Math.max(0, playerCount - 1);
        }
    }

    Process {
        id: closeWatcher
        running: true
        command: ["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; exec tail -n 0 -F \"$runtime/quickshell/media.cmd\""]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

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
    }

    Item {
        id: swoopContainer
        width: 408
        height: mainLayout.implicitHeight + 36
        x: root.width - width - 24
        y: -height - 18

        Component.onCompleted: introAnim.start()

        ParallelAnimation {
            id: introAnim
            NumberAnimation {
                target: swoopContainer
                property: "y"
                to: 0
                duration: 350
                easing.type: Easing.OutQuart
            }
            onFinished: {
                }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation {
                target: swoopContainer
                property: "y"
                to: -swoopContainer.height - 192
                duration: 250
                easing.type: Easing.InQuart
            }
            onFinished: root.notifyClosed()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(m) {
                m.accepted = true;
            }
        }

        Rectangle {
            id: mainBox
            anchors.fill: parent
            color: root.bgMain
            radius: 14

            Rectangle {
                width: parent.width
                height: 14
                anchors.top: parent.top
                color: root.bgMain
            }

            ColumnLayout {
                id: mainLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 19
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰝚"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 17
                        color: root.accent
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        width: implicitWidth; height: implicitHeight
                    }

                    Text {
                        text: "Media Control"
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.textMain
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        width: implicitWidth; height: implicitHeight
                    }

                    RowLayout {
                        visible: root.playerCount > 1
                        spacing: 14

                        Text {
                            text: "󰅁"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 19
                            color: prevAppArea.containsMouse ? root.accent : root.textMuted
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                            width: implicitWidth; height: implicitHeight

                            MouseArea {
                                id: prevAppArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentPlayerIndex = (root.currentPlayerIndex - 1 + root.playerCount) % root.playerCount;
                                }
                            }
                        }

                        Text {
                            text: "󰅂"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 19
                            color: nextAppArea.containsMouse ? root.accent : root.textMuted
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                            width: implicitWidth; height: implicitHeight

                            MouseArea {
                                id: nextAppArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentPlayerIndex = (root.currentPlayerIndex + 1) % root.playerCount;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.border
                }

                Text {
                    visible: root.playerCount === 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    text: "No media players running"
                    font.family: "Noto Sans"
                    font.pixelSize: 14
                    color: root.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                StackLayout {
                    Layout.fillWidth: true
                    currentIndex: root.currentPlayerIndex
                    visible: root.playerCount > 0

                    Repeater {
                        model: Mpris.players

                        delegate: Loader {
                            id: delegateLoader
                            property QtObject playerModelData: modelData
                            Layout.fillWidth: true
                            asynchronous: true
                            active: true

                            sourceComponent: Component {
                                RowLayout {
                                    property QtObject player: delegateLoader.playerModelData
                                    Layout.fillWidth: true
                                    spacing: 19

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 19

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 19

                                            Item {
                                                width: 91
                                                height: 91
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 72
                                                    height: 72
                                                    radius: 36
                                                    color: "#111111"
                                                }

                                                Item {
                                                    id: spinningPart
                                                    anchors.centerIn: parent
                                                    width: 72
                                                    height: 72

                                                    RotationAnimation {
                                                        target: spinningPart
                                                        property: "rotation"
                                                        from: 0
                                                        to: 360
                                                        duration: 6000
                                                        loops: Animation.Infinite
                                                        running: true
                                                        paused: !(player && player.playbackState === MprisPlaybackState.Playing)
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰎆"
                                                        font.family: "Symbols Nerd Font"
                                                        font.pixelSize: 29
                                                        color: root.textMuted
                                                        visible: !albumArt.source || albumArt.source.toString() === ""
                                                        renderType: Text.NativeRendering
                                                        textFormat: Text.PlainText
                                                        width: implicitWidth; height: implicitHeight
                                                    }

                                                    Image {
                                                        id: albumArt
                                                        anchors.fill: parent
                                                        source: delegateLoader.visible ? (function() {
                                                            if (!player) return "";
                                                            if (player.trackArtUrl && player.trackArtUrl !== "") return player.trackArtUrl;
                                                            if (player.metadata && player.metadata["mpris:artUrl"]) return String(player.metadata["mpris:artUrl"]);
                                                            return "";
                                                        })() : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        opacity: 0.9
                                                        sourceSize: Qt.size(77, 77)
                                                        asynchronous: true
                                                        mipmap: false
                                                        cache: false
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 103
                                                    height: 103
                                                    radius: 52
                                                    color: "transparent"
                                                    border.color: root.bgMain
                                                    border.width: 16
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 82
                                                    height: 82
                                                    radius: 41
                                                    color: "transparent"
                                                    border.color: root.accent
                                                    border.width: 1
                                                    opacity: 0.5
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 91
                                                    height: 91
                                                    radius: 46
                                                    color: "transparent"
                                                    border.color: root.border
                                                    border.width: 1
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 5

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: delegateLoader.visible ? (function() {
                                                        if (!player) return "Unknown Title";
                                                        if (player.trackTitle && player.trackTitle !== "") return player.trackTitle;
                                                        if (player.metadata && player.metadata["xesam:title"]) return String(player.metadata["xesam:title"]);
                                                        return "Unknown Title";
                                                    })() : ""
                                                    font.family: "Noto Sans"
                                                    font.pixelSize: 17
                                                    font.bold: true
                                                    color: root.textMain
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                    maximumLineCount: 1
                                                    renderType: Text.NativeRendering
                                                    textFormat: Text.PlainText
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: delegateLoader.visible ? (function() {
                                                        if (!player) return "Unknown Artist";
                                                        if (player.trackArtist && player.trackArtist !== "") return player.trackArtist;
                                                        if (player.metadata && player.metadata["xesam:artist"]) return String(player.metadata["xesam:artist"]);
                                                        return "Unknown Artist";
                                                    })() : ""
                                                    font.family: "Noto Sans"
                                                    font.pixelSize: 13
                                                    color: root.textMuted
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                    renderType: Text.NativeRendering
                                                    textFormat: Text.PlainText
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignCenter
                                            spacing: 29

                                            Text {
                                                property bool canSkip: player && player.canGoPrevious
                                                text: "󰒮"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 24
                                                color: canSkip ? (prevArea.containsMouse ? root.accent : root.textMain) : root.textMuted
                                                opacity: canSkip ? 1.0 : 0.4
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: prevArea
                                                    anchors.fill: parent
                                                    anchors.margins: -12
                                                    hoverEnabled: parent.canSkip
                                                    cursorShape: parent.canSkip ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: {
                                                        if (parent.canSkip) player.previous();
                                                    }
                                                }
                                            }

                                            Text {
                                                text: (player && player.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 34
                                                color: playArea.containsMouse ? root.accent : root.textMain
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: playArea
                                                    anchors.fill: parent
                                                    anchors.margins: -12
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (player) player.togglePlaying();
                                                    }
                                                }
                                            }

                                            Text {
                                                property bool canSkip: player && player.canGoNext
                                                text: "󰒭"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 24
                                                color: canSkip ? (nextArea.containsMouse ? root.accent : root.textMain) : root.textMuted
                                                opacity: canSkip ? 1.0 : 0.4
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: nextArea
                                                    anchors.fill: parent
                                                    anchors.margins: -12
                                                    hoverEnabled: parent.canSkip
                                                    cursorShape: parent.canSkip ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: {
                                                        if (parent.canSkip) player.next();
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        id: rightCol
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 24
                                        spacing: 10

                                        property string sinkId: ""
                                        property real currentVol: player ? player.volume : 0.5

                                        Timer {
                                            id: deferBashSpam
                                            interval: 400
                                            running: player !== null && delegateLoader.visible
                                            repeat: false
                                            onTriggered: fetchSinkId.running = true
                                        }

                                        Process {
                                            id: fetchSinkId
                                            running: false
                                            command: [
                                                "bash",
                                                "-c",
                                                "app='" + (player ? player.identity : "") + "'; " +
                                                "word=$(echo \"$app\" | awk '{print tolower($1)}'); " +
                                                "pactl list sink-inputs | " +
                                                "awk -v search=\"$word\" ' " +
                                                "/^Sink Input/ {id=$3; sub(/#/,\"\",id)} " +
                                                "tolower($0) ~ /application\\.(name|process\\.binary)/ && tolower($0) ~ search {print id; exit}'"
                                            ]
                                            stdout: SplitParser {
                                                onRead: function(data) {
                                                    const id = data.trim();
                                                    if (id !== "") {
                                                        rightCol.sinkId = id;
                                                    }
                                                }
                                            }
                                        }

                                        Process {
                                            id: setVolumeProcess
                                        }

                                        function applyVolume(force) {
                                            if (!force && setVolumeProcess.running) return;
                                            if (rightCol.sinkId !== "") {
                                                const pct = Math.round(rightCol.currentVol * 100);
                                                setVolumeProcess.command = [
                                                    "pactl",
                                                    "set-sink-input-volume",
                                                    rightCol.sinkId,
                                                    pct + "%"
                                                ];
                                                setVolumeProcess.running = true;
                                            } else if (player) {
                                                player.volume = rightCol.currentVol;
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 5
                                                height: parent.height
                                                radius: 2
                                                color: root.bgDark

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    height: parent.height * rightCol.currentVol
                                                    radius: 2
                                                    color: root.accent
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                property double lastTime: 0

                                                onPositionChanged: function(m) {
                                                    if (pressed) {
                                                        const v = Math.max(0, Math.min(1, 1.0 - (m.y / height)));
                                                        rightCol.currentVol = v;
                                                        const now = Date.now();
                                                        if (now - lastTime > 40) {
                                                            lastTime = now;
                                                            rightCol.applyVolume(false);
                                                        }
                                                    }
                                                }

                                                onClicked: function(m) {
                                                    const v = Math.max(0, Math.min(1, 1.0 - (m.y / height)));
                                                    rightCol.currentVol = v;
                                                    rightCol.applyVolume(true);
                                                }

                                                onReleased: {
                                                    rightCol.applyVolume(true);
                                                }
                                            }
                                        }

                                        Text {
                                            property real savedVolume: 1.0
                                            Layout.alignment: Qt.AlignHCenter
                                            text: rightCol.currentVol === 0 ? "󰝟" : (rightCol.currentVol < 0.5 ? "󰖀" : "󰕾")
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 19
                                            color: muteArea.containsMouse ? root.accent : root.textMuted
                                            renderType: Text.NativeRendering
                                            textFormat: Text.PlainText
                                            width: implicitWidth; height: implicitHeight

                                            MouseArea {
                                                id: muteArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (rightCol.currentVol > 0) {
                                                        parent.savedVolume = rightCol.currentVol;
                                                        rightCol.currentVol = 0;
                                                    } else {
                                                        rightCol.currentVol = parent.savedVolume > 0 ? parent.savedVolume : 1.0;
                                                    }
                                                    rightCol.applyVolume(true);
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

            Item {
                anchors.top: mainBox.top
                anchors.right: mainBox.left
                width: 18
                height: 18
                clip: true

                Rectangle {
                    width: 72
                    height: 72
                    radius: 36
                    color: "transparent"
                    border.color: Theme.bgMain
                    border.width: 18
                    x: -36
                    y: -18
                }
            }

            Item {
                anchors.top: mainBox.top
                anchors.left: mainBox.right
                width: 18
                height: 18
                clip: true

                Rectangle {
                    width: 72
                    height: 72
                    radius: 36
                    color: "transparent"
                    border.color: Theme.bgMain
                    border.width: 18
                    x: -18
                    y: -18
                }
            }
        }
    }
}
