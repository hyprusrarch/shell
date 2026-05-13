// === clipboard.qml ===
import QtQuick
import QtQuick.Layouts
import Qt.labs.settings 1.0
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "themes.js" as ThemeDb

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

    property string homeDir: ""

    property var textModelArr: []
    property var imageModelArr: []
    property var favModelArr: []
    property var emojiModelArr: []

    Timer {
        id: copyTimer
        interval: 150
        onTriggered: {
            if (!outroAnim.running) {
                outroAnim.start()
            }
        }
    }

    property int activeTab: 0
    property int animatingTab: -1
    property real swipeOffset: 0

    onActiveTabChanged: {
        if (activeTab === 3 && emojiModelArr.length === 0 && !emojiFetcher.running && emojiFetcher.stdout.fullJson === "") {
            emojiFetcher.running = true;
        }
    }

    NumberAnimation {
        id: offsetAnim
        target: root
        property: "swipeOffset"
        to: 0
        duration: 350
        easing.type: Easing.OutQuart
        onFinished: {
            root.animatingTab = -1;
        }
    }

    function switchTab(newTab) {
        if (activeTab === newTab) return;
        if (!swipeHandler.active) {
            root.swipeOffset = newTab > activeTab ? (listContainer.width + 20) : -(listContainer.width + 20);
        }

        root.animatingTab = root.activeTab;
        root.activeTab = newTab;
        offsetAnim.restart();
    }

    Settings {
        id: favSettings
        category: "Clipboard"
        property string favData: '{"items":[]}'
    }

    property var favs: JSON.parse(favSettings.favData === "" ? '{"items":[]}' : favSettings.favData)

    function updateFavModel() {
        root.favModelArr = favs.items || [];
    }

    function checkFav(type, contentOrId) {
        if (!favs || !favs.items) return false;
        if (type === "TXT") {
            return favs.items.some(f => f.type === "TXT" && f.clipId === contentOrId);
        }
        return favs.items.some(f => f.type === "IMG" && f.clipId === contentOrId);
    }

    function toggleFav(type, clipId, content, rawPath) {
        let current = favs;
        let idx = current.items.findIndex(f => f.type === type && f.clipId === clipId);
        let isNowFav = false;

        if (idx !== -1) {
            let removed = current.items.splice(idx, 1)[0];
            Quickshell.execDetached(["bash", "-c", "rm -f '" + removed.rawPath + "'"]);
            isNowFav = false;
        } else {
            let ext = type === "TXT" ? ".txt" : ".png";
            let destPath = root.homeDir + "/.cache/qs_clip_favs/fav_" + clipId + ext;
            Quickshell.execDetached(["bash", "-c", "cp '" + rawPath + "' '" + destPath + "'"]);
            current.items.unshift({
                type: type,
                clipId: clipId,
                content: content,
                path: "file://" + destPath,
                rawPath: destPath
            });
            isNowFav = true;
        }

        favSettings.favData = JSON.stringify(current);
        favs = current;
        updateFavModel();

        if (type === "TXT") {
            let arr = root.textModelArr;
            for (let i = 0; i < arr.length; i++) {
                if (arr[i].clipId === clipId) {
                    arr[i].isFav = isNowFav;
                    break;
                }
            }
            root.textModelArr = [...arr];
        } else if (type === "IMG") {
            let arr = root.imageModelArr;
            for (let i = 0; i < arr.length; i++) {
                if (arr[i].clipId === clipId) {
                    arr[i].isFav = isNowFav;
                    break;
                }
            }
            root.imageModelArr = [...arr];
        }
    }

    Process {
        id: closeWatcher
        running: true
        command: ["tail", "-n", "0", "-F", "/tmp/qs_clipboard_cmd"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

    Process {
        id: actionCmd
        command: []
    }

    Process {
        id: clipFetcher
        running: false
        command: ["bash", "-c",
        "echo \"HOME|$HOME\"; " +
        "mkdir -p /tmp/qs_clip_images; mkdir -p /tmp/qs_clip_texts; mkdir -p ~/.cache/qs_clip_favs; " +
        "cliphist list | head -n 80 | while IFS= read -r line; do " +
        "id=$(printf \"%s\" \"$line\" | cut -f1); " +
        "content=$(printf \"%s\" \"$line\" | cut -f2-); " +
        "if printf \"%s\" \"$content\" | grep -Fq \"[[ binary data\"; then " +
        "img_path=\"/tmp/qs_clip_images/${id}.png\"; " +
        "if [ ! -s \"$img_path\" ]; then printf \"%s\\n\" \"$line\" | cliphist decode > \"$img_path\"; fi; " +
        "echo \"IMG|$id|$img_path\"; " +
        "else " +
        "txt_path=\"/tmp/qs_clip_texts/${id}.txt\"; " +
        "if [ ! -s \"$txt_path\" ]; then printf \"%s\\n\" \"$line\" | cliphist decode > \"$txt_path\"; fi; " +
        "clean_content=$(head -c 2500 \"$txt_path\" | awk 1 ORS='_NL_' | tr '|' '¦'); " +
        "echo \"TXT|$id|$txt_path|$clean_content\"; " +
        "fi; " +
        "done"
        ]
        stdout: SplitParser {
            property var tempTexts: []
            property var tempImages: []

            onRead: (data) => {
                const parts = data.trim().split("|");
                if (parts[0] === "HOME") {
                    root.homeDir = parts[1];
                    return;
                }
                if (parts.length < 3) return;
                const type = parts[0];
                const cId = parts[1];

                if (type === "TXT" && tempTexts.length < 30) {
                    const tPath = parts[2];
                    const val = parts[3] ? parts[3].replace(/_NL_/g, "\n").replace(/¦/g, "|") : "";
                    tempTexts.push({ clipId: cId, rawPath: tPath, content: val });
                } else if (type === "IMG" && tempImages.length < 30) {
                    tempImages.push({ clipId: cId, path: "file://" + parts[2], rawPath: parts[2] });
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                let txts = stdout.tempTexts;
                let imgs = stdout.tempImages;

                for (let i = 0; i < txts.length; i++) {
                    txts[i].isFav = root.checkFav("TXT", txts[i].clipId);
                }
                for (let j = 0; j < imgs.length; j++) {
                    imgs[j].isFav = root.checkFav("IMG", imgs[j].clipId);
                }

                root.textModelArr = txts;
                root.imageModelArr = imgs;

                stdout.tempTexts = [];
                stdout.tempImages = [];
            }
        }
    }

    Process {
        id: emojiFetcher
        running: false
        command: ["bash", "-c", "cat \"$HOME/.config/quickshell/emojis.json\" 2>/dev/null || echo '[]'"]
        stdout: SplitParser {
            property string fullJson: ""
            onRead: (data) => {
                fullJson += data;
            }
        }
        onRunningChanged: {
            if (!running && stdout.fullJson !== "") {
                try {
                    let parsed = JSON.parse(stdout.fullJson);
                    let emjList = [];
                    let len = parsed.length;
                    for (let i = 0; i < len; i++) {
                        let item = parsed[i];
                        let emj = typeof item === "string" ? item : (item.emoji || item.char || item.character || "");
                        if (emj) emjList.push({ emoji: emj });
                    }
                    root.emojiModelArr = emjList;
                } catch(e) {}
                stdout.fullJson = "";
            }
        }
    }

    function closeAndPurge() {
        root.activeTab = -1;
        root.textModelArr = [];
        root.imageModelArr = [];
        root.favModelArr = [];
        root.emojiModelArr = [];
        Qt.callLater(Qt.quit);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!outroAnim.running) {
                outroAnim.start();
            }
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

    Component {
        id: emptyTabComp
        Text {
            text: "Nothing here yet"
            font.family: "Noto Sans"
            font.pixelSize: 12
            color: Theme.textMuted
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }

    Component {
        id: textDelegateComp
        Rectangle {
            id: textDelegate
            width: textList.width
            property bool isExpanded: false
            property bool canExpand: textContent.truncated || isExpanded

            height: Math.max(40, textContent.implicitHeight + (canExpand ? 44 : 20))
            radius: 8
            color: textArea.containsMouse ? Theme.bgDark : "transparent"
            border.color: textArea.containsMouse ? Theme.accent : Theme.border
            border.width: 1

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Text {
                id: textContent
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 65
                anchors.bottomMargin: textDelegate.canExpand ? 28 : 10
                text: modelData.content.trim()
                font.family: "Noto Sans"
                font.pixelSize: 12
                color: Theme.textMain
                wrapMode: Text.Wrap
                lineHeight: 1.2
                maximumLineCount: textDelegate.isExpanded ? 1000 : 3
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            Item {
                visible: textDelegate.canExpand
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    text: "󰅀"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    color: Theme.accent
                    rotation: textDelegate.isExpanded ? 180 : 0
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: textDelegate.isExpanded = !textDelegate.isExpanded
                }
            }

            MouseArea {
                id: textArea
                anchors.fill: parent
                anchors.bottomMargin: textDelegate.canExpand ? 32 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "wl-copy < '" + modelData.rawPath + "'"]);
                    copyTimer.start();
                }
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 4

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: fTxtArea.containsMouse ? Theme.bgDark : "transparent"
                    property bool isFav: modelData.isFav === true

                    Text {
                        anchors.centerIn: parent
                        text: parent.isFav ? "♥" : "♡"
                        color: parent.isFav ? Theme.accent : Theme.textMuted
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        id: fTxtArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFav("TXT", modelData.clipId, modelData.content, modelData.rawPath)
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: xTextArea.containsMouse ? Theme.error : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: xTextArea.containsMouse ? Theme.bgMain : Theme.textMuted
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        id: xTextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            let targetId = parseInt(modelData.clipId);

                            // 1. Safe grep using whitespace delimiting, and printf to safely pipe to cliphist
                            Quickshell.execDetached([
                                "bash", "-c",
                                "line=$(cliphist list | grep '^" + targetId + "\\s' | head -n 1); if [ -n \"$line\" ]; then printf '%s\\n' \"$line\" | cliphist delete; fi; rm -f '" + modelData.rawPath + "'"
                            ]);

                            // 2. Remove the clicked item from the text array
                            let txtArr = [...root.textModelArr];
                            txtArr.splice(index, 1);

                            // 3. THE FIX: Shift all older IDs down by 1 to perfectly match the cliphist database shift
                            for (let i = 0; i < txtArr.length; i++) {
                                if (parseInt(txtArr[i].clipId) > targetId) {
                                    txtArr[i].clipId = (parseInt(txtArr[i].clipId) - 1).toString();
                                }
                            }
                            root.textModelArr = txtArr;

                            // 4. We must also shift the image array IDs since they share the same global database!
                            let imgArr = [...root.imageModelArr];
                            for (let i = 0; i < imgArr.length; i++) {
                                if (parseInt(imgArr[i].clipId) > targetId) {
                                    imgArr[i].clipId = (parseInt(imgArr[i].clipId) - 1).toString();
                                }
                            }
                            root.imageModelArr = imgArr;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imageDelegateComp
        Item {
            width: imageGrid.cellWidth
            height: imageGrid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 8
                color: imgArea.containsMouse ? Theme.bgDark : "transparent"
                border.color: imgArea.containsMouse ? Theme.accent : Theme.border
                border.width: 1
                clip: true

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(120, 120)
                    cache: false
                    mipmap: false
                }

                MouseArea {
                    id: imgArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", "wl-copy -t image/png < '" + modelData.rawPath + "'"]);
                        copyTimer.start();
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    color: fImgArea.containsMouse ? Theme.bgMain : Theme.bgDark
                    opacity: fImgArea.containsMouse ? 1.0 : 0.8
                    property bool isFav: modelData.isFav === true

                    Text {
                        anchors.centerIn: parent
                        text: parent.isFav ? "♥" : "♡"
                        color: parent.isFav ? Theme.accent : Theme.textMain
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        id: fImgArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFav("IMG", modelData.clipId, "", modelData.rawPath)
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    color: xImgArea.containsMouse ? Theme.error : Theme.bgDark
                    opacity: xImgArea.containsMouse ? 1.0 : 0.8

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: xImgArea.containsMouse ? Theme.bgMain : Theme.textMain
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        id: xImgArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let targetId = parseInt(modelData.clipId);

                            Quickshell.execDetached([
                                "bash", "-c",
                                "line=$(cliphist list | grep '^" + targetId + "\\s' | head -n 1); if [ -n \"$line\" ]; then printf '%s\\n' \"$line\" | cliphist delete; fi; rm -f '" + modelData.rawPath + "'"
                            ]);

                            let imgArr = [...root.imageModelArr];
                            imgArr.splice(index, 1);

                            for (let i = 0; i < imgArr.length; i++) {
                                if (parseInt(imgArr[i].clipId) > targetId) {
                                    imgArr[i].clipId = (parseInt(imgArr[i].clipId) - 1).toString();
                                }
                            }
                            root.imageModelArr = imgArr;

                            let txtArr = [...root.textModelArr];
                            for (let i = 0; i < txtArr.length; i++) {
                                if (parseInt(txtArr[i].clipId) > targetId) {
                                    txtArr[i].clipId = (parseInt(txtArr[i].clipId) - 1).toString();
                                }
                            }
                            root.textModelArr = txtArr;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: favDelegateComp
        Rectangle {
            id: favDelegate
            width: favList.width
            property bool isExpanded: false
            property bool canExpand: modelData.type === "TXT" && (favText.truncated || isExpanded)

            height: modelData.type === "TXT" ? Math.max(40, favText.implicitHeight + (canExpand ? 44 : 20)) : 100
            radius: 8
            color: favArea.containsMouse ? Theme.bgDark : "transparent"
            border.color: favArea.containsMouse ? Theme.accent : Theme.border
            border.width: 1

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuart
                }
            }

            Text {
                id: favText
                visible: modelData.type === "TXT"
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 65
                anchors.bottomMargin: favDelegate.canExpand ? 28 : 10
                text: modelData.content || ""
                font.family: "Noto Sans"
                font.pixelSize: 12
                color: Theme.textMain
                wrapMode: Text.Wrap
                lineHeight: 1.2
                maximumLineCount: favDelegate.isExpanded ? 1000 : 3
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            Item {
                visible: favDelegate.canExpand
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    text: "󰅀"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    color: Theme.accent
                    rotation: favDelegate.isExpanded ? 180 : 0
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: favDelegate.isExpanded = !favDelegate.isExpanded
                }
            }

            Image {
                visible: modelData.type === "IMG"
                anchors.fill: parent
                anchors.margins: 2
                anchors.rightMargin: 40
                source: modelData.path || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(200, 100)
                cache: false
                mipmap: false
            }

            MouseArea {
                id: favArea
                anchors.fill: parent
                anchors.bottomMargin: favDelegate.canExpand ? 32 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.type === "TXT") {
                        Quickshell.execDetached(["bash", "-c", "wl-copy < '" + modelData.rawPath + "'"]);
                    } else {
                        Quickshell.execDetached(["bash", "-c", "wl-copy -t image/png < '" + modelData.rawPath + "'"]);
                    }
                    copyTimer.start();
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 6
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 8
                color: xFavArea.containsMouse ? Theme.error : Theme.bgDark

                Text {
                    anchors.centerIn: parent
                    text: "♥"
                    color: xFavArea.containsMouse ? Theme.bgMain : Theme.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                MouseArea {
                    id: xFavArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleFav(modelData.type, modelData.clipId, "", "")
                }
            }
        }
    }

    Component {
        id: emojiDelegateComp
        Rectangle {
            width: emojiGrid.cellWidth
            height: emojiGrid.cellHeight
            color: emojiArea.containsMouse ? Theme.bgDark : "transparent"
            radius: 8

            Text {
                anchors.centerIn: parent
                text: modelData.emoji || ""
                font.pixelSize: 22
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            MouseArea {
                id: emojiArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "echo -n '" + modelData.emoji + "' | wl-copy"]);
                    copyTimer.start();
                }
            }
        }
    }

    Item {
        id: swoopContainer
        width: 410
        height: 410
        x: root.width - width - 5
        y: -height - 20

        Timer {
            id: initTimer
            interval: 20
            running: true
            onTriggered: introAnim.start()
        }

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
                root.updateFavModel();
                clipFetcher.running = true;
            }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation {
                target: swoopContainer;
                property: "y";
                to: -swoopContainer.height - 160; duration: 250; easing.type: Easing.InQuart
            }
            onFinished: {
                // EXTREME RAM SAVER: Wipe the heavy arrays and force garbage collection
                root.textModelArr = [];
                root.imageModelArr = [];
                root.favModelArr = [];
                root.emojiModelArr = [];
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
            width: 380
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.bgMain
            radius: 12

            Rectangle {
                width: parent.width
                height: 12
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.bgMain
            }

            ColumnLayout {
                id: mainCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰅌"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: Theme.accent
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "Clipboard History"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textMain
                        Layout.fillWidth: true
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        visible: root.activeTab !== 3
                        color: clearArea.containsMouse ? Theme.error : "transparent"
                        border.color: clearArea.containsMouse ? Theme.error : Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: clearArea.containsMouse ? Theme.bgMain : Theme.textMain
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeTab === 0) {
                                    Quickshell.execDetached(["sh", "-c", "cliphist list | grep -v '\\[\\[ binary data' | cliphist delete && rm -rf /tmp/qs_clip_texts/*"]);
                                    root.textModelArr = [];
                                } else if (root.activeTab === 1) {
                                    Quickshell.execDetached(["sh", "-c", "cliphist list | grep '\\[\\[ binary data' | cliphist delete && rm -rf /tmp/qs_clip_images/*"]);
                                    root.imageModelArr = [];
                                } else if (root.activeTab === 2) {
                                    Quickshell.execDetached(["bash", "-c", "rm -f " + root.homeDir + "/.cache/qs_clip_favs/fav_*.png " + root.homeDir + "/.cache/qs_clip_favs/fav_*.txt"]);
                                    root.favs = { items: [] };
                                    favSettings.favData = JSON.stringify(root.favs);
                                    root.updateFavModel();

                                    let txts = root.textModelArr;
                                    for(let i=0; i<txts.length; i++) txts[i].isFav = false;
                                    root.textModelArr = [...txts];

                                    let imgs = root.imageModelArr;
                                    for(let i=0; i<imgs.length; i++) imgs[i].isFav = false;
                                    root.imageModelArr = [...imgs];
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["󰖟  Text", "󰋩  Images", "󰓎  Favs", "󰞅  Emoji"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 6
                            color: root.activeTab === index ? Theme.bgDark : "transparent"
                            border.color: root.activeTab === index ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.bold: true
                                color: root.activeTab === index ? Theme.accent : Theme.textMuted
                                renderType: Text.NativeRendering
                                textFormat: Text.PlainText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.switchTab(index)
                            }
                        }
                    }
                }

                Item {
                    id: listContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    DragHandler {
                        id: swipeHandler
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false

                        property real lastDx: 0

                        onTranslationChanged: {
                            if (active) {
                                root.swipeOffset = translation.x;
                                lastDx = translation.x;
                            }
                        }

                        onActiveChanged: {
                            if (!active) {
                                let dx = lastDx;
                                let threshold = (listContainer.width + 20) / 2;
                                let targetIndex = root.activeTab;

                                if (dx < -threshold && root.activeTab < 3) {
                                    targetIndex = root.activeTab + 1;
                                } else if (dx > threshold && root.activeTab > 0) {
                                    targetIndex = root.activeTab - 1;
                                }

                                if (targetIndex !== root.activeTab) {
                                    if (targetIndex > root.activeTab) {
                                        root.swipeOffset += (listContainer.width + 20);
                                    } else {
                                        root.swipeOffset -= (listContainer.width + 20);
                                    }
                                    root.animatingTab = root.activeTab;
                                    root.activeTab = targetIndex;
                                }
                                offsetAnim.restart();
                                lastDx = 0;
                            }
                        }
                    }

                    WheelHandler {
                        property real accumulatedDelta: 0
                        onWheel: function(event) {
                            accumulatedDelta += event.angleDelta.x;
                            if (accumulatedDelta < -150 && root.activeTab < 3) {
                                root.switchTab(root.activeTab + 1);
                                accumulatedDelta = 0;
                            } else if (accumulatedDelta > 150 && root.activeTab > 0) {
                                root.switchTab(root.activeTab - 1);
                                accumulatedDelta = 0;
                            }
                        }
                    }

                    ListView {
                        id: textList
                        width: parent.width
                        height: parent.height
                        x: ((0 - root.activeTab) * (listContainer.width + 20)) + root.swipeOffset
                        visible: x > -width && x < listContainer.width
                        model: root.textModelArr
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 0
                        reuseItems: true

                        Loader {
                            anchors.centerIn: parent
                            active: root.textModelArr.length === 0
                            sourceComponent: emptyTabComp
                        }

                        delegate: textDelegateComp
                    }

                    GridView {
                        id: imageGrid
                        width: parent.width
                        height: parent.height
                        x: ((1 - root.activeTab) * (listContainer.width + 20)) + root.swipeOffset
                        visible: x > -width && x < listContainer.width
                        model: root.imageModelArr
                        cellWidth: parent.width / 3
                        cellHeight: parent.width / 3
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        cacheBuffer: 0
                        reuseItems: true

                        Loader {
                            anchors.centerIn: parent
                            active: root.imageModelArr.length === 0
                            sourceComponent: emptyTabComp
                        }

                        delegate: imageDelegateComp
                    }

                    ListView {
                        id: favList
                        width: parent.width
                        height: parent.height
                        x: ((2 - root.activeTab) * (listContainer.width + 20)) + root.swipeOffset
                        visible: x > -width && x < listContainer.width
                        model: root.favModelArr
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 0
                        reuseItems: true

                        Loader {
                            anchors.centerIn: parent
                            active: root.favModelArr.length === 0
                            sourceComponent: emptyTabComp
                        }

                        delegate: favDelegateComp
                    }

                    Item {
                        id: emojiTab
                        width: parent.width
                        height: parent.height
                        x: ((3 - root.activeTab) * (listContainer.width + 20)) + root.swipeOffset
                        visible: x > -width && x < listContainer.width

                        GridView {
                            id: emojiGrid
                            anchors.fill: parent
                            model: root.emojiModelArr
                            cellWidth: 43
                            cellHeight: 43
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            cacheBuffer: 0
                            reuseItems: true

                            Loader {
                                anchors.centerIn: parent
                                active: root.emojiModelArr.length === 0
                                sourceComponent: emptyTabComp
                            }

                            delegate: emojiDelegateComp
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
