#!/bin/bash

TARGET="modules.qml"
CMD_FILE="/tmp/qs_modules_cmd"

# Look for the 'qs' process running 'modules.qml'
if ps aux | grep -v grep | grep -q "qs -p .*$TARGET"; then
    # Instantly trigger the QML animation via the file stream
    echo "CLOSE" >> "$CMD_FILE"
else
    # Clear the file and start fresh
    echo "" > "$CMD_FILE"
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software qs -p ~/.config/quickshell/modules.qml >/dev/null 2>&1 &
    disown
fi
