import QtQuick
import QtQuick.Controls
import "../" as Local
import "." as Parts

// Search field: one pill, a leading search glyph and a round trailing button
// that toggles grid / list (or leaves edit mode, shown as a red x).
Item {
    id: root

    required property var controller

    signal navigate(int key)
    signal accepted()

    implicitHeight: 52

    function focusField() { field.forceActiveFocus(); }
    function releaseFocus() { field.focus = false; }

    Local.SpringValue {
        id: focusP
        spring: Local.M3.effectsDefault
        target: field.activeFocus && !root.controller.editMode ? 1 : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.tint(Local.M3.surfaceContainerHigh, Qt.alpha(Local.M3.primary, 0.10 * focusP.value))
    }

    Parts.LauncherGlyph {
        id: searchGlyph
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        kind: "search"
        size: 18
        color: Qt.tint(Local.M3.surfaceVariantText, Qt.alpha(Local.M3.primary, focusP.value))
    }

    TextField {
        id: field
        anchors {
            left: searchGlyph.right; right: toggle.left
            top: parent.top; bottom: parent.bottom
            leftMargin: 8; rightMargin: 6
        }
        font.family: Local.M3.font
        font.pixelSize: 16
        color: Local.M3.surfaceText
        selectionColor: Local.M3.primary
        selectedTextColor: Local.M3.primaryText
        placeholderTextColor: Local.M3.surfaceVariantText
        placeholderText: root.controller.editMode ? "Edit mode — drag to reorder, tap ✕ to exit"
            : root.controller.activeTabIndex === root.controller.themeTab ? "Search themes..."
            : "Search apps..."
        enabled: !root.controller.editMode
        leftPadding: 4
        rightPadding: 8
        background: Item {}

        onTextChanged: root.controller.searchText = text

        Keys.onPressed: function (event) {
            const k = event.key;
            if (k === Qt.Key_Up || k === Qt.Key_Down) {
                root.navigate(k);
                event.accepted = true;
            } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && root.controller.gridViewMode) {
                root.navigate(k);
                event.accepted = true;
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                root.accepted();
                event.accepted = true;
            }
        }
    }

    Connections {
        target: root.controller
        function onSearchCleared() { field.text = ""; }
    }

    Local.Surface {
        id: toggle
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        width: 36
        height: 36
        color: "transparent"
        restRadius: 18
        pressedRadius: 10
        onClicked: {
            if (root.controller.editMode) root.controller.editMode = false;
            else root.controller.gridViewMode = !root.controller.gridViewMode;
            field.forceActiveFocus();
        }
        Parts.LauncherGlyph {
            anchors.centerIn: parent
            size: 18
            kind: root.controller.editMode ? "close" : (root.controller.gridViewMode ? "grid" : "list")
            color: root.controller.editMode ? Local.Theme.error : Local.M3.surfaceVariantText
        }
    }
}
