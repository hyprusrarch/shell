import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: dash

    function notifyClosed() {
        Quickshell.execDetached(["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; printf \"closed modules\\n\" >> \"$runtime/quickshell/control\""]);
    }
    anchors { top: true; bottom: true; left: true; right: true }
    focusable: true
    color: "transparent"

    Process {
        id: closeWatcher
        running: true
        command: ["sh", "-c", "runtime=\"${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}\"; exec tail -n 0 -F \"$runtime/quickshell/modules.cmd\""]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    dash.forceSaveNotes();
                    outroAnim.start();
                }
            }
        }
    }

    property int activeTab: 0
    property int animatingTab: -1
    property real swipeOffset: 0

    NumberAnimation {
        id: offsetAnim
        target: dash
        property: "swipeOffset"
        to: 0
        duration: 350
        easing.type: Easing.OutQuart
        onFinished: {
            dash.animatingTab = -1;
            }
    }

    function switchTab(newTab) {
        if (activeTab === newTab) return;
        if (!swipeHandler.active) {
            dash.swipeOffset = newTab > activeTab ? (mainBox.width + 48) : -(mainBox.width + 48);
        }

        animatingTab = activeTab;
        activeTab = newTab;

        offsetAnim.restart();
    }

    property string locationName: "LOADING..."
    property string temp:        "--"
    property string weatherIcon: "󰖙"
    property string notesData:   ""
    property bool   notesLoaded: false

    readonly property date today:           new Date()
    readonly property int selectedDay:      today.getDate()
    readonly property int firstDayCache:    new Date(today.getFullYear(), today.getMonth(), 1).getDay()
    readonly property int daysInMonthCache: new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()

    readonly property var powerActions: [
        { i: "󰐥", c: "poweroff",                     clr: "error" },
        { i: "󰜉", c: "reboot",                        clr: "warning" },
        { i: "󰗽", c: "loginctl terminate-user $USER", clr: "accentAlt" },
        { i: "󰷛", c: "hyprlock",                      clr: "accent" }
    ]

    property var wallpaperData: []
    property var  _activeXhr:           null
    property real _weatherFetchedAt:    0
    property real _lastSaveTime: 0

    Process {
        id: saveNotes;
        running: false;
        stdout: SplitParser {}
    }

    function forceSaveNotes() {
        if (saveTimer.running || dash.notesData !== "") {
            saveTimer.stop();
            saveNotes.command = ["sh", "-c", "printf '%s' \"$1\" > \"$HOME/.cache/reminders.txt\"", "--", dash.notesData];
            saveNotes.running = true;
        }
    }

    Timer {
        id: saveTimer;
        interval: 500;
        repeat: false
        onTriggered: {
            if (!saveNotes.running) {
                saveNotes.command = ["sh", "-c", "printf '%s' \"$1\" > \"$HOME/.cache/reminders.txt\"", "--", dash.notesData];
                saveNotes.running = true;
            }
        }
    }

    Process {
        id: notesWatcher;
        running: false
        command: ["bash", "-c",
        "trap 'exit 0' TERM;" +
        "f=\"$HOME/.cache/reminders.txt\";" +
        "[ -f \"$f\" ] || touch \"$f\";" +
        "command -v inotifywait &>/dev/null || exit 0;" +
        "while inotifywait -q -e close_write \"$f\" 2>/dev/null;" +
        " do echo changed; done"
        ]
        stdout: SplitParser {
            onRead: function(d) {
                if (d.trim() !== "changed") return;
                if (Date.now() - dash._lastSaveTime < 1500) return;
                readNotes.running = true;
            }
        }
    }

    Process {
        id: readNotes;
        running: false
        command: ["sh", "-c", "cat \"$HOME/.cache/reminders.txt\" 2>/dev/null || echo ''"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(d) {
                readNotes.buffer += d + "\n";
            }
        }
        onRunningChanged: {
            if (running) return;
            const txt = buffer.trim();
            buffer = "";
            dash.notesData   = txt;
            dash.notesLoaded = true;
        }
    }

    Timer {
        id: rootInitTimer
        interval: 400;
        running: true;
        repeat: false
        onTriggered: {
            notesWatcher.running = true;
            readNotes.running    = true;
        }
    }

    function fetchWeather() {
        let ipXhr = new XMLHttpRequest();
        dash._activeXhr = ipXhr;

        ipXhr.open("GET", "http://ip-api.com/json/", true);
        ipXhr.onreadystatechange = function() {
            if (ipXhr.readyState !== XMLHttpRequest.DONE) return;

            if (ipXhr.status === 200) {
                try {
                    const loc = JSON.parse(ipXhr.responseText);
                    let lat = loc.lat || 0;
                    let lon = loc.lon || 0;

                    dash.locationName = (loc.regionName || loc.city || "UNKNOWN").toUpperCase();

                    let xhr = new XMLHttpRequest();
                    dash._activeXhr = xhr;
                    xhr.open("GET",
                             "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + "&current_weather=true&forecast_days=1",
                             true);

                    xhr.onreadystatechange = function() {
                        if (xhr.readyState !== XMLHttpRequest.DONE) return;
                        dash._activeXhr = null;

                        if (xhr.status === 200) {
                            try {
                                const j = JSON.parse(xhr.responseText);
                                if (j.current_weather) {
                                    dash.temp              = Math.round(j.current_weather.temperature) + "°C";
                                    const code             = ~~j.current_weather.weathercode;
                                    dash.weatherIcon       = (code === 0) ? "󰖙" : (code <= 3) ? "󰖕" : "󰖗";
                                    dash._weatherFetchedAt = Date.now();
                                }
                            } catch(e) {
                                dash.temp = "ERR";
                            }
                        }
                        xhr = null;
                    };
                    xhr.send();
                } catch(e) {
                    dash.temp = "ERR";
                }
            } else {
                dash._activeXhr = null;
            }
            ipXhr = null;
        };
        ipXhr.send();
    }

    function closeAndPurge() {
        dash.forceSaveNotes();
        if (dash._activeXhr) {
            dash._activeXhr.abort();
            dash._activeXhr = null;
        }
        dash.activeTab     = -1;
        dash.notesData     = "";
        dash.wallpaperData = [];
        dash.temp          = "";
        dash.weatherIcon   = "";
        dash.notesLoaded   = false;
        dash.notifyClosed();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            dash.forceSaveNotes();
            if (!outroAnim.running) outroAnim.start();
        }

        Shortcut {
            sequence: "Escape";
            context: Qt.ApplicationShortcut
            onActivated: {
                dash.forceSaveNotes();
                if (!outroAnim.running) outroAnim.start();
            }
        }

        Item {
            id: layerWrapper
            anchors.horizontalCenter: parent.horizontalCenter
            width: 756;
            height: 570
            y: -height - 24

            Timer {
                interval: 20;
                running: true;
                repeat: false
                onTriggered: introAnim.start()
            }

            ParallelAnimation {
                id: introAnim
                NumberAnimation {
                    target: layerWrapper;
                    property: "y";
                    to: 0;
                    duration: 350;
                    easing.type: Easing.OutQuart
                }
            }

            ParallelAnimation {
                id: outroAnim
                NumberAnimation {
                    target: layerWrapper;
                    property: "y";
                    to: -layerWrapper.height - 192;
                    duration: 300;
                    easing.type: Easing.InQuart
                }
                onFinished: dash.closeAndPurge()
            }

            Rectangle {
                id: mainBox
                anchors.centerIn: parent
                width: 720;
                height: 570

                color: Theme.bgMain;
                radius: 12;
                border.color: Theme.border;
                border.width: 0

                MouseArea {
                    anchors.fill: parent;
                    onClicked: function(m) {
                        m.accepted = true;
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 18
                    color: Theme.bgMain
                }

                Row {
                    id: navBar
                    anchors {
                        top: parent.top;
                        left: parent.left;
                        right: parent.right;
                        margins: 19
                    }
                    height: 43;
                    spacing: 14;
                    z: 5

                    Repeater {
                        model: ["󰕮  DASHBOARD", "󰸉  WALLPAPERS"]
                        delegate: Rectangle {
                            width: (navBar.width - 14) / 2;
                            height: 43
                            color: dash.activeTab === index ? Theme.border : "transparent";
                            radius: 10

                            Text {
                                anchors.centerIn: parent;
                                text: modelData
                                font.pixelSize: 12;
                                font.bold: true;
                                textFormat: Text.PlainText
                                color: dash.activeTab === index ? (index === 0 ? Theme.accent : Theme.accentAlt) : Theme.textMuted
                            }

                            MouseArea {
                                anchors.fill: parent;
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dash.switchTab(index);
                                }
                            }
                        }
                    }
                }

                Item {
                    id: contentArea
                    clip: true
                    anchors {
                        top: navBar.bottom;
                        left: parent.left;
                        right: parent.right;
                        bottom: parent.bottom;
                        margins: 19
                    }

                    DragHandler {
                        id: swipeHandler
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false

                        property real lastDx: 0

                        onTranslationChanged: {
                            if (active) {
                                dash.swipeOffset = translation.x;
                                lastDx = translation.x;
                            }
                        }

                        onActiveChanged: {
                            if (!active) {
                                let dx = lastDx;
                                let threshold = (mainBox.width + 48) / 2;
                                let targetIndex = dash.activeTab;

                                if (dx < -threshold && dash.activeTab < 1) {
                                    targetIndex = dash.activeTab + 1;
                                }
                                else if (dx > threshold && dash.activeTab > 0) {
                                    targetIndex = dash.activeTab - 1;
                                }

                                if (targetIndex !== dash.activeTab) {
                                    if (targetIndex > dash.activeTab) {
                                        dash.swipeOffset += (mainBox.width + 48);
                                    } else {
                                        dash.swipeOffset -= (mainBox.width + 48);
                                    }

                                    dash.animatingTab = dash.activeTab;
                                    dash.activeTab = targetIndex;
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
                            if (accumulatedDelta < -150 && dash.activeTab < 1) {
                                dash.switchTab(dash.activeTab + 1);
                                accumulatedDelta = 0;
                            } else if (accumulatedDelta > 150 && dash.activeTab > 0) {
                                dash.switchTab(dash.activeTab - 1);
                                accumulatedDelta = 0;
                            }
                        }
                    }


                    Component {
                        id: modulesComp
                        Item {
                            id: modRoot
                            anchors.fill: parent

                            property var diskData: []

                            Component.onDestruction: {
                                modRoot.diskData = [];
                            }

                            Process {
                                id: sysCmd;
                                command: [];
                                stdout: SplitParser {}
                            }

                            Process {
                                id: diskProc
                                command: ["sh", "-c",
                                "df -h --output=target,size,avail,pcent | " +
                                "tail -n +2 | " +
                                "awk '{gsub(\"%\",\"\",$4); print $1\"|\"$2\"|\"$3\"|\"$4}'"]
                                property string buffer: ""

                                stdout: SplitParser {
                                    onRead: function(d) {
                                        diskProc.buffer += d + "\n";
                                    }
                                }
                                onRunningChanged: {
                                    if (running) return;
                                    if (buffer.length === 0) return;
                                    modRoot.diskData = buffer.split("\n")
                                    .filter(function(l) { return l.length > 0; })
                                    .map(function(l)    { return l.split("|"); })
                                    .filter(function(p) {
                                        return p.length === 4 && (p[0] === "/" || p[0] === "/home");
                                    })
                                    .map(function(p) {
                                        return {
                                            name:  p[0] === "/" ? "ROOT" : "HOME",
                                            size:  p[1],
                                            avail: p[2],
                                            pct: ~~p[3]
                                        };
                                    });
                                    buffer = "";
                                }
                            }

                            Timer {
                                id: initModules
                                interval: 400;
                                running: true;
                                repeat: false
                                onTriggered: {
                                    diskProc.running = true;
                                    const age = Date.now() - dash._weatherFetchedAt;
                                    if (dash._weatherFetchedAt === 0 || age > 3600000) {
                                        dash.fetchWeather();
                                    }
                                }
                            }

                            Row {
                                id: midRow;
                                width: parent.width;
                                height: 372;
                                spacing: 19

                                Column {
                                    width: 259;
                                    height: parent.height;
                                    spacing: 17

                                    Rectangle {
                                        width: parent.width;
                                        height: 307;
                                        color: Theme.border;
                                        radius: 10

                                        ColumnLayout {
                                            anchors.fill: parent;
                                            anchors.margins: 10

                                            Text {
                                                text: Qt.formatDate(dash.today, "MMMM yyyy").toUpperCase()
                                                color: Theme.accent;
                                                font.pixelSize: 12;
                                                font.bold: true
                                                Layout.alignment: Qt.AlignHCenter;
                                                textFormat: Text.PlainText
                                            }

                                            GridLayout {
                                                columns: 7;
                                                Layout.fillWidth: true

                                                Repeater {
                                                    model: ["S","M","T","W","T","F","S"]
                                                    Text {
                                                        text: modelData;
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        color: Theme.textMuted;
                                                        font.pixelSize: 10;
                                                        textFormat: Text.PlainText
                                                    }
                                                }

                                                Repeater {
                                                    model: 42
                                                    delegate: Rectangle {
                                                        Layout.preferredWidth: 26;
                                                        Layout.preferredHeight: 26;
                                                        radius: 5

                                                        readonly property int  dNum:  index - dash.firstDayCache + 1
                                                        readonly property bool valid: dNum > 0 && dNum <= dash.daysInMonthCache

                                                        color: (valid && dNum === dash.selectedDay) ? Theme.accent : "transparent"
                                                        visible: valid

                                                        Text {
                                                            anchors.centerIn: parent;
                                                            text: parent.dNum
                                                            color: parent.dNum === dash.selectedDay ? Theme.bgMain : parent.dNum === dash.today.getDate() ? Theme.accent : Theme.textMain
                                                            font.pixelSize: 11;
                                                            textFormat: Text.PlainText
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width;
                                        height: 48;
                                        color: Theme.border;
                                        radius: 10

                                        Row {
                                            anchors.centerIn: parent;
                                            spacing: 24

                                            Repeater {
                                                model: dash.powerActions
                                                delegate: Text {
                                                    text: modelData.i;
                                                    font.pixelSize: 19;
                                                    font.family: "Symbols Nerd Font"
                                                    color: pwMa.containsMouse ? Theme[modelData.clr] : Theme.textMuted

                                                    Behavior on color {
                                                        ColorAnimation { duration: 200;
                                                            easing.type: Easing.InOutQuad }
                                                    }

                                                    MouseArea {
                                                        id: pwMa;
                                                        anchors.fill: parent;
                                                        hoverEnabled: true;
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            sysCmd.command = ["sh", "-c", modelData.c];
                                                            sysCmd.running = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - 259 - 19;
                                    height: parent.height;
                                    spacing: 17

                                    Rectangle {
                                        width: parent.width;
                                        height: 91;
                                        color: Theme.border;
                                        radius: 10

                                        RowLayout {
                                            anchors.centerIn: parent;
                                            spacing: 14

                                            Text {
                                                text: dash.weatherIcon;
                                                font.pixelSize: 36;
                                                color: Theme.info;
                                                font.family: "Symbols Nerd Font"
                                            }

                                            Column {
                                                Text {
                                                    text: dash.temp;
                                                    color: Theme.textMain;
                                                    font.pixelSize: 24;
                                                    font.bold: true;
                                                    textFormat: Text.PlainText
                                                }
                                                Text {
                                                    text: dash.locationName;
                                                    color: Theme.textMuted;
                                                    font.pixelSize: 8;
                                                    textFormat: Text.PlainText
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width;
                                        height: parent.height - 91 - 17
                                        color: Theme.border;
                                        radius: 10

                                        ColumnLayout {
                                            anchors.fill: parent;
                                            anchors.margins: 12;
                                            spacing: 5

                                            Item {
                                                Layout.fillWidth: true;
                                                Layout.fillHeight: true

                                                Flickable {
                                                    id: noteFlick
                                                    anchors {
                                                        left: parent.left;
                                                        top: parent.top;
                                                        bottom: parent.bottom;
                                                        right: noteTrack.left
                                                    }
                                                    clip: true;
                                                    contentHeight: rem.implicitHeight
                                                    flickableDirection: Flickable.VerticalFlick

                                                    TextEdit {
                                                        id: rem
                                                        width: noteFlick.width
                                                        text: dash.notesData
                                                        textFormat: TextEdit.PlainText
                                                        color: Theme.textMain
                                                        font.pixelSize: 12
                                                        font.family: "CaskaydiaCove Nerd Font"
                                                        wrapMode: TextEdit.Wrap
                                                        selectByMouse: true
                                                        selectionColor:    Theme.accent
                                                        selectedTextColor: Theme.bgMain

                                                        onTextChanged: {
                                                            if (!dash.notesLoaded) return;
                                                            if (text === dash.notesData) return;

                                                            dash.notesData     = text;
                                                            dash._lastSaveTime = Date.now();
                                                            saveTimer.restart();
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: noteTrack
                                                    anchors {
                                                        right: parent.right;
                                                        top: parent.top;
                                                        bottom: parent.bottom
                                                    }
                                                    width: 4;
                                                    color: "transparent"
                                                    visible: noteFlick.visibleArea.heightRatio < 1.0

                                                    Rectangle {
                                                        y:      noteFlick.visibleArea.yPosition  * noteTrack.height
                                                        height: Math.max(19, noteFlick.visibleArea.heightRatio * noteTrack.height)
                                                        width:  parent.width;
                                                        radius: 2;
                                                        color: Theme.textMuted
                                                        opacity: noteMa.containsMouse ? 0.85 : 0.45

                                                        Behavior on opacity {
                                                            NumberAnimation { duration: 150 }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: noteMa;
                                                        anchors.fill: parent;
                                                        hoverEnabled: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.top: midRow.bottom;
                                anchors.topMargin: 17
                                anchors.bottom: parent.bottom;
                                width: parent.width
                                color: Theme.border;
                                radius: 10

                                RowLayout {
                                    anchors.fill: parent;
                                    anchors.margins: 17
                                    spacing: modRoot.diskData.length > 1 ? 24 : 0

                                    Repeater {
                                        model: modRoot.diskData
                                        delegate: ColumnLayout {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: modRoot.diskData.length > 1 ? (parent.width - 24) / 2 : parent.width
                                            spacing: 6

                                            readonly property int diskPct: modelData.pct

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: modelData.name;
                                                    color: Theme.accent;
                                                    font.pixelSize: 11;
                                                    font.bold: true;
                                                    textFormat: Text.PlainText
                                                }
                                                Item  { Layout.fillWidth: true }
                                                Text {
                                                    text: modelData.size + "  ·  " + diskPct + "% used";
                                                    color: Theme.textMuted;
                                                    font.pixelSize: 8;
                                                    textFormat: Text.PlainText
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true;
                                                Layout.preferredHeight: 7;
                                                color: Theme.bgMain;
                                                radius: 4

                                                Rectangle {
                                                    property real displayPct: 0
                                                    width: parent.width * (displayPct / 100)
                                                    height: parent.height;
                                                    radius: 4
                                                    color: diskPct > 90 ? Theme.error : diskPct > 70 ? Theme.warning : Theme.info

                                                    Behavior on displayPct {
                                                        NumberAnimation { duration: 600;
                                                            easing.type: Easing.OutQuint }
                                                    }

                                                    Component.onCompleted: {
                                                        displayPct = diskPct;
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.avail + " free";
                                                color: Theme.textMuted;
                                                font.pixelSize: 8;
                                                Layout.alignment: Qt.AlignRight;
                                                textFormat: Text.PlainText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }


                    Component {
                        id: wallComp
                        Item {
                            id: wallRoot
                            anchors.fill: parent

                            property string searchText: ""
                            readonly property var awwwTransitions: ["fade","wipe","slide","wave","grow","center","outer"]

                            property var filteredData: {
                                const q = wallRoot.searchText.toLowerCase().trim();
                                if (q.length === 0) return dash.wallpaperData;
                                return dash.wallpaperData.filter(function(w) {
                                    return w.name.toLowerCase().indexOf(q) !== -1;
                                });
                            }

                            Timer {
                                id: initWall
                                interval: 400;
                                running: true;
                                repeat: false
                                onTriggered: {
                                    if (dash.wallpaperData.length === 0) {
                                        wpScanner.running = true;
                                    }
                                }
                            }

                            Process {
                                id: awwwProc;
                                command: []
                            }

                            Process {
                                id: wpScanner
                                command: ["sh", "-c",
                                "mkdir -p \"$HOME/.wallpapers\" && " +
                                "find \"$HOME/.wallpapers\" -maxdepth 1 -type f " +
                                "\\( -iname \"*.jpg\" -o -iname \"*.png\" -o -iname \"*.jpeg\" -o -iname \"*.jxl\" \\) " +
                                "-printf \"%f|file://%p\\n\" | sort"]
                                property string buffer: ""
                                stdout: SplitParser {
                                    onRead: function(d) {
                                        wpScanner.buffer += d + "\n";
                                    }
                                }
                                onRunningChanged: {
                                    if (running) return;
                                    if (buffer.length === 0) return;

                                    dash.wallpaperData = buffer.split("\n")
                                    .filter(function(l) { return l.length > 0; })
                                    .map(function(l)    { return l.split("|"); })
                                    .filter(function(p) { return p.length === 2; })
                                    .map(function(p)    { return { name: p[0], path: p[1] }; });
                                    buffer = "";
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent;
                                spacing: 7

                                Rectangle {
                                    Layout.fillWidth: true;
                                    Layout.preferredHeight: 41
                                    color: Theme.border;
                                    radius: 10

                                    RowLayout {
                                        anchors { fill: parent;
                                            leftMargin: 12; rightMargin: 43 }
                                            spacing: 7

                                            Text {
                                                text: "󰍉";
                                                color: Theme.textMuted
                                                font.family: "Symbols Nerd Font";
                                                font.pixelSize: 17
                                                textFormat: Text.PlainText
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Item {
                                                Layout.fillWidth: true;
                                                Layout.fillHeight: true

                                                TextInput {
                                                    id: wallSearch
                                                    anchors {
                                                        left: parent.left
                                                        right: parent.right
                                                        verticalCenter: parent.verticalCenter
                                                    }
                                                    color: Theme.textMain;
                                                    font.pixelSize: 12
                                                    font.family: "CaskaydiaCove Nerd Font"
                                                    selectionColor: Theme.accent;
                                                    selectedTextColor: Theme.bgMain

                                                    onTextEdited: {
                                                        wallRoot.searchText = text;
                                                    }

                                                    Text {
                                                        anchors.fill: parent
                                                        text: "Search wallpapers..."
                                                        color: Theme.textMuted;
                                                        font.pixelSize: 12
                                                        font.family: "CaskaydiaCove Nerd Font"
                                                        textFormat: Text.PlainText
                                                        visible: wallSearch.text.length === 0 && !wallSearch.activeFocus
                                                    }
                                                }
                                            }
                                    }

                                    Rectangle {
                                        anchors { right: parent.right; rightMargin: 10;
                                            verticalCenter: parent.verticalCenter }
                                            width: 24;
                                            height: 24;
                                            radius: 5
                                            visible: wallSearch.text.length > 0
                                            color: clrBtn.containsMouse ? Theme.bgMain : "transparent"

                                            Behavior on color {
                                                ColorAnimation { duration: 80 }
                                            }

                                            Text {
                                                anchors.centerIn: parent;
                                                text: "✕";
                                                color: Theme.textMuted;
                                                font.pixelSize: 11;
                                                textFormat: Text.PlainText
                                            }

                                            MouseArea {
                                                id: clrBtn;
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor;
                                                hoverEnabled: true
                                                onClicked: {
                                                    wallSearch.text = "";
                                                    wallRoot.searchText = "";
                                                }
                                            }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom;
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: wallSearch.activeFocus ? parent.width - 19 : 0;
                                        height: 1
                                        color: Theme.accent;
                                        radius: 1

                                        Behavior on width {
                                            NumberAnimation { duration: 180;
                                                easing.type: Easing.OutQuart }
                                        }
                                    }
                                }

                                Text {
                                    id: countLabel
                                    Layout.fillWidth: true
                                    visible: wallRoot.searchText.length > 0
                                    text: wallRoot.filteredData.length + " / " + dash.wallpaperData.length + " wallpapers"
                                    color: Theme.textMuted;
                                    font.pixelSize: 10;
                                    textFormat: Text.PlainText
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    GridView {
                                        id: wallGrid
                                        anchors {
                                            left: parent.left;
                                            top: parent.top
                                            bottom: parent.bottom;
                                            right: wallTrack.left
                                        }
                                        clip:       true
                                        reuseItems: true


                                        model: wallRoot.filteredData

                                        cellWidth:  Math.floor((parent.width - 7) / 3)
                                        cellHeight: 182

                                        Text {
                                            anchors.centerIn: parent
                                            visible: wallRoot.filteredData.length === 0
                                            text: dash.wallpaperData.length === 0
                                            ? "No wallpapers found in ~/.wallpapers"
                                            : "No results for \"" + wallRoot.searchText + "\""
                                            color: Theme.textMuted;
                                            font.pixelSize: 12;
                                            textFormat: Text.PlainText
                                            wrapMode: Text.WordWrap;
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width * 0.7
                                        }

                                        delegate: Item {
                                            width:  wallGrid.cellWidth
                                            height: wallGrid.cellHeight

                                            Rectangle {
                                                anchors.fill: parent;
                                                anchors.margins: 5
                                                color: Theme.border;
                                                radius: 10;
                                                clip: true

                                                Column {
                                                    anchors.fill: parent
                                                    Image {
                                                        width:  parent.width
                                                        height: parent.height
                                                        source: modelData.path
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        sourceSize.width: wallGrid.cellWidth
                                                        sourceSize.height: wallGrid.cellHeight
                                                        cache: true;
                                                        smooth: true;
                                                        mipmap: false

                                                        Component.onDestruction: {
                                                            source = "";
                                                        }
                                                    }
                                                }

                                                Text {
                                                    anchors {
                                                        left: parent.left;
                                                        right: parent.right;
                                                        bottom: parent.bottom
                                                    }
                                                    leftPadding: 8;
                                                    rightPadding: 8;
                                                    height: 41
                                                    text: modelData.name;
                                                    color: Theme.textMain;
                                                    font.pixelSize: 10
                                                    verticalAlignment: Text.AlignVCenter
                                                    horizontalAlignment: Text.AlignLeft
                                                    elide: Text.ElideRight;
                                                    textFormat: Text.PlainText
                                                }

                                                MouseArea {
                                                    anchors.fill: parent;
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const t = wallRoot.awwwTransitions[
                                                            Math.floor(Math.random() * wallRoot.awwwTransitions.length)];
                                                            const path = modelData.path.replace("file://", "");


                                                            Quickshell.execDetached([
                                                                "sh", "-c",
                                                                "awww img '" + path + "' --transition-type " + t + " --transition-duration 1.5 & " +
                                                                "mkdir -p ~/.cache && nice -n 19 matugen image '" + path + "' -t scheme-fidelity -j hex --source-color-index 0 > ~/.cache/m3-colors.json && echo 'm3_update' >> /tmp/qs_theme"
                                                            ]);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: wallTrack
                                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                                        width: 5;
                                        color: "transparent"
                                        visible: wallGrid.visibleArea.heightRatio < 1.0

                                        Rectangle {
                                            y:      wallGrid.visibleArea.yPosition  * wallTrack.height
                                            height: Math.max(24, wallGrid.visibleArea.heightRatio * wallTrack.height)
                                            width:  parent.width;
                                            radius: 2
                                            color: Theme.textMuted
                                            opacity: wallMa.containsMouse || wallMa.pressed ? 0.85 : 0.5

                                            Behavior on opacity {
                                                NumberAnimation { duration: 150 }
                                            }
                                        }

                                        MouseArea {
                                            id: wallMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            preventStealing: true
                                            property real lastY: 0

                                            onPressed: function(mouse) {
                                                lastY = mouse.y;


                                                let tY = wallGrid.visibleArea.yPosition * wallTrack.height;
                                                let tH = Math.max(24, wallGrid.visibleArea.heightRatio * wallTrack.height);

                                                if (mouse.y < tY || mouse.y > tY + tH) {
                                                    let trackScrollable = wallTrack.height - tH;
                                                    if (trackScrollable > 0) {
                                                        let pct = Math.max(0, Math.min((mouse.y - tH / 2) / trackScrollable, 1.0));
                                                        wallGrid.contentY = pct * (wallGrid.contentHeight - wallGrid.height);
                                                    }
                                                }
                                            }

                                            onPositionChanged: function(mouse) {
                                                if (pressed) {
                                                    let dy = mouse.y - lastY;
                                                    let tH = Math.max(24, wallGrid.visibleArea.heightRatio * wallTrack.height);
                                                    let trackScrollable = wallTrack.height - tH;

                                                    if (trackScrollable > 0) {
                                                        let pctChange = dy / trackScrollable;
                                                        let contentScrollable = wallGrid.contentHeight - wallGrid.height;


                                                        wallGrid.contentY = Math.max(0, Math.min(wallGrid.contentY + (pctChange * contentScrollable), contentScrollable));
                                                    }
                                                    lastY = mouse.y;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        id: modLoader
                        width: parent.width;
                        anchors.top: parent.top;
                        anchors.bottom: parent.bottom
                        active: true
                        sourceComponent: modulesComp
                        visible: x > -width && x < mainBox.width
                        x: ((0 - dash.activeTab) * (parent.width + 48)) + dash.swipeOffset
                    }

                    Loader {
                        id: wallLoader
                        width: parent.width;
                        anchors.top: parent.top;
                        anchors.bottom: parent.bottom

                        active: true
                        sourceComponent: wallComp
                        visible: x > -width && x < mainBox.width
                        x: ((1 - dash.activeTab) * (parent.width + 48)) + dash.swipeOffset
                    }
                }
            }

            Shape {
                anchors.top: mainBox.top
                anchors.right: mainBox.left
                width: 18;
                height: 18
                ShapePath {
                    fillColor: Theme.bgMain
                    strokeWidth: 0
                    startX: 0;
                    startY: 0
                    PathLine { x: 18;
                        y: 0 }
                        PathLine { x: 18;
                            y: 18 }
                            PathArc { x: 0;
                                y: 0; radiusX: 18; radiusY: 18; direction: PathArc.Counterclockwise }
                }
            }

            Shape {
                anchors.top: mainBox.top
                anchors.left: mainBox.right
                width: 18; height: 18
                ShapePath {
                    fillColor: Theme.bgMain
                    strokeWidth: 0
                    startX: 0;
                    startY: 0
                    PathLine { x: 18;
                        y: 0 }
                        PathArc { x: 0;
                            y: 18; radiusX: 18; radiusY: 18; direction: PathArc.Counterclockwise }
                            PathLine { x: 0;
                                y: 0 }
                }
            }
        }
    }
}
