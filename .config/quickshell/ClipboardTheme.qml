pragma Singleton
import QtQuick

// The clipboard uses the shell's shared Material roles (same ones as the
// control centre and Wi-Fi), so it follows the active theme / Matugen palette.
QtObject {
    readonly property color panel: M3.surfaceContainer
    readonly property color content: M3.surfaceContainerHigh
    readonly property color selected: M3.surfaceContainerHighest
    readonly property color text: M3.surfaceText
    readonly property color secondaryText: M3.surfaceVariantText
    readonly property color accent: M3.primary
    readonly property color accentThumb: M3.primaryText
    readonly property color outline: M3.outline
    readonly property color error: Theme.error
}
