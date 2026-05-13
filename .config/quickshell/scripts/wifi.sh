#!/bin/bash

TARGET="wifi.qml"
CMD_FILE="/tmp/qs_wifi_cmd"

# Look for the 'qs' process running 'wifi.qml'
# The brackets [w] prevent pgrep from catching this script itself!
if pgrep -f "qs.*[w]ifi.qml" > /dev/null; then
    # Instantly trigger the QML animation via the file stream
    echo "CLOSE" >> "$CMD_FILE"
else
    # Clear the file and start fresh
    echo "" > "$CMD_FILE"

    # Launch and disown (using 'qs' to match your terminal command)
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software qs -p ~/.config/quickshell/wifi.qml >/dev/null 2>&1 &
    disown
fi
