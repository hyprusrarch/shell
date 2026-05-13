#!/bin/bash

TARGET="powerdrop.qml"
CMD_FILE="/tmp/qs_powerdrop_cmd"

# Look for the process running 'powerdrop.qml'
if pgrep -f "(qs|quickshell).*$TARGET" > /dev/null; then
    # Instantly trigger the QML animation via the file stream
    echo "CLOSE" >> "$CMD_FILE"
else
    # Clear the file and start fresh
    echo "" > "$CMD_FILE"
    
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software quickshell -p ~/.config/quickshell/powerdrop.qml >/dev/null 2>&1 &
    disown
fi
