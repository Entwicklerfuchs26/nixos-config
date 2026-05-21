#!/usr/bin/env bash
set -euo pipefail

COLORS_SH="/home/fuchs/.config/matugen/colors.sh"
HYPERION_URL="http://192.168.1.45:8090/json-rpc"
PRIORITY=200

[ -f "$COLORS_SH" ] || { echo "[hyperion-sync] colors.sh nicht gefunden"; exit 1; }

HEX=$(grep 'MATUGEN_PRIMARY=' "$COLORS_SH" | grep -oP '#[0-9A-Fa-f]{6}' | head -1)
[ -z "$HEX" ] && { echo "[hyperion-sync] Keine Farbe gefunden"; exit 1; }

hex="${HEX#\#}"
R=$((16#${hex:0:2}))
G=$((16#${hex:2:2}))
B=$((16#${hex:4:2}))

curl -sf -X POST "$HYPERION_URL" \
  -H "Content-Type: application/json" \
  -d "{\"command\":\"color\",\"color\":[$R,$G,$B],\"priority\":$PRIORITY,\"duration\":-1}" \
  > /dev/null

echo "[hyperion-sync] Gesendet: $HEX -> RGB($R,$G,$B)"
