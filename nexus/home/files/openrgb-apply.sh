#!/usr/bin/env bash
source ~/.config/matugen/colors.sh

HEX="${MATUGEN_PRIMARY_CONTAINER#\#}"

# RTX 2070
openrgb --device 0 --zone 0 --mode Direct --color "$HEX" 2>/dev/null || true

# Maus
openrgb --device 1 --mode Static --color "$HEX" 2>/dev/null || true

# Mainboard + Lüfter (Zone 0)
openrgb --device 3 --zone 0 --mode Static --color "$HEX" 2>/dev/null || true
