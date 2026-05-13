import QtQuick
import QtQuick.Layouts
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
    visible: true
    focusable: true
    color: "transparent"

    // ── GRACEFUL CLOSE WATCHER ──
    Process {
        id: closeWatcher
        
        running: true
        command: ["tail", "-F", "/tmp/qs_powerdrop_cmd"]
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() === "CLOSE" && !outroAnim.running) {
                    outroAnim.start();
                }
            }
        }
    }

    Process {
        id: powerCmd
        command: []
    }

    // ── INVISIBLE BACKGROUND CATCHER ──
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!outroAnim.running) outroAnim.start();
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                if (!outroAnim.running) outroAnim.start();
            }
        }
    }

    // ── MINIMALIST CORNER DROPDOWN (Scaled up 20%) ──
    Item {
        id: swoopContainer
        width: 40
        height: mainLayout.implicitHeight + 20

        // Stuck flush to the right edge
        anchors.right: parent.right
        anchors.rightMargin: 0

        // Start hidden above the screen
        y: -height - 15

        // ── KEYBOARD NAVIGATION ──
        focus: true
        property int activeIndex: 0 // Starts focused on the top item

        Keys.onDownPressed: {
            activeIndex = (activeIndex + 1) % 4;
// Loops through 4 items
        }
        Keys.onUpPressed: {
            activeIndex = (activeIndex + 3) % 4;
        }
        Keys.onReturnPressed: {
            let cmds = [
                "hyprlock",
                "loginctl terminate-user $USER",
                "systemctl reboot",
                "systemctl poweroff"
        
            ];
            powerCmd.command = ["sh", "-c", cmds[activeIndex]];
            powerCmd.running = true;
            if (!outroAnim.running) outroAnim.start();
        }

        Component.onCompleted: {
            introAnim.start();
            swoopContainer.forceActiveFocus(); // Grab keyboard input immediately
        }

        // Pure slide-down flush to the top edge (y: 0)
        ParallelAnimation {
            id: introAnim
            NumberAnimation { target: swoopContainer;property: "y"; to: 0; duration: 350; easing.type: Easing.OutQuart }
        }

        ParallelAnimation {
            id: outroAnim
            NumberAnimation { target: swoopContainer;property: "y"; to: -swoopContainer.height - 100; duration: 250; easing.type: Easing.InQuart }
            onFinished: { gc(); Qt.quit(); }
        }

        // ── THE MAIN BOX ──
        Rectangle {
            id: mainBox
            anchors.fill: parent
            color: Theme.bgMain

        
            radius: 10

            Rectangle {
                width: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
              
                color: Theme.bgMain
            }

            Rectangle {
                width: 10
                height: 10
                anchors.top: parent.top
                anchors.left: parent.left
    
                color: Theme.bgMain
            }

            // ── VERTICAL LIST OF ICONS ONLY ──
            ColumnLayout {
                id: mainLayout
                anchors.centerIn: parent
         
                spacing: 10

                Repeater {
                    model: [
                        { icon: "󰌾", cmd: "hyprlock",                      colorType: "accent" },
  
                        { icon: "󰗽", cmd: "loginctl terminate-user $USER", colorType: "info" },
                        { icon: "󰜉", cmd: "systemctl reboot",              colorType: "warning" },
                        
{ icon: "󰐥", cmd: "systemctl poweroff",            colorType: "error" }
                    ]

                    delegate: Rectangle {
                        // Checks if Keyboard OR Mouse is selecting it
       
                         property bool isFocused: swoopContainer.activeIndex === index

                        Layout.alignment: Qt.AlignHCenter
                        width: 24
                        height: 24
   
                        radius: 5

                        color: (btnArea.containsMouse ||
isFocused) ? Theme.bgDark : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.fill: parent
         
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: modelData.icon
                      
                            font.family: "JetBrains Mono Nerd Font" // Updated font
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                            textFormat: Text.PlainText

                            color: (btnArea.containsMouse || isFocused) ?
Theme[modelData.colorType] : Theme.textMain
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
            
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                         
                            cursorShape: Qt.PointingHandCursor

                            onEntered: swoopContainer.activeIndex = index // Syncs keyboard highlight with mouse
                            onClicked: {
                              
                                powerCmd.command = ["sh", "-c", modelData.cmd];
                                powerCmd.running = true;
                                if (!outroAnim.running) outroAnim.start();
}
                        }
                    }
                }
            }
        }

        // ── INVERTED TOP-LEFT CORNER ──
       
        Item {
            anchors.top: mainBox.top
            anchors.right: mainBox.left
            width: 15;
            height: 15
            clip: true

            Rectangle {
                width: 60; height: 60; radius: 30
                color: "transparent"
                border.color: Theme.bgMain
                border.width: 15
                x: -30; y: -15
            }
        }
    }
}
