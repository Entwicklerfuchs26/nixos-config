#!/usr/bin/env bash
pkill -f nwg-dock
sleep 0.3
nohup nwg-dock-hyprland -d -mb 5 -ml 10 -mr 10 > /dev/null 2>&1 &
