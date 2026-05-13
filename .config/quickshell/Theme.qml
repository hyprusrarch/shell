pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "./themes.js" as ThemeConfig

QtObject {
  id: root

  readonly property var themeData: ThemeConfig.themes
  readonly property var themeList: Object.keys(ThemeConfig.themes)

  property Settings themeSettings: Settings {
    category: "Appearance"
    property string savedTheme: "tokyo_night_storm"
  }

  property string currentTheme: themeSettings.savedTheme

  // Reactive Semantic Colors
  property color bgMain: "#000000"
  property color bgDark: "#000000"
  property color textMain: "#ffffff"
  property color textMuted: "#aaaaaa"
  property color accent: "#ffffff"
  property color accentAlt: "#ffffff"
  property color border: "#ffffff"

  // Reactive Status Colors
  property color error: "#ff0000"
  property color warning: "#ffff00"
  property color success: "#00ff00"
  property color info: "#0000ff"

  property color background: bgMain
  property color foreground: textMain


  property Process hyprlockWriter: Process {
    running: false
    command: []
  }

  function updateHyprlockColors() {
    let b = String(root.bgMain).replace("#", "").slice(-6);
    let t = String(root.textMain).replace("#", "").slice(-6);
    let a = String(root.accent).replace("#", "").slice(-6);
    let s = String(root.bgDark).replace("#", "").slice(-6);

    let conf = "$base = rgb(" + b + ")\\n$text = rgb(" + t + ")\\n$accent = rgb(" + a + ")\\n$surface = rgb(" + s + ")\\n";

    hyprlockWriter.command = ["sh", "-c", "printf '%b' '" + conf + "' > ~/.cache/hyprlock-colors.conf"];
    hyprlockWriter.running = true;
  }

  property Process themeSyncWatcher: Process {
    running: true
    command: ["bash", "-c", "touch /tmp/qs_theme && tail -n 0 -F /tmp/qs_theme"]
    stdout: SplitParser {
      onRead: function(d) {
        let t = d.trim();

        if (t === "m3_update") {
          if (root.currentTheme === "adaptive") {
            m3Debounce.restart();
          }
          return;
        }

        if (t !== "" && t !== root.currentTheme && (themeData[t] || t === "adaptive")) {
          root.applyTheme(t, true);
        }
      }
    }
  }

  property Process themeWriter: Process {
    running: false
    command: []
  }

  // ── MATERIAL 3 ADAPTIVE THEMING ENGINE ──
  property Process readM3: Process {
    running: false
    command: ["sh", "-c", "cat ~/.cache/m3-colors.json"]
    property string buffer: ""
    stdout: SplitParser {
      onRead: function(d) { readM3.buffer += d; }
    }
    onRunningChanged: {
      if (running) return;
      try {
        let m3 = JSON.parse(buffer);
        let c = m3.colors;

        root.bgMain    = c.surface.dark.color;
        root.bgDark    = c.surface_container.dark.color;
        root.textMain  = c.on_surface.dark.color;
        root.textMuted = c.outline.dark.color;

        root.accent    = c.primary.dark.color;
        root.accentAlt = c.tertiary.dark.color;
        root.border    = Qt.darker(c.outline_variant.dark.color, 1.25);

        root.error     = c.error.dark.color;
        root.warning   = c.secondary.dark.color;
        root.success   = c.primary_fixed.dark.color;
        root.info      = c.tertiary_fixed.dark.color;

        // Push M3 colors to Hyprlock
        root.updateHyprlockColors();
      } catch(e) {
        console.log("Adaptive Theme: Error parsing Matugen JSON - " + e);
      }
      buffer = "";
    }
  }

  property Timer m3Debounce: Timer {
    interval: 100
    repeat: false
    onTriggered: {
      readM3.running = false;
      readM3.running = true;
    }
  }

  function applyTheme(themeName, fromSync = false) {
    if (themeName === "adaptive") {
      currentTheme = themeName;
      themeSettings.savedTheme = themeName;

      if (!fromSync) {
        themeWriter.command = ["sh", "-c", "echo '" + themeName + "' >> /tmp/qs_theme"];
        themeWriter.running = true;
      }

      readM3.running = false;
      readM3.running = true;
      return;
    }

    const data = themeData[themeName];
    if (data) {
      currentTheme = themeName;
      themeSettings.savedTheme = themeName;

      if (!fromSync) {
        themeWriter.command = ["sh", "-c", "echo '" + themeName + "' >> /tmp/qs_theme"];
        themeWriter.running = true;
      }

      bgMain = data.bgMain;
      bgDark = data.bgDark;
      textMain = data.textMain;
      textMuted = data.textMuted;
      accent = data.accent;
      accentAlt = data.accentAlt;
      border = data.border;

      error = data.error || "#ff0000";
      warning = data.warning || "#ffff00";
      success = data.success || "#00ff00";
      info = data.info || "#0000ff";

      // Push Preset colors to Hyprlock
      root.updateHyprlockColors();
    }
  }

  Component.onCompleted: {
    themeWriter.command = ["sh", "-c", "touch /tmp/qs_theme && echo '" + currentTheme + "' >> /tmp/qs_theme"];
    themeWriter.running = true;
    applyTheme(currentTheme, true);
  }
}
