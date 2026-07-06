#!/usr/bin/env bash
ROFI=(rofi -dmenu -theme-str 'window { location: north east; anchor: north east; x-offset: -10px; y-offset: 5px; width: 350px; }')

STATE=$(curl -sf http://localhost:7777/state | python3 -c "
import sys,json
d=json.load(sys.stdin)
ov=d.get('override') or 'auto'
mon=d.get('monitor') or ''
print(ov + '|' + mon)
" 2>/dev/null || echo "auto|")
CURRENT="${STATE%|*}"
CUR_MON="${STATE#*|}"

mark() {
    if [ "$1" = "video" ] && [ "$CURRENT" = "video" ]; then
        [ -n "$CUR_MON" ] && echo "◆  $2 ($CUR_MON)" || echo "◆  $2"
    elif [ "$1" = "$CURRENT" ]; then
        echo "◆  $2"
    else
        echo "◇  $2"
    fi
}

ENTRIES=(
    "$(mark video 'Video')"
    "$(mark music 'Musik')"
    "$(mark idle 'Idle')"
    "$(mark auto 'Auto (erkennt automatisch)')"
)
MODES=("video" "music" "idle" "auto")

IDX=$(printf '%s\n' "${ENTRIES[@]}" | "${ROFI[@]}" -p "󰛨  LED Modus" -format i)
[ -z "$IDX" ] && exit 0

MODE="${MODES[$IDX]}"

if [ "$MODE" = "video" ]; then
    MONITORS=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import sys,json
mons=json.load(sys.stdin)
for m in mons:
    print(m['name'])
" 2>/dev/null)

    MON=$(printf '%s\n' $MONITORS | "${ROFI[@]}" -p "󰍹  Monitor wählen")
    [ -z "$MON" ] && exit 0
    curl -sf -X POST "http://localhost:7777/mode/video/$MON" > /dev/null
else
    curl -sf -X POST "http://localhost:7777/mode/$MODE" > /dev/null
fi
