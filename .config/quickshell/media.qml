import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: root

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
        command: [
            "tail",
            "-n",
            "0",
            "-F",
            "/tmp/qs_media_cmd"
        ]
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
        width: 340
        height: mainLayout.implicitHeight + 30
        x: root.width - width - 20
        y: -height - 15

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
                gc();
            }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation {
                target: swoopContainer
                property: "y"
                to: -swoopContainer.height - 160
                duration: 250
                easing.type: Easing.InQuart
            }
            onFinished: {
                gc();
                Qt.callLater(Qt.quit);
            }
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
            radius: 12

            Rectangle {
                width: parent.width
                height: 12
                anchors.top: parent.top
                color: root.bgMain
            }

            ColumnLayout {
                id: mainLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰝚"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: root.accent
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        width: implicitWidth; height: implicitHeight
                    }

                    Text {
                        text: "Media Control"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.textMain
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        width: implicitWidth; height: implicitHeight
                    }

                    RowLayout {
                        visible: root.playerCount > 1
                        spacing: 12

                        Text {
                            text: "󰅁"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: prevAppArea.containsMouse ? root.accent : root.textMuted
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                            width: implicitWidth; height: implicitHeight

                            MouseArea {
                                id: prevAppArea
                                anchors.fill: parent
                                anchors.margins: -5
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
                            font.pixelSize: 16
                            color: nextAppArea.containsMouse ? root.accent : root.textMuted
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                            width: implicitWidth; height: implicitHeight

                            MouseArea {
                                id: nextAppArea
                                anchors.fill: parent
                                anchors.margins: -5
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
                    font.pixelSize: 12
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
                                    spacing: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 16

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 16

                                            Item {
                                                width: 76
                                                height: 76
                                                Layout.alignment: Qt.AlignVCenter

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 60
                                                    height: 60
                                                    radius: 30
                                                    color: "#111111"
                                                }

                                                Item {
                                                    id: spinningPart
                                                    anchors.centerIn: parent
                                                    width: 60
                                                    height: 60

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
                                                        font.pixelSize: 24
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
                                                        sourceSize: Qt.size(64, 64)
                                                        asynchronous: true
                                                        mipmap: false
                                                        cache: false
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 86
                                                    height: 86
                                                    radius: 43
                                                    color: "transparent"
                                                    border.color: root.bgMain
                                                    border.width: 13
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 68
                                                    height: 68
                                                    radius: 34
                                                    color: "transparent"
                                                    border.color: root.accent
                                                    border.width: 1
                                                    opacity: 0.5
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 76
                                                    height: 76
                                                    radius: 38
                                                    color: "transparent"
                                                    border.color: root.border
                                                    border.width: 1
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 4

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: delegateLoader.visible ? (function() {
                                                        if (!player) return "Unknown Title";
                                                        if (player.trackTitle && player.trackTitle !== "") return player.trackTitle;
                                                        if (player.metadata && player.metadata["xesam:title"]) return String(player.metadata["xesam:title"]);
                                                        return "Unknown Title";
                                                    })() : ""
                                                    font.family: "Noto Sans"
                                                    font.pixelSize: 14
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
                                                    font.pixelSize: 11
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
                                            spacing: 24

                                            Text {
                                                property bool canSkip: player && player.canGoPrevious
                                                text: "󰒮"
                                                font.family: "Symbols Nerd Font"
                                                font.pixelSize: 20
                                                color: canSkip ? (prevArea.containsMouse ? root.accent : root.textMain) : root.textMuted
                                                opacity: canSkip ? 1.0 : 0.4
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: prevArea
                                                    anchors.fill: parent
                                                    anchors.margins: -10
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
                                                font.pixelSize: 28
                                                color: playArea.containsMouse ? root.accent : root.textMain
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: playArea
                                                    anchors.fill: parent
                                                    anchors.margins: -10
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
                                                font.pixelSize: 20
                                                color: canSkip ? (nextArea.containsMouse ? root.accent : root.textMain) : root.textMuted
                                                opacity: canSkip ? 1.0 : 0.4
                                                renderType: Text.NativeRendering
                                                textFormat: Text.PlainText
                                                width: implicitWidth; height: implicitHeight

                                                MouseArea {
                                                    id: nextArea
                                                    anchors.fill: parent
                                                    anchors.margins: -10
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
                                        Layout.preferredWidth: 20
                                        spacing: 8

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
                                                width: 4
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
                                            font.pixelSize: 16
                                            color: muteArea.containsMouse ? root.accent : root.textMuted
                                            renderType: Text.NativeRendering
                                            textFormat: Text.PlainText
                                            width: implicitWidth; height: implicitHeight

                                            MouseArea {
                                                id: muteArea
                                                anchors.fill: parent
                                                anchors.margins: -5
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
                width: 15
                height: 15
                clip: true

                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    color: "transparent"
                    border.color: Theme.bgMain
                    border.width: 15
                    x: -30
                    y: -15
                }
            }

            Item {
                anchors.top: mainBox.top
                anchors.left: mainBox.right
                width: 15
                height: 15
                clip: true

                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    color: "transparent"
                    border.color: Theme.bgMain
                    border.width: 15
                    x: -15
                    y: -15
                }
            }
        }
    }
}
