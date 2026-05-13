#!/bin/bash

TARGET="media.qml"
CMD_FILE="/tmp/qs_media_cmd"

# The brackets [m] prevent pgrep from catching the script itself
if pgrep -f "qs.*[m]edia.qml" > /dev/null; then
    echo "CLOSE" >> "$CMD_FILE"
else
    echo "" > "$CMD_FILE"
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software qs -p ~/.config/quickshell/media.qml >/dev/null 2>&1 &
    disown
fi
