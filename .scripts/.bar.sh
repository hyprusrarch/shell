#!/bin/bash

TARGET="bar.qml"

if pgrep -f "quickshell.*$TARGET" > /dev/null; then
    pkill -f "quickshell.*$TARGET"
else
    # Launch, send output to nowhere, and disown it so the bar can't kill it
    env QML_DISABLE_DISK_CACHE=1 QSG_RENDER_LOOP=basic QT_QUICK_BACKEND=software qs -p ~/.config/quickshell/bar.qml >/dev/null 2>&1 &
    disown
fi
