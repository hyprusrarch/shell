#!/bin/bash

TARGET="launcher.qml"
CMD_FILE="/tmp/qs_launcher_cmd"

if pgrep -f "qs.*$TARGET" > /dev/null; then
    echo "CLOSE" >> "$CMD_FILE"
else
    echo "" > "$CMD_FILE"

    env  QT_QPA_PLATFORMTHEME=gtk3 env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software qs -p ~/.config/quickshell/launcher.qml >/dev/null 2>&1 &
    disown
fi
