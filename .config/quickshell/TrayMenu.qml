import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: menuWindow

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"
    visible: true

    property var menuHandle: null
    property var parentMenu: null
    property var childMenu: null
    property real anchorX: 0
    property real anchorY: 0

    readonly property bool isSubmenu: parentMenu !== null

    signal closeRequested()

    readonly property real targetY: isSubmenu ? anchorY : 0

    Shortcut {
        sequence: "Escape"
        onActivated: closeMenu()
    }

    HoverHandler { id: bgHover }

    Timer {
        id: idleCloseTimer
        interval: 50
        running: bgHover.hovered && !mainBoxHover.hovered && !menuWindow.childMenu
        onTriggered: closeMenu()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: closeMenu()
    }

    function closeMenu() {
        if (childMenu) childMenu.closeMenu();
        if (!outroAnim.running) outroAnim.start();
    }

    property real contentW: menuLayout.implicitWidth + 16
    property real contentH: menuLayout.implicitHeight + 16

    property real calculatedWidth: Math.min(menuWindow.width - 20, Math.max(150, contentW))
    property real calculatedHeight: Math.min(menuWindow.height - targetY - 20, contentH)

    property real targetX: isSubmenu ? anchorX : (anchorX + 8) - (calculatedWidth / 2)
    property real safeX: Math.max(0, Math.min(menuWindow.width - calculatedWidth, targetX))

    Item {
        id: layerWrapper
        x: safeX
        y: -calculatedHeight - 20
        width: calculatedWidth
        height: calculatedHeight

        Timer {
            interval: 10
            running: true
            onTriggered: introAnim.start()
        }

        ParallelAnimation {
            id: introAnim
            NumberAnimation { target: layerWrapper; property: "y"; to: targetY; duration: 350; easing.type: Easing.OutQuart }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation { target: layerWrapper; property: "y"; to: -layerWrapper.height - 200; duration: 250; easing.type: Easing.InQuart }
            onFinished: {
                if (parentMenu) parentMenu.destroyChild();
                menuWindow.visible = false;
                if (!isSubmenu) closeRequested();
            }
        }

        Rectangle {
            id: mainBox
            anchors.fill: parent
            color: Theme.bgMain
            radius: 12
            border.width: 0
            clip: true

            HoverHandler { id: mainBoxHover }

            Rectangle {
                visible: !menuWindow.isSubmenu
                width: parent.width
                height: 12
                anchors.top: parent.top
                color: Theme.bgMain
            }

            QsMenuOpener {
                id: menuOpener
                menu: menuWindow.menuHandle
            }

            Flickable {
                id: scrollArea
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: menuLayout.implicitWidth
                contentHeight: menuLayout.implicitHeight
                clip: true
                interactive: contentHeight > height

                ColumnLayout {
                    id: menuLayout
                    width: scrollArea.width
                    spacing: 0

                    Repeater {
                        model: menuOpener.children

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: modelData.isSeparator ? 9 : 26
                            radius: 6
                            color: (!modelData.isSeparator && btnArea.containsMouse) ? Theme.bgDark : "transparent"

                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 1
                                color: Theme.border
                            }

                            RowLayout {
                                visible: !modelData.isSeparator
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text || ""
                                    color: Theme.textMain
                                    font.pixelSize: 11
                                    font.family: "Noto Sans"
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    visible: modelData.hasChildren
                                    text: "▶"
                                    color: Theme.textMuted
                                    font.pixelSize: 9
                                    renderType: Text.NativeRendering
                                    textFormat: Text.PlainText
                                }
                            }

                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !modelData.isSeparator

                                onClicked: {
                                    if (modelData.hasChildren) {
                                        childMenuLoader.setSource("TrayMenu.qml", {
                                            "parentMenu": menuWindow,
                                            "menuHandle": modelData,
                                            "anchorX": layerWrapper.x + layerWrapper.width + 5,
                                            "anchorY": layerWrapper.y + parent.y - scrollArea.contentY
                                        });
                                        childMenuLoader.active = true;
                                        menuWindow.childMenu = childMenuLoader.item;
                                    } else {
                                        modelData.triggered();
                                        menuWindow.closeMenu();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            visible: !menuWindow.isSubmenu
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
            visible: !menuWindow.isSubmenu
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

    Loader {
        id: childMenuLoader
        active: false
        asynchronous: true
    }

    function destroyChild() {
        if (childMenuLoader.active) {
            if (childMenuLoader.item && typeof childMenuLoader.item.closeMenu === "function") {
                childMenuLoader.item.closeMenu();
            }
            childMenuLoader.active = false;
            childMenu = null;
            gc();
        }
    }
}
