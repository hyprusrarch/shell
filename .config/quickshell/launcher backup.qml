import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.settings 1.0 
import Quickshell
import Quickshell.Io

PanelWindow {
  id: root

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  focusable: true
  color: "transparent"

  // --- Configuration ---
  property string fileManager: "nautilus"

  readonly property string fontFamily: "Noto Sans"
  readonly property int fontSize: 12
  
  // --- State Variables ---
  property bool editMode: false

  // --- State for standalone calculator ---
  property string calcResult: ""
  property string rawMathCmd: ""

  // --- NATIVE State Management ---
  Settings {
    id: appSettings
    property string savedOrder: "[]"      // Explicit order
    property string frequencyData: "{}"   // Fallback usage frequency
  }

  // --- Anti-Race Condition Logic ---
  property bool listStabilized: false
  property int lastAppCount: -1

  Timer {
    id: stabilityTimer
    interval: 250
    repeat: true
    running: true
    onTriggered: function() {
      var currentCount = DesktopEntries.applications.values.length;
      if (currentCount > 0 && currentCount === root.lastAppCount) {
        if (!root.listStabilized) {
          root.listStabilized = true;
          updateModel();
        }
      } else if (currentCount > 0) {
        root.lastAppCount = currentCount;
      }
    }
  }

  Process { id: adhocProcess }

  Timer {
    id: quitTimer
    interval: 50
    onTriggered: function() { Qt.quit() }
  }

  function saveFreq(appName) {
    var freqs = {};
    try { freqs = JSON.parse(appSettings.frequencyData); } catch(e) {}
    freqs[appName] = (freqs[appName] || 0) + 1;
    appSettings.frequencyData = JSON.stringify(freqs);
  }

  function saveCurrentOrder() {
    var newOrder = [];
    for (var i = 0; i < appModel.count; i++) {
      if (!appModel.get(i).isCustom) {
        newOrder.push(appModel.get(i).appName);
      }
    }
    appSettings.savedOrder = JSON.stringify(newOrder);
  }

  // --- Dynamic Model ---
  ListModel { id: appModel }

  function updateModel() {
    if (!root.listStabilized) return;
    var allApps = DesktopEntries.applications.values;
    if (allApps.length === 0) return;

    appModel.clear();
    var rawText = app_search.text;
    var query = rawText.toLowerCase();

    // --- Standalone Calculator Logic ---
    root.calcResult = "";
    root.rawMathCmd = "";
    
    var isExplicitCalc = rawText.startsWith("=");
    var mathRegex = /^[\d\s\+\-\*\/\(\)\.]+$/;
    var isMath = mathRegex.test(rawText) && /[\+\-\*\/]/.test(rawText) && /\d/.test(rawText);

    if (isExplicitCalc || isMath) {
      var mathStr = isExplicitCalc ? rawText.substring(1).trim() : rawText.trim();
      if (mathStr.length > 0) {
        try {
          if (/^[0-9\+\-\*\/\(\)\.\s]*$/.test(mathStr)) {
            var result = eval(mathStr);
            if (result !== undefined && !isNaN(result) && result !== Infinity) {
              root.calcResult = "= " + result;
              root.rawMathCmd = result.toString();
              if (isExplicitCalc) return; 
            }
          }
        } catch(e) {}
      }
    }

    if (rawText.startsWith(":")) {
      var cmd = rawText.substring(1).trim();
      if (cmd.length > 0) appModel.append({ appName: "Run command: " + cmd, appIcon: "foot", isCustom: true, type: "command", cmd: cmd, path: "", appId: "" });
      return;
    }
    if (rawText.startsWith("/") || rawText.startsWith("~")) {
      appModel.append({ appName: "Open path: " + rawText, appIcon: "org.gnome.Nautilus", isCustom: true, type: "path", cmd: "", path: rawText, appId: "" });
      return;
    }

    var appMap = {};
    var validApps = [];
    for (var i = 0; i < allApps.length; i++) {
      var app = allApps[i];
      if (!app.noDisplay && !app.runInTerminal) {
        appMap[app.name] = app;
        validApps.push(app);
      }
    }

    var parsedOrder = [];
    try { parsedOrder = JSON.parse(appSettings.savedOrder); } catch(e) {}
    
    var freqs = {};
    try { freqs = JSON.parse(appSettings.frequencyData); } catch(e) {}

    var finalOrder = [];
    var used = {};
    if (parsedOrder && parsedOrder.length > 0) {
      for (var j = 0; j < parsedOrder.length; j++) {
        var name = parsedOrder[j];
        if (appMap[name] && !used[name]) {
          finalOrder.push(appMap[name]);
          used[name] = true;
        }
      }
    }

    var remainingApps = [];
    for (var k = 0; k < validApps.length; k++) {
      if (!used[validApps[k].name]) remainingApps.push(validApps[k]);
    }

    remainingApps.sort(function(a, b) {
      var freqA = freqs[a.name] || 0;
      var freqB = freqs[b.name] || 0;
      if (freqB !== freqA) return freqB - freqA; 
      return a.name.localeCompare(b.name);       
    });
    
    for (var m = 0; m < remainingApps.length; m++) {
      finalOrder.push(remainingApps[m]);
    }

    for (var n = 0; n < finalOrder.length; n++) {
      var appData = finalOrder[n];
      var matchesSearch = true;
      if (query.length > 0) {
        matchesSearch = appData.name.toLowerCase().includes(query) ||
                        appData.keywords.some(function(k) { return k.toLowerCase().includes(query); });
      }

      if (matchesSearch) {
        appModel.append({
          appName: appData.name,
          appIcon: appData.icon || "",
          appId: appData.id || appData.name + ".desktop",
          isCustom: false,
          type: "",
          cmd: "",
          path: ""
        });
      }
    }

    // --- Web Search Fallback ---
    if (query.length > 0) {
      appModel.append({
        appName: "Search the web for '" + rawText + "'",
        appIcon: "system-search", 
        appId: "",
        isCustom: true,
        type: "search",
        cmd: rawText,
        path: ""
      });
    }

    app_list.currentIndex = 0;
  }

  // --- UI Layout ---
  MouseArea {
    anchors.fill: parent
    onClicked: function() { Qt.quit() }

    Shortcut {
      sequence: "Escape"
      onActivated: function() { Qt.quit() }
    }

    Rectangle {
      width: 450
      height: 530 
      anchors.centerIn: parent
      color: Theme.bgMain
      radius: 8

      MouseArea { 
        anchors.fill: parent
        onClicked: function(mouse) { mouse.accepted = true } 
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          TextField {
            id: app_search
            placeholderText: root.listStabilized ? "Search, calculate (=), run (:), paths (/)..." : "Loading apps..."
            focus: true
            Layout.fillWidth: true
            background: Rectangle { color: "transparent" }
            color: Theme.textMain
            placeholderTextColor: Theme.textMuted
            font { family: root.fontFamily; pixelSize: root.fontSize }
            enabled: root.listStabilized

            onTextChanged: function() { updateModel() }

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Up) app_list.decrementCurrentIndex()
              else if (event.key === Qt.Key_Down) app_list.incrementCurrentIndex()
              else if (event.key === Qt.Key_Return && !root.editMode) {
                // If calculator has a valid result, prioritize copying the result!
                if (root.calcResult !== "") {
                  var safeMath = root.rawMathCmd.replace(/'/g, "'\\''");
                  adhocProcess.command = ["bash", "-c", "echo -n '" + safeMath + "' | wl-copy"];
                  adhocProcess.running = true;
                  quitTimer.start();
                } else if (app_list.currentItem) {
                  app_list.currentItem.launch();
                }
              }
            }
          }

          Rectangle {
            Layout.preferredWidth: 75  
            Layout.preferredHeight: 32
            radius: 4
            color: root.editMode ? Theme.bgDark : "transparent"
            border.color: Theme.accent
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 6

              Text {
                id: penIcon
                text: "✎"
                color: Theme.textMain
                font { family: root.fontFamily; pixelSize: 14 }
                transform: Scale { origin.x: penIcon.width / 2; xScale: -1 } 
              }

              Text {
                text: root.editMode ? "Done" : "Edit"
                color: Theme.textMain
                font { family: root.fontFamily; pixelSize: 12; bold: true }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: function() {
                root.editMode = !root.editMode;
                if (!root.editMode) app_search.forceActiveFocus();
              }
            }
          }
        }

        // --- STANDALONE CALCULATOR BLOCK (25% Smaller) ---
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.calcResult !== "" ? 60 : 0
          visible: root.calcResult !== ""
          color: Theme.bgDark 
          radius: 8
          clip: true

          Text {
            anchors.centerIn: parent
            text: root.calcResult
            color: Theme.textMain
            font { family: root.fontFamily; pixelSize: 24; bold: true }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            color: Theme.bgMain 
            radius: 4
            width: 32
            height: 20
            
            Text {
              anchors.centerIn: parent
              text: "⏎ 1"
              color: Theme.textMuted
              font { family: root.fontFamily; pixelSize: 10; bold: true }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function() {
              var safeMath = root.rawMathCmd.replace(/'/g, "'\\''");
              adhocProcess.command = ["bash", "-c", "echo -n '" + safeMath + "' | wl-copy"];
              adhocProcess.running = true;
              quitTimer.start();
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          clip: true

          ListView {
            id: app_list
            anchors.fill: parent
            spacing: 4
            currentIndex: 0
            cacheBuffer: 500
            model: appModel
            
            boundsBehavior: Flickable.StopAtBounds

            MouseArea {
              anchors.fill: parent
              propagateComposedEvents: true
              onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0) {
                  if (app_list.atYBeginning) { app_list.positionViewAtEnd(); wheel.accepted = true; } 
                  else { wheel.accepted = false; }
                } else if (wheel.angleDelta.y < 0) {
                  if (app_list.atYEnd) { app_list.positionViewAtBeginning(); wheel.accepted = true; } 
                  else { wheel.accepted = false; }
                }
              }
            }

            delegate: Item {
              id: delegate_item
              width: app_list.width
              height: 38
              property int visualIndex: index

              function launch() {
                if (root.editMode) return; 
                
                if (model.isCustom) {
                  adhocProcess.running = false;
                  
                  // --- WEB SEARCH LAUNCH ---
                  if (model.type === "search") {
                    var searchUrl = "https://www.google.com/search?q=" + encodeURIComponent(model.cmd);
                    var safeUrl = searchUrl.replace(/'/g, "'\\''");
                    // Using hyprctl dispatch exec xdg-open forces the default browser
                    adhocProcess.command = ["hyprctl", "dispatch", "exec", "--", "xdg-open '" + safeUrl + "'"];
                    adhocProcess.running = true;
                  } 
                  // --- COMMAND OR PATH LAUNCH ---
                  else {
                    var execString = "";
                    if (model.type === "command") {
                      var safeCmd = model.cmd.replace(/'/g, "'\\''");
                      execString = "foot bash -c '" + safeCmd + "; exec bash'";
                    } else if (model.type === "path") {
                      var rawPath = model.path;
                      var finalPathStr = rawPath.startsWith("~") ? "$HOME/\"" + rawPath.substring(1).replace(/^\//, "").replace(/"/g, '\\"') + "\"" : "\"" + rawPath.replace(/"/g, '\\"') + "\"";
                      var bashCmd = root.fileManager + " " + finalPathStr;
                      execString = "bash -c '" + bashCmd.replace(/'/g, "'\\''") + "'";
                    }
                    adhocProcess.command = ["hyprctl", "dispatch", "exec", "--", execString];
                    adhocProcess.running = true;
                  }
                } else {
                  root.saveFreq(model.appName); 
                  var apps = DesktopEntries.applications.values;
                  for (var i = 0; i < apps.length; i++) {
                    if (apps[i].name === model.appName) {
                      apps[i].execute();
                      break;
                    }
                  }
                }
                quitTimer.start();
              }

              Rectangle {
                id: contentItem
                width: parent.width
                height: parent.height
                radius: 4
                color: delegate_item.ListView.isCurrentItem && !root.editMode ? Theme.bgDark : (root.editMode ? "#1e1e2e" : "transparent")

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  Button {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    padding: 0
                    enabled: false
                    background: null
                    icon.name: (model.appIcon && !model.appIcon.startsWith("/")) ? model.appIcon : "application-x-executable"
                    icon.source: (model.appIcon && model.appIcon.startsWith("/")) ? "file://" + model.appIcon : ""
                    icon.width: 24
                    icon.height: 24
                    icon.color: "transparent" 
                  }

                  Text {
                    text: model.appName
                    color: delegate_item.ListView.isCurrentItem && !root.editMode ? Theme.accent : Theme.textMain
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font { family: root.fontFamily; pixelSize: root.fontSize }
                  }

                  // --- EXPLICIT REORDERING BUTTONS ---
                  RowLayout {
                    visible: root.editMode && !model.isCustom && app_search.text === "" && root.listStabilized
                    spacing: 4

                    Rectangle {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      radius: 4
                      color: delegate_item.visualIndex > 0 ? Theme.bgMain : "transparent"
                      border.color: delegate_item.visualIndex > 0 ? Theme.border : "transparent"

                      Text { text: "↑"; anchors.centerIn: parent; color: delegate_item.visualIndex > 0 ? Theme.textMain : Theme.textMuted; font.bold: true }
                      
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: delegate_item.visualIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: function() {
                          if (delegate_item.visualIndex > 0) {
                            appModel.move(delegate_item.visualIndex, delegate_item.visualIndex - 1, 1);
                            root.saveCurrentOrder();
                          }
                        }
                      }
                    }

                    Rectangle {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      radius: 4
                      color: delegate_item.visualIndex < appModel.count - 1 ? Theme.bgMain : "transparent"
                      border.color: delegate_item.visualIndex < appModel.count - 1 ? Theme.border : "transparent"

                      Text { text: "↓"; anchors.centerIn: parent; color: delegate_item.visualIndex < appModel.count - 1 ? Theme.textMain : Theme.textMuted; font.bold: true }
                      
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: delegate_item.visualIndex < appModel.count - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: function() {
                          if (delegate_item.visualIndex < appModel.count - 1) {
                            appModel.move(delegate_item.visualIndex, delegate_item.visualIndex + 1, 1);
                            root.saveCurrentOrder();
                          }
                        }
                      }
                    }
                  }

                  // --- RED DELETE BUTTON ---
                  Rectangle {
                    visible: root.editMode && !model.isCustom
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.leftMargin: 4
                    radius: 4
                    color: "#f38ba8" 
                    
                    Text { text: "🗑️"; anchors.centerIn: parent; font.pixelSize: 12 }
                    
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: function() {
                        var safeId = model.appId.replace(/'/g, "'\\''");
                        // Creates a local override with NoDisplay=true to safely hide apps forever without root access
                        var cmd = "ID='" + safeId + "'; " +
                                  "[[ \"$ID\" != *.desktop ]] && ID=\"$ID.desktop\"; " +
                                  "FILE=$(find ~/.local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications /var/lib/snapd/desktop/applications -maxdepth 5 -name \"$ID\" 2>/dev/null | head -n 1); " +
                                  "if [ -n \"$FILE\" ]; then " +
                                  "  if [[ \"$FILE\" == \"$HOME/.local/share/applications/\"* ]]; then " +
                                  "    rm \"$FILE\"; " +
                                  "  else " +
                                  "    mkdir -p \"$HOME/.local/share/applications\"; " +
                                  "    LOCAL_FILE=\"$HOME/.local/share/applications/$(basename \"$FILE\")\"; " +
                                  "    cp \"$FILE\" \"$LOCAL_FILE\"; " +
                                  "    sed -i '/^NoDisplay=/d' \"$LOCAL_FILE\"; " +
                                  "    echo 'NoDisplay=true' >> \"$LOCAL_FILE\"; " +
                                  "  fi; " +
                                  "fi";
                                  
                        adhocProcess.command = ["bash", "-c", cmd];
                        adhocProcess.running = true;
                        
                        // Instantly removes it from the screen for visual feedback
                        appModel.remove(delegate_item.visualIndex);
                        root.saveCurrentOrder(); 
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.rightMargin: root.editMode ? 100 : 40 
                  onClicked: function() { if (!root.editMode) app_list.currentIndex = index; }
                  onDoubleClicked: function() { if (!root.editMode) delegate_item.launch(); }
                }
              }
            }
          }
        }
        
        // --- Theme Switcher Footer ---
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 30
          color: "transparent"

          Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.border
          }

          RowLayout {
            anchors.fill: parent
            anchors.topMargin: 8

            Text {
              Layout.fillWidth: true
              text: "Theme: " + Theme.currentTheme.replace("_", " ")
              color: Theme.textMuted
              font { family: root.fontFamily; pixelSize: 11 }
              font.capitalization: Font.Capitalize
            }

            Rectangle {
              Layout.preferredWidth: 90
              Layout.preferredHeight: 24
              radius: 4
              color: Theme.accent

              Text {
                anchors.centerIn: parent
                text: "Cycle Theme"
                color: Theme.bgMain
                font { family: root.fontFamily; pixelSize: 11; bold: true }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function() {
                    Theme.cycleTheme();
                    if (!root.editMode) app_search.forceActiveFocus(); 
                }
              }
            }
          }
        }
      }
    }
  }
}
