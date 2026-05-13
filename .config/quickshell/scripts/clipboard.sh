#!/bin/bash

TARGET="clipboard.qml"
CMD_FILE="/tmp/qs_clipboard_cmd"

# The brackets [c] prevent pgrep from catching the script itself
if pgrep -f "qs.*[c]lipboard.qml" > /dev/null; then
    echo "CLOSE" >> "$CMD_FILE"
else
    echo "" > "$CMD_FILE"
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=gtk3 qs -p ~/.config/quickshell/clipboard.qml >/dev/null 2>&1 &
    disown
fi
