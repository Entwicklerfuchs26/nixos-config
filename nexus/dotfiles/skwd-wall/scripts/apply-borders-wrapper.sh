#!/usr/bin/env bash
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ | head -1)
sleep 1
bash /home/fuchs/.config/matugen/apply-borders.sh
bash /home/fuchs/.config/matugen/papirus-color.sh
/run/current-system/sw/bin/gtk-update-icon-cache /home/fuchs/.local/share/icons/Papirus-Dark 2>/dev/null
if /run/current-system/sw/bin/pgrep -f /run/current-system/sw/bin/dolphin > /dev/null; then
    /run/current-system/sw/bin/pkill -f /run/current-system/sw/bin/dolphin
    sleep 1
    /run/current-system/sw/bin/dolphin & disown
fi
