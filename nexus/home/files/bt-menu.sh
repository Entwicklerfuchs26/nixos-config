#!/usr/bin/env bash

BT_POWER=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

declare -a ENTRIES
declare -a ACTIONS

if [ "$BT_POWER" = "no" ]; then
    ENTRIES=("⏻  Bluetooth einschalten")
    ACTIONS=("power_on")
else
    while IFS= read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        NAME=$(echo "$line" | cut -d' ' -f3-)
        STATUS=$(bluetoothctl info "$MAC" | grep "Connected:" | awk '{print $2}')
        if [ "$STATUS" = "yes" ]; then
            ENTRIES+=("◆  $NAME")
            ACTIONS+=("disconnect:$MAC")
        else
            ENTRIES+=("◇  $NAME")
            ACTIONS+=("connect:$MAC")
        fi
    done < <(bluetoothctl devices Paired)

    ENTRIES+=("+ Neues Gerät koppeln")
    ACTIONS+=("scan")
    ENTRIES+=("⏻  Bluetooth ausschalten")
    ACTIONS+=("power_off")
fi

IDX=$(printf '%s\n' "${ENTRIES[@]}" | rofi -dmenu -p "󰂯  Bluetooth" -format i)
[ -z "$IDX" ] && exit 0

ACTION="${ACTIONS[$IDX]}"

case "$ACTION" in
    power_on)
        bluetoothctl power on
        notify-send "Bluetooth" "Eingeschaltet"
        ;;
    power_off)
        bluetoothctl power off
        notify-send "Bluetooth" "Ausgeschaltet"
        ;;
    scan)
        blueman-manager &
        ;;
    connect:*)
        MAC="${ACTION#connect:}"
        NAME=$(bluetoothctl info "$MAC" | grep "Name:" | awk '{$1=""; print $0}' | sed 's/^ //')
        notify-send "Bluetooth" "Verbinde mit $NAME..."
        bluetoothctl connect "$MAC" &
        ;;
    disconnect:*)
        MAC="${ACTION#disconnect:}"
        NAME=$(bluetoothctl info "$MAC" | grep "Name:" | awk '{$1=""; print $0}' | sed 's/^ //')
        bluetoothctl disconnect "$MAC"
        notify-send "Bluetooth" "Getrennt: $NAME"
        ;;
esac
