#!/usr/bin/env bash

btctl() { printf '%s\n' "$@" | bluetoothctl 2>/dev/null; }
ROFI=( rofi -dmenu -theme-str 'window { location: north east; anchor: north east; x-offset: -10px; y-offset: 5px; width: 350px; }' )

BT_POWER=$(btctl "show" | grep "Powered:" | awk '{print $2}')

declare -a ENTRIES
declare -a ACTIONS

if [ "$BT_POWER" = "no" ]; then
    ENTRIES=("⏻  Bluetooth einschalten")
    ACTIONS=("power_on")
else
    CONNECTED_MACS=$(btctl "devices Connected" | grep "^Device " | awk '{print $2}')

    while IFS= read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        NAME=$(echo "$line" | cut -d' ' -f3-)
        [ -z "$MAC" ] && continue

        if echo "$CONNECTED_MACS" | grep -q "$MAC"; then
            ENTRIES+=("◆  $NAME")
            ACTIONS+=("disconnect:$MAC")
        else
            ENTRIES+=("◇  $NAME")
            ACTIONS+=("connect:$MAC")
        fi
    done < <(btctl "devices" | grep "^Device ")

    ENTRIES+=("󰐖  Neues Gerät suchen")
    ACTIONS+=("scan")
    ENTRIES+=("⏻  Bluetooth ausschalten")
    ACTIONS+=("power_off")
fi

IDX=$(printf '%s\n' "${ENTRIES[@]}" | "${ROFI[@]}" -p "󰂯  Bluetooth" -format i)
[ -z "$IDX" ] && exit 0

ACTION="${ACTIONS[$IDX]}"

case "$ACTION" in
    power_on)
        btctl "power on"
        notify-send "Bluetooth" "Eingeschaltet"
        ;;
    power_off)
        btctl "power off"
        notify-send "Bluetooth" "Ausgeschaltet"
        ;;
    scan)
        KNOWN_MACS=$(bluetoothctl devices | awk '{print $2}')
        notify-send "Bluetooth" "Suche läuft (10s)..." -t 10000
        bluetoothctl scan on &
        SCAN_PID=$!
        sleep 10
        kill "$SCAN_PID" 2>/dev/null
        bluetoothctl scan off

        declare -a NEW_ENTRIES
        declare -a NEW_MACS
        while IFS= read -r line; do
            MAC=$(echo "$line" | awk '{print $2}')
            NAME=$(echo "$line" | cut -d' ' -f3-)
            [ -z "$MAC" ] && continue
            echo "$KNOWN_MACS" | grep -q "$MAC" && continue
            NEW_ENTRIES+=("$NAME")
            NEW_MACS+=("$MAC")
        done < <(bluetoothctl devices | grep "^Device ")

        if [ ${#NEW_ENTRIES[@]} -eq 0 ]; then
            notify-send "Bluetooth" "Keine neuen Geräte gefunden"
            exit 0
        fi

        PAIR_IDX=$(printf '%s\n' "${NEW_ENTRIES[@]}" | "${ROFI[@]}" -p "  Koppeln mit" -format i)
        [ -z "$PAIR_IDX" ] && exit 0

        PAIR_MAC="${NEW_MACS[$PAIR_IDX]}"
        PAIR_NAME="${NEW_ENTRIES[$PAIR_IDX]}"
        notify-send "Bluetooth" "Kopplung mit $PAIR_NAME..."
        bluetoothctl pair "$PAIR_MAC" && \
        bluetoothctl trust "$PAIR_MAC" && \
        bluetoothctl connect "$PAIR_MAC" \
            && notify-send "Bluetooth" "Verbunden: $PAIR_NAME" \
            || notify-send "Bluetooth" "Kopplung fehlgeschlagen" -u critical
        ;;
    connect:*)
        MAC="${ACTION#connect:}"
        NAME=$(bluetoothctl info "$MAC" | grep "Name:" | cut -d' ' -f2-)
        notify-send "Bluetooth" "Verbinde mit ${NAME:-Gerät}..."
        if bluetoothctl connect "$MAC"; then
            notify-send "Bluetooth" "Verbunden: ${NAME:-$MAC}"
        else
            notify-send "Bluetooth" "Verbindung fehlgeschlagen" -u critical
        fi
        ;;
    disconnect:*)
        MAC="${ACTION#disconnect:}"
        bluetoothctl disconnect "$MAC"
        notify-send "Bluetooth" "Getrennt"
        ;;
esac
