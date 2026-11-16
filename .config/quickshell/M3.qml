pragma Singleton
import QtQuick
import Quickshell

// Material 3 Expressive design tokens bound to the shell palette and adaptive Matugen colours.
Singleton {
    // ── colour roles: sourced from the shell's active preset or Matugen theme ──
    readonly property color surface: Theme.bgMain
    readonly property color surfaceContainer: Theme.bgDark
    readonly property color surfaceContainerHigh: Theme.isDark ? Qt.lighter(Theme.bgDark, 1.13) : Qt.darker(Theme.bgDark, 1.05)
    readonly property color surfaceContainerHighest: Theme.isDark ? Qt.lighter(Theme.bgDark, 1.25) : Qt.darker(Theme.bgDark, 1.10)
    readonly property color surfaceText: Theme.textMain
    readonly property color surfaceVariantText: Theme.textMuted
    readonly property color outline: Theme.border
    readonly property color outlineVariant: Theme.border
    readonly property color primary: Theme.accent
    readonly property color primaryText: (Theme.accent.r * 0.299 + Theme.accent.g * 0.587 + Theme.accent.b * 0.114) > 0.55 ? "#202027" : "#FFFFFF"
    readonly property color primaryContainer: Theme.isDark ? Qt.darker(Theme.accent, 1.75) : Qt.lighter(Theme.accent, 1.65)
    readonly property color primaryContainerText: Theme.textMain
    readonly property color secondaryContainer: Theme.isDark ? Qt.lighter(Theme.bgDark, 1.25) : Qt.darker(Theme.bgDark, 1.07)
    readonly property color secondaryContainerText: Theme.textMain
    readonly property color errorContainer: Theme.isDark ? Qt.darker(Theme.error, 1.65) : Qt.lighter(Theme.error, 1.65)
    readonly property color errorContainerText: Theme.textMain

    // ── shape scale (dp) ────────────────────────────────────────
    readonly property int shapeSm: 8
    readonly property int shapeMd: 12
    readonly property int shapeLg: 16
    readonly property int shapeLgInc: 20
    readonly property int shapeXl: 28
    readonly property int shapeXlInc: 32

    // ── type ────────────────────────────────────────────────────
    // Load the bundled variable font when installed. The fallback keeps the shell
    // usable before the one-time font setup script is run.
    property FontLoader googleSansFlexLoader: FontLoader {
        source: Qt.resolvedUrl("assets/fonts/GoogleSansFlex.ttf")
    }
    readonly property string font: googleSansFlexLoader.status === FontLoader.Ready
        ? googleSansFlexLoader.name : "Roboto Flex"

    // ── motion: M3 Expressive spring tokens ─────────────────────
    // spatial = position / size / shape (may overshoot), effects = colour / opacity (never overshoots)
    // damping is a damping *ratio*; mass is 1.
    readonly property var spatialFast:    ({ stiffness: 800,  damping: 0.6 })
    readonly property var spatialDefault: ({ stiffness: 380,  damping: 0.8 })
    readonly property var spatialSlow:    ({ stiffness: 200,  damping: 0.8 })
    readonly property var effectsFast:    ({ stiffness: 3800, damping: 1.0 })
    readonly property var effectsDefault: ({ stiffness: 1600, damping: 1.0 })
    readonly property var effectsSlow:    ({ stiffness: 800,  damping: 1.0 })

    // ── launchers used by the "settings" actions (edit to taste) ─
    property var wifiSettingsCommand: ["nm-connection-editor"]
    property var bluetoothSettingsCommand: ["blueman-manager"]
}
