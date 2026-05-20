#!/usr/bin/env bash
if pgrep -f "skwd-wall/shell.qml" > /dev/null; then
    pkill -f "skwd-wall/shell.qml"
else
    quickshell -p ~/.config/skwd-wall/shell.qml &
    sleep 0.5
    skwd wall toggle
fi
