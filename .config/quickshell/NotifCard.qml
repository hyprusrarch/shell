import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Compact Material 3 notification card matching the supplied reference.
// The action row stays in the layout at all times, so hover never changes card height.
Surface {
    id: card
    required property var notif

    property bool replying: false
    property string ago: "Just now"
    property var arrived: new Date()
    readonly property int minutePulse: Notifs.minutePulse
    readonly property bool hot: cardHover.hovered
    readonly property bool canReply: card.notif.hasInlineReply === true
    readonly property var extraAction: pickAction()

    interactive: !replying
    restRadius: 18
    pressedRadius: 14
    hoverHighlight: false
    color: card.hot
        ? Qt.tint(M3.surfaceContainerHigh, Qt.alpha(M3.surfaceText, 0.07))
        : M3.surfaceContainerHigh

    implicitHeight: col.implicitHeight + 28
    opacity: Math.max(0, Math.min(1, appear.value))
    scale: 0.97 + 0.03 * appear.value
    transform: Translate { x: (1 - appear.value) * 18 }

    SpringValue { id: appear; spring: M3.spatialDefault; initial: 0; target: 1 }

    HoverHandler {
        id: cardHover
        acceptedDevices: PointerDevice.Mouse
        target: null
    }

    function pickAction() {
        const actions = notif.actions
        if (!actions) return null
        for (let i = 0; i < actions.length; i++)
            if (actions[i].identifier !== "default") return actions[i]
        return null
    }

    function iconSrc() {
        const name = notif.appIcon || notif.desktopEntry || ""
        if (!name) return ""
        if (name.startsWith("/") || name.startsWith("file:")) return name
        return Quickshell.iconPath(name, true)
    }

    function activate() {
        const actions = notif.actions
        if (actions) {
            for (let i = 0; i < actions.length; i++) {
                if (actions[i].identifier === "default") {
                    actions[i].invoke()
                    break
                }
            }
        }
        notif.dismiss()
    }

    function startReply() {
        if (!canReply) return
        replying = true
        Notifs.replyActive = true
        replyFocusTimer.restart()
    }

    function cancelReply() {
        replying = false
        Notifs.replyActive = false
        replyFocusTimer.stop()
    }

    function sendReply() {
        const message = replyField.text.trim()
        if (message.length === 0) return
        if (canReply && typeof notif.sendInlineReply === "function") {
            notif.sendInlineReply(message)
            replyField.text = ""
            cancelReply()
        }
    }

    function updateAge() {
        const minutes = Math.max(0, Math.floor((Date.now() - arrived.getTime()) / 60000))
        ago = minutes < 1 ? "Just now"
            : minutes < 60 ? minutes + " min ago"
            : Math.floor(minutes / 60) + " h ago"
    }

    onClicked: if (!replying) activate()
    onMinutePulseChanged: updateAge()

    Timer {
        id: replyFocusTimer
        interval: 80
        repeat: false
        onTriggered: if (card.replying) replyField.forceActiveFocus(Qt.MouseFocusReason)
    }
    onNotifChanged: {
        if (replying) Notifs.replyActive = false
        arrived = new Date()
        replying = false
        updateAge()
    }
    Component.onCompleted: updateAge()
    Component.onDestruction: if (replying) Notifs.replyActive = false

    component TextAction: Surface {
        property string label: ""
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        color: "transparent"
        content: M3.primary
        restRadius: 12
        pressedRadius: 7
        M3Text {
            anchors.centerIn: parent
            text: parent.label
            color: M3.primary
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    M3IconButton {
        id: dismissButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.rightMargin: 6
        z: 5
        visible: card.hot
        buttonSize: 24
        iconSize: 14
        iconName: "close"
        accessibleName: "Remove notification"
        iconColor: M3.surfaceText
        containerColor: "transparent"
        hoverHighlight: false
        onClicked: {
            card.cancelReply()
            card.notif.dismiss()
            Notifs.dropToast(card.notif)
        }
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 13
            rightMargin: 12
            topMargin: 12
        }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 5

            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                IconImage {
                    id: appImg
                    anchors.fill: parent
                    source: card.iconSrc()
                    visible: source !== ""
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !appImg.visible
                    name: "notifications"
                    size: 16
                    color: M3.primary
                }
            }

            M3Text {
                Layout.fillWidth: true
                text: card.notif.appName || "Notification"
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            M3Text {
                Layout.rightMargin: card.hot ? 22 : 0
                text: card.ago
                color: M3.surfaceVariantText
                font.pixelSize: 11
            }
        }

        M3Text {
            Layout.fillWidth: true
            Layout.topMargin: 5
            Layout.leftMargin: 16
            Layout.rightMargin: 4
            visible: text.length > 0
            text: card.notif.body || card.notif.summary || ""
            color: M3.surfaceVariantText
            font.pixelSize: 11
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 4
            Layout.topMargin: 7
            Layout.preferredHeight: card.replying ? 34 : 24
            clip: true

            RowLayout {
                anchors.fill: parent
                visible: !card.replying
                spacing: 0

                TextAction {
                    visible: card.canReply || card.extraAction !== null
                    label: card.canReply ? "reply" : (card.extraAction ? card.extraAction.text : "")
                    onClicked: {
                        if (card.canReply) card.startReply()
                        else if (card.extraAction) card.extraAction.invoke()
                    }
                }

                Rectangle {
                    visible: card.canReply || card.extraAction !== null
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: M3.outlineVariant
                }

                TextAction {
                    label: Notifs.dnd ? "turn off dnd" : "turn on dnd"
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
            }

            RowLayout {
                anchors.fill: parent
                visible: card.replying
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: M3.surfaceContainerHighest

                    TextInput {
                        id: replyField
                        anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                        verticalAlignment: TextInput.AlignVCenter
                        focus: card.replying
                        enabled: card.replying
                        activeFocusOnPress: true
                        selectByMouse: true
                        color: M3.surfaceText
                        font.family: M3.font
                        font.pixelSize: 13
                        clip: true
                        onAccepted: card.sendReply()
                        Keys.onEscapePressed: card.cancelReply()
                    }

                    M3Text {
                        visible: replyField.text.length === 0
                        anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter }
                        text: card.notif.inlineReplyPlaceholder || "Reply"
                        color: M3.surfaceVariantText
                        font.pixelSize: 12
                    }
                }

                Surface {
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    restRadius: 17
                    pressedRadius: 9
                    color: M3.primary
                    content: M3.primaryText
                    onClicked: card.sendReply()
                    Image { anchors.centerIn: parent; source: "assets/reply_send.svg"; width: 17; height: 17; fillMode: Image.PreserveAspectFit; smooth: true }
                }
            }
        }
    }
}
