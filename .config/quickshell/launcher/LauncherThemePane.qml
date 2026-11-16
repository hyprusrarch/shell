import QtQuick
import "../" as Local
import "." as Parts

// Themes tab: a 3-column grid of theme previews (sorted by luminance).
Item {
    id: pane

    required property var controller

    // keyboard navigation does not apply to the theme grid (same as before)
    readonly property Item activeView: null

    Component.onCompleted: pane.controller.rebuildThemeModel(pane.controller.searchText)

    GridView {
        id: themeGrid
        anchors.fill: parent
        clip: true
        cellWidth: Math.floor(width / 3)
        cellHeight: 84
        model: pane.controller.modelForTab(pane.controller.themeTab)
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: Parts.LauncherThemeCard {
            controller: pane.controller
            view: themeGrid
        }
    }
}
