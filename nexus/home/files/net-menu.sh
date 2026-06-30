#!/usr/bin/env bash

ROFI=( rofi -dmenu -theme-str 'window { location: north east; anchor: north east; x-offset: -10px; y-offset: 5px; width: 350px; }' )

declare -a ENTRIES
declare -a ACTIONS

# Aktive Verbindungen
while IFS=: read -r NAME TYPE STATE; do
    [ "$STATE" != "activated" ] && continue
    if [ "$TYPE" = "ethernet" ]; then
        ENTRIES+=("󰈀  $NAME")
        ACTIONS+=("down:$NAME")
    elif [ "$TYPE" = "wifi" ]; then
        ENTRIES+=("◆  $NAME")
        ACTIONS+=("down:$NAME")
    fi
done < <(nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null)

# Gespeicherte WLAN-Verbindungen (nicht aktiv)
ACTIVE_NAMES=$(nmcli -t -f NAME con show --active 2>/dev/null | cut -d: -f1)
while IFS=: read -r NAME TYPE _; do
    [ "$TYPE" != "wifi" ] && continue
    echo "$ACTIVE_NAMES" | grep -qxF "$NAME" && continue
    ENTRIES+=("◇  $NAME")
    ACTIONS+=("up:$NAME")
done < <(nmcli -t -f NAME,TYPE con show 2>/dev/null)

ENTRIES+=("󰐖  WLAN suchen")
ACTIONS+=("scan")
ENTRIES+=("⚙  Verbindungen verwalten")
ACTIONS+=("manage")

IDX=$(printf '%s\n' "${ENTRIES[@]}" | "${ROFI[@]}" -p "󰤨  Netzwerk" -format i)
[ -z "$IDX" ] && exit 0

ACTION="${ACTIONS[$IDX]}"

case "$ACTION" in
    up:*)
        NAME="${ACTION#up:}"
        notify-send "Netzwerk" "Verbinde mit $NAME..."
        nmcli con up "$NAME" \
            && notify-send "Netzwerk" "Verbunden: $NAME" \
            || notify-send "Netzwerk" "Verbindung fehlgeschlagen" -u critical
        ;;
    down:*)
        NAME="${ACTION#down:}"
        nmcli con down "$NAME"
        notify-send "Netzwerk" "Getrennt: $NAME"
        ;;
    scan)
        notify-send "Netzwerk" "Scanne WLAN..."
        nmcli dev wifi rescan 2>/dev/null

        declare -a SSID_ENTRIES
        declare -a SSID_LIST
        while IFS=$'\t' read -r SSID SIGNAL SECURITY; do
            [ -z "$SSID" ] || [ "$SSID" = "--" ] && continue
            LOCK=""
            [ -n "$SECURITY" ] && [ "$SECURITY" != "--" ] && LOCK=" 󰌾"
            SSID_ENTRIES+=("${SSID}${LOCK}  ${SIGNAL}%")
            SSID_LIST+=("$SSID")
        done < <(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
            | sort -t: -k2 -rn \
            | awk -F: '!seen[$1]++ && $1!=""' \
            | awk -F: '{print $1"\t"$2"\t"$3}')

        if [ ${#SSID_ENTRIES[@]} -eq 0 ]; then
            notify-send "Netzwerk" "Keine WLAN-Netze gefunden"
            exit 0
        fi

        SSID_IDX=$(printf '%s\n' "${SSID_ENTRIES[@]}" | "${ROFI[@]}" -p "  WLAN wählen" -format i)
        [ -z "$SSID_IDX" ] && exit 0
        SSID="${SSID_LIST[$SSID_IDX]}"

        SAVED=$(nmcli -t -f NAME,TYPE con show 2>/dev/null \
            | awk -F: '$2=="wifi"{print $1}' \
            | grep -xF "$SSID" | head -1)

        if [ -n "$SAVED" ]; then
            notify-send "Netzwerk" "Verbinde mit $SSID..."
            nmcli con up "$SAVED" \
                && notify-send "Netzwerk" "Verbunden: $SSID" \
                || notify-send "Netzwerk" "Verbindung fehlgeschlagen" -u critical
        else
            PASS=$(echo "" | "${ROFI[@]}" -p "  Passwort für $SSID" -password)
            [ -z "$PASS" ] && exit 0
            notify-send "Netzwerk" "Verbinde mit $SSID..."
            nmcli dev wifi connect "$SSID" password "$PASS" \
                && notify-send "Netzwerk" "Verbunden: $SSID" \
                || notify-send "Netzwerk" "Verbindung fehlgeschlagen" -u critical
        fi
        ;;
    manage)
        nm-connection-editor &
        ;;
esac
